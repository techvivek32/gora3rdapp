import type { CabCategory, PlatformSettings, TripDraft } from './types';
import { stateFromText } from './states';

/**
 * The cab fare engine, ported 1:1 from the mobile app's `cab_results_page.dart`.
 *
 * It MUST stay identical to the Flutter version: a customer who prices a trip in
 * the app and then books the same trip on the website has to see the same
 * number, and the figure the website sends as `estimatedFare` is what the driver
 * is later paid against. Every rule below exists in the app — read them as a
 * pair, and change them as a pair.
 *
 * Order of operations (this is the part that is easy to get subtly wrong):
 *   base   = billable km x per-km rate        (or the Local package price)
 *   +toll  = admin's toll/tax per-km x distance, All-Inclusive mode only
 *   net    = (base + toll) after the cab's discount%
 *   +allow = driver allowance, added AFTER the discount so the driver keeps it
 *   +gst   = gstPercent of (net + allowance)
 */

export type IncMode = 'Best Price' | 'All Inclusive';

export interface FareContext {
  trip: TripDraft;
  settings: PlatformSettings;
  /** Road distance in km for the WHOLE trip (already doubled for round trips). */
  distanceKm: number;
  /** Toll in rupees for the whole trip (already doubled for round trips). */
  toll: number;
  incMode: IncMode;
}

export interface FareBreakdown {
  /** Ride fare before toll, discount, allowance and GST. */
  baseFare: number;
  toll: number;
  /** (base + toll) after the cab's discount. */
  netBase: number;
  allowance: number;
  gst: number;
  /** What the customer pays. */
  total: number;
  /** Pre-discount total, for the struck-through price. 0 when there's no discount. */
  originalTotal: number;
  billedKm: number;
  minApplied: boolean;
}

const num = (v: unknown, fallback = 0): number =>
  typeof v === 'number' && Number.isFinite(v) ? v : fallback;

export const isRoundTrip = (trip: TripDraft) => trip.subType === 'Round Trip';
export const isLocalTrip = (trip: TripDraft) => trip.subType === 'Local';
export const localHours = (trip: TripDraft) => num(trip.durationHours, 8) || 8;

/**
 * Days the trip spans, start date -> end date inclusive (same day = 1). Drives
 * both the round-trip allowance and the included km.
 */
export function tripDays(trip: TripDraft): number {
  const s = trip.travelDate ? new Date(trip.travelDate) : null;
  const e = trip.tripEndDate ? new Date(trip.tripEndDate) : null;
  if (!s || !e || Number.isNaN(s.getTime()) || Number.isNaN(e.getTime())) return 1;
  const d0 = Date.UTC(s.getFullYear(), s.getMonth(), s.getDate());
  const d1 = Date.UTC(e.getFullYear(), e.getMonth(), e.getDate());
  const diff = Math.round((d1 - d0) / 86400000);
  return diff < 0 ? 1 : diff + 1;
}

/** Fuels the admin priced for this cab (price > 0). Empty = flat pricePerKm. */
export function availableFuels(cat: CabCategory): string[] {
  const out: string[] = [];
  if (num(cat.pricePerKmPetrol) > 0) out.push('Petrol');
  if (num(cat.pricePerKmDiesel) > 0) out.push('Diesel');
  if (num(cat.pricePerKmCng) > 0) out.push('CNG');
  return out;
}

/** The pickup's state, for state-wise fuel pricing. '' = use the base rate. */
export function pickupState(trip: TripDraft): string {
  return stateFromText(`${trip.pickup?.address ?? ''} ${trip.pickupCity ?? ''}`);
}

function stateRate(cat: CabCategory, fuel: string, state: string): number {
  if (!state) return 0;
  const sp = cat.statePricing;
  if (!Array.isArray(sp)) return 0;
  const key = fuel === 'Diesel' ? 'diesel' : fuel === 'CNG' ? 'cng' : 'petrol';
  for (const e of sp) {
    if (e && String(e.state ?? '').toLowerCase() === state.toLowerCase()) {
      return num((e as Record<string, unknown>)[key]);
    }
  }
  return 0;
}

/** Per-km rate: the pickup state's rate first, then the fuel rate, then flat. */
export function rateForFuel(cat: CabCategory, fuel: string, state: string): number {
  if (!fuel) return num(cat.pricePerKm);
  const sr = stateRate(cat, fuel, state);
  if (sr > 0) return sr;
  const key = fuel === 'Diesel' ? 'pricePerKmDiesel' : fuel === 'CNG' ? 'pricePerKmCng' : 'pricePerKmPetrol';
  const r = num((cat as Record<string, unknown>)[key]);
  return r > 0 ? r : num(cat.pricePerKm);
}

/** Km included in a Local package — global (same for every cab), per settings. */
export function localIncludedKm(cat: CabCategory, trip: TripDraft, settings: PlatformSettings): number {
  const hours = localHours(trip);
  for (const p of settings.localPackageKm ?? []) {
    if (num(p?.hours) === hours) {
      const km = num(p?.km);
      if (km > 0) return km;
    }
  }
  return Math.round(num(cat.packageKmPerHour) * hours);
}

/** The admin's price for the chosen package, 0 when they set none. */
export function localPackagePrice(cat: CabCategory, trip: TripDraft): number {
  const hours = localHours(trip);
  for (const p of cat.localPackages ?? []) {
    if (num(p?.hours) === hours) return num(p?.price);
  }
  return 0;
}

/** True when the cab offers Local packages at all. */
export function localOffered(cat: CabCategory): boolean {
  return (cat.localPackages ?? []).length > 0 || num(cat.packageKmPerHour) > 0;
}

/** Minimum included km: round trip -> km/day x days, else the global flat min. */
function minKmFor(cat: CabCategory, ctx: FareContext): number {
  if (isRoundTrip(ctx.trip)) {
    const daily = num(cat.dailyKmLimit);
    if (daily > 0) return daily * tripDays(ctx.trip);
  }
  return num(ctx.settings.minBillKm);
}

/** The distance actually charged: never below this cab's minimum. */
export function billableKmFor(cat: CabCategory, ctx: FareContext): number {
  const m = minKmFor(cat, ctx);
  return ctx.distanceKm < m ? m : ctx.distanceKm;
}

/** Driver allowance. Round trip: days x daily. One way: base or max by distance. */
export function allowanceFor(cat: CabCategory, ctx: FareContext): number {
  if (isLocalTrip(ctx.trip)) return 0;
  if (isRoundTrip(ctx.trip)) return Math.round(num(cat.allowanceDailyRate)) * tripDays(ctx.trip);
  const baseR = Math.round(num(cat.allowanceBaseRate));
  const maxR = Math.round(num(cat.allowanceMaxRate));
  if (baseR === 0 && maxR === 0) return 0;
  const thr = num(cat.allowanceDistanceThreshold);
  return ctx.distanceKm <= thr ? baseR : maxR;
}

function discounted(fare: number, cat: CabCategory): number {
  const p = Math.min(100, Math.max(0, num(cat.discountPercent)));
  return p > 0 ? Math.round(fare * (1 - p / 100)) : fare;
}

/** Toll applies to All-Inclusive only; Best Price and Local never carry it. */
function tollFor(ctx: FareContext): number {
  if (ctx.incMode === 'Best Price' || isLocalTrip(ctx.trip)) return 0;
  return Math.round(ctx.toll);
}

/** Ride fare before toll/discount/allowance/GST. */
function baseFareForFuel(cat: CabCategory, fuel: string, ctx: FareContext): number {
  if (isLocalTrip(ctx.trip)) {
    const pkg = localPackagePrice(cat, ctx.trip);
    // A packaged price IS the price — it does not move with fuel.
    if (pkg > 0) return pkg;
    return Math.round(localIncludedKm(cat, ctx.trip, ctx.settings) * rateForFuel(cat, fuel, pickupState(ctx.trip)));
  }
  return Math.round(billableKmFor(cat, ctx) * rateForFuel(cat, fuel, pickupState(ctx.trip)));
}

/** The whole breakdown for one cab + fuel. This is the single entry point. */
export function fareFor(cat: CabCategory, fuel: string, ctx: FareContext): FareBreakdown {
  const gstPercent = num(ctx.settings.gstPercent);
  const base = baseFareForFuel(cat, fuel, ctx);
  const toll = tollFor(ctx);
  const baseToll = base + toll;
  const netBase = discounted(baseToll, cat);
  const allowance = allowanceFor(cat, ctx);

  // GST is charged on what the customer actually pays: net base + toll, plus
  // the driver allowance.
  const gstOn = (netBaseToll: number) =>
    gstPercent > 0 ? Math.round(((netBaseToll + allowance) * gstPercent) / 100) : 0;

  const gst = gstOn(netBase);
  const total = netBase + allowance + gst;
  const rawTotal = baseToll + allowance + gstOn(baseToll);

  const m = minKmFor(cat, ctx);
  return {
    baseFare: base,
    toll,
    netBase,
    allowance,
    gst,
    total,
    originalTotal: rawTotal > total ? rawTotal : 0,
    billedKm: isLocalTrip(ctx.trip) ? localIncludedKm(cat, ctx.trip, ctx.settings) : billableKmFor(cat, ctx),
    minApplied: m > 0 && ctx.distanceKm < m && !isLocalTrip(ctx.trip),
  };
}

/** The fuel to price a card with: the one chosen, else the first available. */
export function resolveFuel(cat: CabCategory, chosen?: string): string {
  const avail = availableFuels(cat);
  if (avail.length === 0) return '';
  return chosen && avail.includes(chosen) ? chosen : avail[0];
}

/** Cheapest/dearest across the cab's fuels, for the card's "₹X – ₹Y" line. */
export function fareRange(cat: CabCategory, ctx: FareContext): [number, number] {
  const fuels = availableFuels(cat);
  if (fuels.length === 0) {
    const f = fareFor(cat, '', ctx).total;
    return [f, f];
  }
  const fares = fuels.map((f) => fareFor(cat, f, ctx).total).sort((a, b) => a - b);
  return [fares[0], fares[fares.length - 1]];
}

/** Fallback classes so the results page still works before the admin adds any. */
export const DEFAULT_CATEGORIES: CabCategory[] = [
  { name: 'Wagon R or equivalent', vehicleClass: 'Compact', imageUrl: '', pricePerKm: 12, seats: 4, bags: '1 Small bag' },
  { name: 'Dzire or equivalent', vehicleClass: 'Sedan', imageUrl: '', pricePerKm: 15, seats: 4, bags: '2 Small bags' },
  { name: 'Ertiga or equivalent', vehicleClass: 'SUV', imageUrl: '', pricePerKm: 18, seats: 6, bags: '2 Bags' },
  { name: 'Innova Crysta', vehicleClass: 'Premium SUV', imageUrl: '', pricePerKm: 22, seats: 7, bags: '3 Bags' },
];

export const DEFAULT_INCLUSIONS = [
  'Toll tax',
  'State tax',
  'Car parking',
  'Driver allowance',
  'GST',
  'No hidden charges',
];
