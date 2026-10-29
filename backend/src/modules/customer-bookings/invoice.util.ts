import PDFDocument from 'pdfkit';
import * as fs from 'fs';
import * as path from 'path';
import { DEFAULT_INVOICE_TEMPLATE, InvoiceBlock } from '../../database/schemas/invoice-template.schema';

export interface InvoiceData {
  bookingId: string;
  serviceType: string;
  subType?: string;
  customerName: string;
  customerMobile?: string;
  customerEmail?: string;
  customerAddress?: string;
  driverName: string;
  driverPhone?: string;
  vehicle?: string;
  vehicleNumber?: string;
  // Booked cab class details (from the admin cab category).
  carName?: string;
  carClass?: string;
  carSeats?: number;
  carBags?: string;
  carFuel?: string;
  /** The per-km rate the booking was priced at, recorded when it was made. */
  ratePerKm?: number;
  /** The cab category's discount — only used to rebuild older bookings' rate. */
  discountPercent?: number;
  dailyKmLimit?: number;
  pickup?: string;
  drop?: string;
  pickupCity?: string;
  dropCity?: string;
  travelDate?: Date | string;
  travelTime?: string;
  returnDate?: string; // round trip only, "dd-MM-yyyy"
  startedAt?: Date | string;
  completedAt?: Date | string;
  distanceKm?: number;
  passengers?: number;
  fare: number;
  tollAmount?: number;
  parkingCharge?: number;
  otherCharge?: number;
  driverAllowance?: number;
  gstAmount?: number;
  fareMode?: string;
  paymentMode?: string;
  includedKm?: number;
  trackedKm?: number;
  extraKm?: number;
  extraKmPrice?: number;
  extraCharge?: number;
  packageHours?: number;
  extraHourPrice?: number;
  extraHours?: number;
  extraHourCharge?: number;
  advanceAmount?: number;
}

/** The saved design. Shape mirrors DEFAULT_INVOICE_TEMPLATE. */
export interface InvoiceTemplateLike {
  paper?: Record<string, any>;
  company?: Record<string, any>;
  tax?: Record<string, any>;
  invoice?: Record<string, any>;
  blocks?: InvoiceBlock[];
}

// ─── formatting helpers ──────────────────────────────────────────────────────

function fmtDate(d?: Date | string, withTime = true): string {
  if (!d) return '-';
  const dt = new Date(d);
  if (isNaN(dt.getTime())) return String(d);
  return dt.toLocaleString('en-IN', {
    day: '2-digit', month: 'short', year: 'numeric',
    ...(withTime ? { hour: '2-digit' as const, minute: '2-digit' as const, hour12: true } : {}),
  });
}

function money(n?: number): string {
  const v = Math.round((n || 0) * 100) / 100;
  return `Rs. ${v.toLocaleString('en-IN', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`;
}

/** Two decimals at most, and none at all on a whole number: 90, not 90.00. */
function round2(n: number): string {
  const v = Math.round(n * 100) / 100;
  return Number.isInteger(v) ? String(v) : v.toFixed(2);
}

function fmtDuration(start?: Date | string, end?: Date | string): string {
  if (!start || !end) return '';
  const s = new Date(start).getTime();
  const e = new Date(end).getTime();
  if (isNaN(s) || isNaN(e) || e <= s) return '';
  const mins = Math.round((e - s) / 60000);
  const h = Math.floor(mins / 60), m = mins % 60;
  return h > 0 ? `${h}h ${m}m` : `${m}m`;
}

/**
 * Fold typographic characters down to what the built-in Helvetica can draw.
 *
 * pdfkit's standard fonts are WinAnsi; an em dash or a curly quote that is not
 * in the subset silently renders as a blank, so an admin typing a dash into the
 * terms would see a gap on the PDF with nothing to explain it.
 */
function txt(v: any): string {
  return String(v ?? '')
    .replace(/[‒-―]/g, '-')
    .replace(/[‘’‛]/g, "'")
    .replace(/[“”]/g, '"')
    .replace(/…/g, '...')
    .replace(/[   ]/g, ' ')
    .replace(/₹/g, 'Rs. ');
}

function prettyService(s?: string): string {
  switch (s) {
    case 'cab': return 'Cab Service';
    case 'hire_driver': return 'Hire a Driver';
    case 'luxury': return 'Luxury';
    case 'car_pool': return 'Car Pool';
    default: return s || 'Booking';
  }
}

const ONES = ['', 'One', 'Two', 'Three', 'Four', 'Five', 'Six', 'Seven', 'Eight', 'Nine', 'Ten',
  'Eleven', 'Twelve', 'Thirteen', 'Fourteen', 'Fifteen', 'Sixteen', 'Seventeen', 'Eighteen', 'Nineteen'];
const TENS = ['', '', 'Twenty', 'Thirty', 'Forty', 'Fifty', 'Sixty', 'Seventy', 'Eighty', 'Ninety'];

function twoDigits(n: number): string {
  if (n < 20) return ONES[n];
  return (TENS[Math.floor(n / 10)] + (n % 10 ? ' ' + ONES[n % 10] : '')).trim();
}

/** Indian-system words: 1,23,456 → "One Lakh Twenty Three Thousand Four Hundred Fifty Six". */
function numberToWords(num: number): string {
  const n = Math.floor(Math.abs(num));
  if (n === 0) return 'Zero';
  const parts: string[] = [];
  const crore = Math.floor(n / 10000000);
  const lakh = Math.floor((n % 10000000) / 100000);
  const thousand = Math.floor((n % 100000) / 1000);
  const hundred = Math.floor((n % 1000) / 100);
  const rest = n % 100;
  if (crore) parts.push(twoDigits(crore) + ' Crore');
  if (lakh) parts.push(twoDigits(lakh) + ' Lakh');
  if (thousand) parts.push(twoDigits(thousand) + ' Thousand');
  if (hundred) parts.push(ONES[hundred] + ' Hundred');
  if (rest) parts.push(twoDigits(rest));
  return parts.join(' ');
}

/** "Rupees One Thousand Twenty Five and Fifty Paise Only". */
function amountInWords(amount: number): string {
  const rupees = Math.floor(Math.abs(amount));
  const paise = Math.round((Math.abs(amount) - rupees) * 100);
  let s = 'Rupees ' + numberToWords(rupees);
  if (paise > 0) s += ' and ' + numberToWords(paise) + ' Paise';
  return s + ' Only';
}

// ─── fare + tax maths ────────────────────────────────────────────────────────

interface FareLine {
  label: string;
  rate?: string;
  amount: number;
  /**
   * How many units this line was billed for, of what, and at what price —
   * 200 km at 100/km. `rateValue` is the rate the booking was actually priced
   * at, so qty x rateValue equals `amount` and the Rate column explains the
   * Amount beside it.
   */
  qty?: number;
  unit?: string;
  rateValue?: number;
  /**
   * False for money the driver laid out and is simply being paid back — toll,
   * parking, and whatever they entered as "other". Those are reimbursements,
   * not our service, so no tax is charged on them and the figure printed must
   * be the exact amount the rider handed over.
   */
  taxable?: boolean;
}

interface FareBreakdown {
  lines: FareLine[];
  taxable: number;
  cgst: number;
  sgst: number;
  igst: number;
  taxTotal: number;
  total: number;
  roundOff: number;
  finalAmount: number;
  advance: number;
  balance: number;
}

/**
 * Turn the booking's stored amounts into invoice lines plus the tax split.
 *
 * The booking's own `gstAmount` wins when it is set — that is the tax actually
 * charged to the rider, and an invoice must state what was charged, not what a
 * later settings change would have charged. The template's rates only come into
 * play for older bookings that never stored one.
 */
function computeFare(data: InvoiceData, tax: Record<string, any>): FareBreakdown {
  const num = (v: any) => (typeof v === 'number' && isFinite(v) ? v : 0);
  const mode = tax.mode || 'cgst_sgst';
  const cgstPct = num(tax.cgstPercent);
  const sgstPct = num(tax.sgstPercent);
  const igstPct = num(tax.igstPercent);
  const totalPct = mode === 'igst' ? igstPct : mode === 'none' ? 0 : cgstPct + sgstPct;

  const gross = Math.max(0, num(data.fare));
  const toll = Math.max(0, num(data.tollAmount));
  const parking = Math.max(0, num(data.parkingCharge));
  const other = Math.max(0, num(data.otherCharge));
  const extraKmCharge = Math.max(0, num(data.extraCharge));
  const extraHrCharge = Math.max(0, num(data.extraHourCharge));
  const allowance = Math.max(0, num(data.driverAllowance));
  const storedGst = Math.max(0, num(data.gstAmount));

  // What the ride itself came to, once every itemised extra is taken out.
  const base = Math.max(0, gross - toll - parking - other - extraKmCharge - extraHrCharge - allowance - storedGst);

  const lines: FareLine[] = [];
  const svc = prettyService(data.serviceType);
  const route = [data.pickupCity || data.pickup, data.dropCity || data.drop].filter(Boolean).join(' to ');
  // Name the fare on the line, so an All Inclusive bill says why there is no
  // separate toll row — the same thing the driver's trip-end screen shows.
  const svcLabel = data.fareMode ? `${svc} (${data.fareMode})` : svc;
  // What the ride was actually billed for. On a minimum-km fare that is the
  // package (200 km) rather than the distance driven (91 km), so say which
  // number the amount beside it was worked out from.
  const billedKm = Math.max(0, num(data.includedKm)) || Math.max(0, num(data.distanceKm));
  const svcRoute = route ? `${svcLabel} - ${route}` : svcLabel;

  // The ride is billed at the admin's per-km rate and THEN discounted, so the
  // invoice shows both: km x rate as the gross, and the reduction as its own
  // line. Dividing the discounted total by the km instead would print a rate
  // the admin never set and quietly hide the discount from the rider.
  const storedRate = Math.max(0, num(data.ratePerKm));
  let grossBase = base;
  let baseRate = 0;
  if (billedKm > 0 && storedRate > 0 && Math.round(billedKm * storedRate) >= base) {
    // Priced at the admin's rate, then discounted down to `base`.
    grossBase = Math.round(billedKm * storedRate);
    baseRate = storedRate;
  } else if (num(data.includedKm) > 0) {
    // Booked before the rate was recorded. The discount the cab category
    // carried is the only thing that moved km x rate and the charged fare
    // apart, so it can be rebuilt — but ONLY for a booking that carries a real
    // billing basis (`includedKm`, written by the fare engine). Without one
    // there is nothing to say the fare was ever priced per km, and assuming a
    // discount would invent one the rider never got.
    const pct = Math.min(99, Math.max(0, num(data.discountPercent)));
    const g = pct > 0 ? Math.round(base / (1 - pct / 100)) : base;
    if (g >= base) {
      grossBase = g;
      baseRate = g / billedKm;
    }
  }
  // Whatever route got us here, the three cells must agree before any of them
  // is printed: a rate that does not multiply up to the amount is worse than
  // no rate at all.
  if (!(billedKm > 0) || Math.abs(billedKm * baseRate - grossBase) > 1) {
    grossBase = base;
    baseRate = 0;
  }
  const discount = grossBase > base ? grossBase - base : 0;

  lines.push({
    label: billedKm > 0 ? `${svcRoute} (${round2(billedKm)} km)` : svcRoute,
    qty: billedKm,
    unit: 'km',
    rateValue: baseRate,
    amount: grossBase,
  });
  if (discount > 0) {
    const pct = Math.round((discount / grossBase) * 100);
    lines.push({ label: pct > 0 ? `Discount (${pct}%)` : 'Discount', amount: -discount });
  }
  if (allowance > 0) lines.push({ label: 'Driver allowance', amount: allowance });
  if (extraKmCharge > 0) {
    // Extra km is billed at trip end at the snapshot rate and is not discounted.
    lines.push({ label: `Extra ${data.extraKm} km`, qty: num(data.extraKm), unit: 'km', rateValue: num(data.extraKmPrice), amount: extraKmCharge });
  }
  if (extraHrCharge > 0) {
    lines.push({ label: `Extra ${data.extraHours} hr`, qty: num(data.extraHours), unit: 'hr', rateValue: num(data.extraHourPrice), amount: extraHrCharge });
  }
  if (toll > 0) lines.push({ label: 'Toll', amount: toll, taxable: false });
  if (parking > 0) lines.push({ label: 'Parking', amount: parking, taxable: false });
  if (other > 0) lines.push({ label: 'Other charges', amount: other, taxable: false });

  // What the rider pays back at cost, and what they pay us for the service.
  const passThrough = lines.filter((l) => l.taxable === false).reduce((s, l) => s + l.amount, 0);
  const serviceTotal = lines.filter((l) => l.taxable !== false).reduce((s, l) => s + l.amount, 0);

  // How much tax this invoice states — on the service only.
  let taxTotal: number;
  let taxable: number;
  let rescaled = false;
  if (storedGst > 0) {
    // The booking recorded the tax actually charged; an invoice must state that.
    taxTotal = storedGst;
    taxable = serviceTotal;
  } else if (totalPct > 0 && tax.fareIncludesTax) {
    rescaled = true;
    // The fare already has tax inside it — pull it back out so the taxable
    // value plus the tax add up to what was charged. Only the service lines
    // are scaled; a reimbursement is printed at the amount actually paid.
    taxable = serviceTotal / (1 + totalPct / 100);
    taxTotal = serviceTotal - taxable;
    lines.forEach((l) => {
      if (l.taxable !== false) l.amount = l.amount / (1 + totalPct / 100);
    });
  } else if (totalPct > 0) {
    taxable = serviceTotal;
    taxTotal = (serviceTotal * totalPct) / 100;
  } else {
    taxable = serviceTotal;
    taxTotal = 0;
  }

  // Print the rate the ride was priced at. `rescaled` is the one case where it
  // cannot be shown: the fare had no GST recorded, so the tax was pulled back
  // out of every line above and the amounts no longer are qty x rate. Leaving
  // the cell empty there beats printing a rate that does not multiply out.
  for (const l of lines) {
    if (rescaled) { l.rate = undefined; continue; }
    if (!l.qty || l.qty <= 0 || !l.rateValue || l.rateValue <= 0) continue;
    l.rate = `Rs. ${round2(l.rateValue)}/${l.unit || 'km'}`;
  }

  let cgst = 0, sgst = 0, igst = 0;
  if (mode === 'igst') igst = taxTotal;
  else if (mode === 'cgst_sgst') {
    const split = cgstPct + sgstPct;
    cgst = split > 0 ? (taxTotal * cgstPct) / split : taxTotal / 2;
    sgst = taxTotal - cgst;
  }

  // The reimbursements sit outside the tax but inside what the rider pays.
  const total = taxable + taxTotal + passThrough;
  const rounded = Math.round(total);
  const roundOff = tax.showRoundOff ? rounded - total : 0;
  const finalAmount = tax.showRoundOff ? rounded : total;

  const advance = Math.max(0, Math.round(num(data.advanceAmount)));
  return {
    lines, taxable, cgst, sgst, igst, taxTotal, total, roundOff, finalAmount,
    advance, balance: Math.max(0, finalAmount - advance),
  };
}

// ─── field lookups used by the parties / trip blocks ─────────────────────────

function companyFieldValue(key: string, data: InvoiceData, company: Record<string, any>, invoice: Record<string, any>): [string, string] | null {
  switch (key) {
    case 'invoiceNo': return ['Invoice No', `${invoice.numberPrefix || 'INV'}-${data.bookingId}`];
    case 'invoiceDate': return ['Invoice Date', fmtDate(data.completedAt || data.travelDate, false)];
    case 'companyName': return ['Company Name', company.tradeName || company.legalName || ''];
    case 'address': return ['Address', company.address || ''];
    case 'phone': return ['Phone', company.phone || ''];
    case 'email': return ['Email', company.email || ''];
    case 'gstin': return ['GSTIN No', company.gstin || ''];
    case 'placeOfSupply': return ['Place of Supply', company.placeOfSupply || ''];
    default: return null;
  }
}

function customerFieldValue(key: string, data: InvoiceData): [string, string] | null {
  switch (key) {
    case 'customerName': return ['Customer Name', data.customerName || ''];
    case 'phone': return ['Phone', data.customerMobile || ''];
    case 'email': return ['Email ID', data.customerEmail || ''];
    case 'address': return ['Address', data.customerAddress || ''];
    case 'cabType': return ['Cab Type', [data.carName || data.vehicle, data.carClass].filter(Boolean).join(' ')];
    case 'package': return ['Package', data.subType || '-'];
    case 'serviceCategory': return ['Service Category', prettyService(data.serviceType)];
    case 'paymentMode': return ['Payment Mode', data.paymentMode || 'Cash'];
    default: return null;
  }
}

function tripFieldValue(key: string, data: InvoiceData): [string, string] | null {
  switch (key) {
    case 'pickup': return ['Pick-Up', data.pickup || data.pickupCity || '-'];
    case 'drop': return ['Drop', data.drop || data.dropCity || '-'];
    case 'pickupCity': return ['Pickup City', data.pickupCity || '-'];
    case 'dropCity': return ['Drop City', data.dropCity || '-'];
    case 'travelDate': return ['Travel Date', fmtDate(data.travelDate, false)];
    case 'travelTime': return ['Travel Time', data.travelTime || '-'];
    case 'returnDate': return ['Return Date', data.returnDate || '-'];
    case 'tripStart': return ['Trip Start', fmtDate(data.startedAt)];
    case 'tripEnd': return ['Trip End', fmtDate(data.completedAt)];
    case 'duration': return ['Duration', fmtDuration(data.startedAt, data.completedAt) || '-'];
    case 'distance': return ['Distance', data.distanceKm ? `${data.distanceKm} km` : '-'];
    case 'passengers': return ['Passengers', data.passengers ? String(data.passengers) : '-'];
    case 'driverName': return ['Driver', data.driverName || '-'];
    case 'driverPhone': return ['Driver Phone', data.driverPhone || '-'];
    case 'vehicle': return ['Vehicle', data.vehicle || '-'];
    case 'vehicleNumber': return ['Vehicle No', data.vehicleNumber || '-'];
    case 'includedKm': return ['Included KM', data.includedKm ? `${data.includedKm} km` : '-'];
    case 'trackedKm': return ['Travelled (GPS)', data.trackedKm != null ? `${data.trackedKm.toFixed(1)} km` : '-'];
    case 'extraKm': return ['Extra KM', data.extraKm ? `${data.extraKm} km` : '-'];
    case 'packageHours': return ['Package', data.packageHours ? `${data.packageHours} hrs` : '-'];
    default: return null;
  }
}

/** A local logo file for the default template, when no custom logo is uploaded. */
function builtInLogo(): Buffer | null {
  for (const p of [
    path.join(process.cwd(), 'assets', 'invoice-logo.png'),
    path.join(process.cwd(), 'uploads', 'invoice-logo.png'),
  ]) {
    try {
      if (fs.existsSync(p)) return fs.readFileSync(p);
    } catch { /* fall through to no logo */ }
  }
  return null;
}

/** Resolve an uploaded logo URL to bytes on disk (local storage only). */
function logoBytes(logoUrl?: string): Buffer | null {
  if (!logoUrl) return builtInLogo();
  try {
    const m = String(logoUrl).match(/\/uploads\/(.+)$/);
    if (m) {
      const p = path.join(process.cwd(), 'uploads', m[1].split('?')[0]);
      if (fs.existsSync(p)) return fs.readFileSync(p);
    }
  } catch { /* ignore — a missing logo must never fail the invoice */ }
  return builtInLogo();
}

// ─── the renderer ────────────────────────────────────────────────────────────

/**
 * Draw the invoice described by `template` for one booking and return the PDF.
 *
 * Blocks are drawn in the order the admin arranged them in the Invoice Design
 * page; a disabled block is skipped. Everything the admin can change lives in
 * the template, so this function holds layout only, never business wording.
 */
export function buildInvoicePdf(data: InvoiceData, template?: InvoiceTemplateLike): Promise<Buffer> {
  const t = template || (DEFAULT_INVOICE_TEMPLATE as InvoiceTemplateLike);
  const paper = { ...DEFAULT_INVOICE_TEMPLATE.paper, ...(t.paper || {}) };
  const company = { ...DEFAULT_INVOICE_TEMPLATE.company, ...(t.company || {}) };
  const tax = { ...DEFAULT_INVOICE_TEMPLATE.tax, ...(t.tax || {}) };
  const invoice = { ...DEFAULT_INVOICE_TEMPLATE.invoice, ...(t.invoice || {}) };
  const blocks = (t.blocks && t.blocks.length ? t.blocks : DEFAULT_INVOICE_TEMPLATE.blocks) as InvoiceBlock[];

  const M = Number(paper.margin) || 36;
  const FS = Number(paper.fontSize) || 9;
  const ACCENT = paper.accent || '#F26522';
  const TEXT = paper.text || '#1F2430';
  const MUTED = paper.muted || '#6B7280';
  const BORDER = paper.border || '#D1D5DB';
  const HEADBG = paper.headerBg || '#F3F4F6';

  const doc = new PDFDocument({ size: 'A4', margin: 0, bufferPages: true });
  const chunks: Buffer[] = [];
  doc.on('data', (c: Buffer) => chunks.push(c));
  const done = new Promise<Buffer>((resolve) => doc.on('end', () => resolve(Buffer.concat(chunks))));

  const pageW = doc.page.width;
  const pageH = doc.page.height;
  const W = pageW - M * 2;
  let y = M;

  const fare = computeFare(data, tax);

  /** Start a new page when the next block would not fit. */
  const ensure = (needed: number) => {
    if (y + needed <= pageH - M) return;
    doc.addPage();
    y = M;
  };

  const line = (x1: number, yy: number, x2: number) =>
    doc.moveTo(x1, yy).lineTo(x2, yy).lineWidth(0.7).strokeColor(BORDER).stroke();

  /** label: value, wrapped, returns the height used. */
  const kv = (label: string, value: string, x: number, w: number, yy: number): number => {
    const lw = Math.min(92, w * 0.42);
    doc.fillColor(MUTED).font('Helvetica').fontSize(FS).text(txt(label) + ':', x, yy, { width: lw - 4 });
    const vh = doc.fillColor(TEXT).font('Helvetica-Bold').fontSize(FS)
      .heightOfString(value || '-', { width: w - lw });
    doc.text(txt(value) || '-', x + lw, yy, { width: w - lw });
    return Math.max(doc.heightOfString(label + ':', { width: lw - 4 }), vh) + 3;
  };

  // ── block painters ─────────────────────────────────────────────────────────

  const drawLogo = (b: InvoiceBlock) => {
    const img = logoBytes(company.logoUrl);
    const w = Math.min(Number(b.props?.width) || 150, W);
    if (!img) {
      // No logo file — fall back to the company name so the top is never blank.
      ensure(26);
      doc.fillColor(ACCENT).font('Helvetica-Bold').fontSize(16)
        .text(company.tradeName || company.legalName || '', M, y, { width: W, align: b.props?.align || 'center' });
      y += 24;
      return;
    }
    ensure(60);
    const x = b.props?.align === 'left' ? M : b.props?.align === 'right' ? M + W - w : M + (W - w) / 2;
    try {
      doc.image(img, x, y, { width: w });
      // pdfkit advances y itself for images only when flowing; measure instead.
      y += (doc as any)._imageHeight || 46;
    } catch {
      y += 4;
    }
    y += 8;
  };

  const drawTitle = (b: InvoiceBlock) => {
    const text = b.props?.text || invoice.title || 'TAX INVOICE';
    const h = 22;
    ensure(h + 6);
    if (b.props?.boxed) {
      doc.rect(M, y, W, h).fillAndStroke(HEADBG, BORDER);
    }
    doc.fillColor(TEXT).font('Helvetica-Bold').fontSize(FS + 2)
      .text(txt(text).toUpperCase(), M, y + 6, { width: W, align: b.props?.align || 'center' });
    y += h + 8;
  };

  const drawParties = (b: InvoiceBlock) => {
    const left: Array<[string, string]> = (b.props?.leftFields || [])
      .map((k: string) => companyFieldValue(k, data, company, invoice))
      .filter(Boolean) as Array<[string, string]>;
    const right: Array<[string, string]> = (b.props?.rightFields || [])
      .map((k: string) => customerFieldValue(k, data))
      .filter(Boolean) as Array<[string, string]>;

    const colW = (W - 24) / 2;
    // Measure first so the surrounding box is drawn at the right height.
    const measure = (rows: Array<[string, string]>) => {
      let h = 0;
      const lw = Math.min(92, colW * 0.42);
      for (const [l, v] of rows) {
        doc.font('Helvetica-Bold').fontSize(FS);
        h += Math.max(
          doc.font('Helvetica').heightOfString(l + ':', { width: lw - 4 }),
          doc.font('Helvetica-Bold').heightOfString(v || '-', { width: colW - lw }),
        ) + 3;
      }
      return h;
    };
    const titleH = 16;
    const bodyH = Math.max(measure(left), measure(right));
    const boxH = titleH + bodyH + 14;
    ensure(boxH + 8);

    doc.rect(M, y, W, boxH).lineWidth(0.7).strokeColor(BORDER).stroke();
    let ly = y + 8;
    doc.fillColor(TEXT).font('Helvetica-Bold').fontSize(FS + 0.5)
      .text(b.props?.leftTitle || 'Company Details:', M + 10, ly, { width: colW });
    doc.text(b.props?.rightTitle || 'Customer Details:', M + 14 + colW + 10, ly, { width: colW });
    ly += titleH;
    let ry = ly;
    for (const [l, v] of left) ly += kv(l, v, M + 10, colW - 10, ly);
    for (const [l, v] of right) ry += kv(l, v, M + 14 + colW + 10, colW - 10, ry);
    y += boxH + 8;
  };

  const drawTrip = (b: InvoiceBlock) => {
    const rows: Array<[string, string]> = (b.props?.fields || [])
      .map((k: string) => tripFieldValue(k, data))
      .filter(Boolean) as Array<[string, string]>;
    if (!rows.length) return;
    const colW = (W - 24) / 2;
    const perCol = Math.ceil(rows.length / 2);
    const colA = rows.slice(0, perCol);
    const colB = rows.slice(perCol);
    const measure = (rr: Array<[string, string]>) => {
      let h = 0;
      const lw = Math.min(92, colW * 0.42);
      for (const [l, v] of rr) {
        h += Math.max(
          doc.font('Helvetica').fontSize(FS).heightOfString(l + ':', { width: lw - 4 }),
          doc.font('Helvetica-Bold').fontSize(FS).heightOfString(v || '-', { width: colW - lw }),
        ) + 3;
      }
      return h;
    };
    const titleH = 16;
    const boxH = titleH + Math.max(measure(colA), measure(colB)) + 14;
    ensure(boxH + 8);
    doc.rect(M, y, W, boxH).lineWidth(0.7).strokeColor(BORDER).stroke();
    doc.fillColor(TEXT).font('Helvetica-Bold').fontSize(FS + 0.5)
      .text(b.props?.title || 'Trip Details', M + 10, y + 8, { width: W - 20 });
    let ay = y + 8 + titleH, by = ay;
    for (const [l, v] of colA) ay += kv(l, v, M + 10, colW - 10, ay);
    for (const [l, v] of colB) by += kv(l, v, M + 14 + colW + 10, colW - 10, by);
    y += boxH + 8;
  };

  const drawFare = (b: InvoiceBlock) => {
    const amtW = 95, rateW = 80;
    const descW = W - amtW - rateW;
    const rowH = 18;

    ensure(60);
    doc.fillColor(TEXT).font('Helvetica-Bold').fontSize(FS + 0.5)
      .text(b.props?.title || 'Fare Details:', M, y);
    y += 16;

    // header
    doc.rect(M, y, W, rowH).fillAndStroke(HEADBG, BORDER);
    doc.fillColor(TEXT).font('Helvetica-Bold').fontSize(FS)
      .text(b.props?.descriptionLabel || 'Particulars', M + 6, y + 5, { width: descW - 12 })
      .text(b.props?.rateLabel || 'Rate', M + descW, y + 5, { width: rateW - 8, align: 'right' })
      .text(b.props?.amountLabel || 'Amount', M + descW + rateW, y + 5, { width: amtW - 8, align: 'right' });
    y += rowH;

    const money2 = (n: number) => money(n).replace('Rs. ', '');
    const row = (label: string, rate: string, amount: string, bold = false, bg?: string) => {
      const lh = doc.font(bold ? 'Helvetica-Bold' : 'Helvetica').fontSize(FS)
        .heightOfString(label, { width: descW - 12 });
      const h = Math.max(rowH, lh + 8);
      ensure(h);
      if (bg) doc.rect(M, y, W, h).fill(bg);
      doc.rect(M, y, W, h).lineWidth(0.5).strokeColor(BORDER).stroke();
      doc.fillColor(TEXT).font(bold ? 'Helvetica-Bold' : 'Helvetica').fontSize(FS)
        .text(txt(label), M + 6, y + 5, { width: descW - 12 })
        .text(rate, M + descW, y + 5, { width: rateW - 8, align: 'right' })
        .text(amount, M + descW + rateW, y + 5, { width: amtW - 8, align: 'right' });
      y += h;
    };

    for (const l of fare.lines) row(l.label, l.rate || '', money2(l.amount));

    if (tax.mode === 'cgst_sgst' && fare.taxTotal > 0) {
      row('CGST', `${tax.cgstPercent}%`, money2(fare.cgst));
      row('SGST', `${tax.sgstPercent}%`, money2(fare.sgst));
    } else if (tax.mode === 'igst' && fare.taxTotal > 0) {
      row('IGST', `${tax.igstPercent}%`, money2(fare.igst));
    }

    row('Total', '', money2(fare.total), true);
    if (tax.showRoundOff && Math.abs(fare.roundOff) >= 0.005) {
      row('Rounded Off', '', (fare.roundOff < 0 ? '-' : '') + money2(Math.abs(fare.roundOff)));
    }
    row('Final Amount', '', money2(fare.finalAmount), true, HEADBG);

    if (fare.advance > 0) {
      row('Advance paid (online)', '', '-' + money2(fare.advance));
      row('Balance payable', '', money2(fare.balance), true);
    }
    y += 10;
  };

  const drawWords = (b: InvoiceBlock) => {
    ensure(26);
    const label = b.props?.label || 'Amount in words:';
    doc.fillColor(MUTED).font('Helvetica').fontSize(FS).text(label, M, y, { width: W });
    y += 12;
    doc.fillColor(TEXT).font('Helvetica-Bold').fontSize(FS).text(amountInWords(fare.finalAmount), M, y, { width: W });
    y += doc.heightOfString(amountInWords(fare.finalAmount), { width: W }) + 10;
  };

  const drawTerms = (b: InvoiceBlock) => {
    const items: string[] = (b.props?.items || []).filter((s: string) => String(s || '').trim());
    if (!items.length) return;
    ensure(30);
    doc.fillColor(TEXT).font('Helvetica-Bold').fontSize(FS + 0.5)
      .text(b.props?.title || 'Terms & Conditions:', M, y, { width: W });
    y += 14;
    doc.font('Helvetica').fontSize(FS - 0.5).fillColor(MUTED);
    items.forEach((it, i) => {
      const text = txt(`${i + 1}. ${it}`);
      const h = doc.heightOfString(text, { width: W - 8 }) + 3;
      ensure(h);
      doc.fillColor(MUTED).font('Helvetica').fontSize(FS - 0.5).text(txt(text), M + 4, y, { width: W - 8 });
      y += h;
    });
    y += 8;
  };

  const drawNote = (b: InvoiceBlock) => {
    const text = String(b.props?.text || '').trim();
    if (!text) return;
    const h = doc.font('Helvetica-Bold').fontSize(FS).heightOfString(text, { width: W - 16 }) + 16;
    ensure(h + 6);
    doc.rect(M, y, W, h).lineWidth(0.7).strokeColor(BORDER).stroke();
    doc.fillColor(TEXT).font('Helvetica-Bold').fontSize(FS)
      .text(txt(text), M + 8, y + 8, { width: W - 16, align: b.props?.align || 'center' });
    y += h + 8;
  };

  const drawText = (b: InvoiceBlock) => {
    const text = String(b.props?.text || '').trim();
    if (!text) return;
    const size = Number(b.props?.size) || FS;
    const font = b.props?.bold ? 'Helvetica-Bold' : 'Helvetica';
    const h = doc.font(font).fontSize(size).heightOfString(text, { width: W }) + 6;
    ensure(h);
    doc.fillColor(b.props?.color || TEXT).font(font).fontSize(size)
      .text(txt(text), M, y, { width: W, align: b.props?.align || 'left' });
    y += h;
  };

  const drawDivider = () => {
    ensure(12);
    line(M, y + 4, M + W);
    y += 12;
  };

  const drawSpacer = (b: InvoiceBlock) => {
    y += Math.max(0, Number(b.props?.height) || 10);
  };

  // ── walk the design ────────────────────────────────────────────────────────
  for (const b of blocks) {
    if (!b || b.enabled === false) continue;
    switch (b.type) {
      case 'logo': drawLogo(b); break;
      case 'title': drawTitle(b); break;
      case 'parties': drawParties(b); break;
      case 'trip': drawTrip(b); break;
      case 'fare': drawFare(b); break;
      case 'amountInWords': drawWords(b); break;
      case 'terms': drawTerms(b); break;
      case 'note': drawNote(b); break;
      case 'text': drawText(b); break;
      case 'divider': drawDivider(); break;
      case 'spacer': drawSpacer(b); break;
      default: break;
    }
  }

  doc.end();
  return done;
}

/** A realistic booking used by the admin's "Download sample" button. */
/**
 * A stand-in booking for the Invoice Design preview.
 *
 * The GST is passed in rather than fixed so the preview answers the question
 * the admin is actually asking — "what does MY tax setting look like?" — and
 * so it goes down the same path a real booking does, which records the tax it
 * was charged instead of having it pulled back out of the total.
 */
// 200 km at Rs 100/km, less the cab's 10% discount, plus the driver allowance.
const SAMPLE_ALLOWANCE = 300;
const SAMPLE_NET = 18000 + SAMPLE_ALLOWANCE;

export function sampleInvoiceData(gstPercent = 0): InvoiceData {
  const sampleGst = Math.round((SAMPLE_NET * Math.max(0, gstPercent)) / 100);
  const now = new Date();
  const started = new Date(now.getTime() - 3 * 3600000);
  return {
    bookingId: 'CB2025000123',
    serviceType: 'cab',
    subType: 'One Way',
    customerName: 'Chandan Patel',
    customerMobile: '9088861449',
    customerEmail: 'chandanpatel@example.com',
    customerAddress: 'SLC Homes I, 14, 2nd Cross, Tavarekere, Bengaluru, 560029',
    driverName: 'Suresh Kumar',
    driverPhone: '9876543210',
    vehicle: 'Toyota Innova Crysta',
    vehicleNumber: 'GJ03AB1234',
    carName: 'Innova Crysta',
    carClass: 'A/C Sedan',
    pickup: 'Rajkot Railway Station, Rajkot',
    drop: 'Jamnagar Airport, Jamnagar',
    pickupCity: 'Rajkot',
    dropCity: 'Jamnagar',
    travelDate: now,
    travelTime: '09:30',
    startedAt: started,
    completedAt: now,
    // A realistic fare so the preview shows what a real invoice shows: a
    // 92 km trip billed on the 200 km minimum at Rs 100/km, less the cab's
    // 10% discount, plus the allowance, taxed at whatever the admin has set.
    distanceKm: 92,
    includedKm: 200,
    ratePerKm: 100,
    passengers: 3,
    fare: SAMPLE_NET + sampleGst,
    tollAmount: 0,
    driverAllowance: SAMPLE_ALLOWANCE,
    gstAmount: sampleGst,
    paymentMode: 'Cash — paid to the driver',
  };
}
