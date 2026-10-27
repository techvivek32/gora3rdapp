/** Shapes the web app reads off the API. Deliberately loose where the backend
 *  itself is loose (cab categories and bookings carry admin-authored extras),
 *  so a new field never has to be added here before it can be displayed. */

export type ServiceType = 'cab' | 'hire_driver' | 'luxury' | 'car_pool';

export interface Geo {
  address?: string;
  lat?: number;
  lng?: number;
  city?: string;
}

export interface User {
  _id?: string;
  fullName?: string;
  mobile?: string;
  email?: string;
  city?: string;
  state?: string;
  role?: string;
  profileImage?: string;
  walletBalance?: number;
  customerWalletBalance?: number;
  [k: string]: unknown;
}

/** A cab class the admin manages (collection `cabCategories`). */
export interface CabCategory {
  _id?: string;
  name?: string;
  vehicleClass?: string;
  imageUrl?: string;
  seats?: number;
  bags?: string;
  pricePerKm?: number;
  pricePerKmPetrol?: number;
  pricePerKmDiesel?: number;
  pricePerKmCng?: number;
  statePricing?: { state?: string; petrol?: number; diesel?: number; cng?: number }[];
  discountPercent?: number;
  allowanceBaseRate?: number;
  allowanceMaxRate?: number;
  allowanceDistanceThreshold?: number;
  allowanceDailyRate?: number;
  dailyKmLimit?: number;
  extraKmPrice?: number;
  packageKmPerHour?: number;
  extraHourPrice?: number;
  localPackages?: { hours?: number; price?: number }[];
  [k: string]: unknown;
}

/** Global cab settings the fare depends on (`GET /settings`). */
export interface PlatformSettings {
  minBillKm?: number;
  tollTaxPerKm?: number;
  gstPercent?: number;
  localPackageKm?: { hours?: number; km?: number }[];
  minDeposit?: number;
  minWithdrawal?: number;
  minTransfer?: number;
  [k: string]: unknown;
}

export interface Booking {
  _id?: string;
  bookingId?: string;
  serviceType?: ServiceType;
  subType?: string;
  status?: string;
  pickup?: Geo;
  drop?: Geo;
  stops?: Geo[];
  pickupCity?: string;
  dropCity?: string;
  travelDate?: string;
  travelTime?: string;
  tripEndDate?: string;
  tripEndTime?: string;
  passengers?: number;
  vehicleType?: string;
  durationHours?: number;
  notes?: string;
  estimatedFare?: number;
  finalFare?: number;
  baseFare?: number;
  driverAllowance?: number;
  gstAmount?: number;
  estimatedDistance?: number;
  advanceStatus?: string;
  advanceAmount?: number;
  advancePercent?: number;
  driverSnapshot?: { name?: string; phone?: string; vehicle?: string; vehicleNumber?: string; rating?: number };
  createdAt?: string;
  [k: string]: unknown;
}

export interface PoolRide {
  _id?: string;
  rideId?: string;
  from?: Geo;
  to?: Geo;
  fromCity?: string;
  toCity?: string;
  travelDate?: string;
  departureTime?: string;
  totalSeats?: number;
  seatsBooked?: number;
  pricePerSeat?: number;
  vehicle?: string;
  vehicleNumber?: string;
  distanceKm?: number;
  notes?: string;
  status?: string;
  driver?: { fullName?: string; agencyName?: string; mobile?: string; rating?: number; profileImage?: string };
  [k: string]: unknown;
}

/** A place suggestion from `GET /places/autocomplete`. */
export interface PlaceSuggestion {
  description?: string;
  placeId?: string;
  place_id?: string;
  mainText?: string;
  secondaryText?: string;
  [k: string]: unknown;
}

/** The trip the customer is building, handed between the search, results and
 *  confirm screens. Mirrors the map the mobile app passes via GoRouter `extra`,
 *  but lives in sessionStorage because a web page can be reloaded mid-flow. */
export interface TripDraft {
  serviceType: ServiceType;
  subType: string;
  pickup?: Geo;
  drop?: Geo;
  stops?: Geo[];
  pickupCity?: string;
  dropCity?: string;
  travelDate?: string;
  travelTime?: string;
  tripEndDate?: string;
  tripEndTime?: string;
  passengers?: number;
  durationHours?: number;
  notes?: string;
  distanceKm?: number;
}

/** What the results screen hands the confirm screen once a cab is picked. */
export interface SelectedCab {
  cat: CabCategory;
  fuel: string;
  fare: number;
  baseFare: number;
  gst: number;
  allowance: number;
  toll: number;
  distanceKm: number;
  billedKm: number;
  isRound: boolean;
  isLocal: boolean;
  packageHours: number;
  extraHourPrice: number;
  dailyKmLimit: number;
  extraKmPrice: number;
  includedKm: number;
  bestPrice: boolean;
}
