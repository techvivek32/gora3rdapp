import PDFDocument from 'pdfkit';

export interface InvoiceData {
  bookingId: string;
  serviceType: string;
  subType?: string;
  customerName: string;
  customerMobile?: string;
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
  ratePerKm?: number;
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
  // GST split (new bookings): driver allowance and the GST charged on
  // (base + allowance). Shown as their own lines in the Fare Summary.
  driverAllowance?: number;
  gstAmount?: number;
  fareMode?: string;
  paymentMode?: string;
  // Round-trip GPS extra-km billing (optional).
  includedKm?: number;
  trackedKm?: number;
  extraKm?: number;
  extraKmPrice?: number;
  extraCharge?: number;
  // Local hourly package (optional).
  packageHours?: number;
  extraHourPrice?: number;
  extraHours?: number;
  extraHourCharge?: number;
  // Advance paid to the platform (online) and the cash balance due to the driver.
  advanceAmount?: number;
}

const ORANGE = '#F26522';
const DARK = '#1F2430';
const GREY = '#6B7280';
const LIGHT = '#F3F4F6';

function fmtDate(d?: Date | string): string {
  if (!d) return '-';
  const dt = new Date(d);
  if (isNaN(dt.getTime())) return String(d);
  return dt.toLocaleString('en-IN', {
    day: '2-digit', month: 'short', year: 'numeric',
    hour: '2-digit', minute: '2-digit', hour12: true,
  });
}

function money(n?: number): string {
  const v = Math.max(0, Math.round(n || 0));
  return `Rs. ${v.toLocaleString('en-IN')}`;
}

/** "2h 15m" trip duration from start→end, or '' if unavailable. */
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
 * Build a one-page PDF ride invoice for a completed CustomerBooking and return
 * it as a Buffer. Pure programmatic drawing (pdfkit) — no headless browser.
 */
export function buildInvoicePdf(data: InvoiceData): Promise<Buffer> {
  const doc = new PDFDocument({ size: 'A4', margin: 0 });
  const chunks: Buffer[] = [];
  doc.on('data', (c: Buffer) => chunks.push(c));
  const done = new Promise<Buffer>((resolve) => doc.on('end', () => resolve(Buffer.concat(chunks))));

  const pageW = doc.page.width; // 595.28 for A4
  const M = 50; // content margin
  const contentW = pageW - M * 2;

  // ── Header band ──────────────────────────────────────────────────────────
  doc.rect(0, 0, pageW, 110).fill(ORANGE);
  doc.fillColor('#FFFFFF').font('Helvetica-Bold').fontSize(26).text('GORA CABS', M, 34);
  doc.font('Helvetica').fontSize(10).fillColor('#FFF3EC').text("India Ka Apna App", M, 66);
  doc.font('Helvetica-Bold').fontSize(20).fillColor('#FFFFFF').text('INVOICE', M, 34, { width: contentW, align: 'right' });
  doc.font('Helvetica').fontSize(10).fillColor('#FFF3EC')
    .text(`#${data.bookingId}`, M, 62, { width: contentW, align: 'right' })
    .text(`Date: ${fmtDate(data.completedAt || data.travelDate)}`, M, 76, { width: contentW, align: 'right' });

  let y = 140;

  // ── Parties (Customer / Driver) ──────────────────────────────────────────
  const colW = (contentW - 20) / 2;
  const boxH = 92;
  doc.roundedRect(M, y, colW, boxH, 6).fill(LIGHT);
  doc.roundedRect(M + colW + 20, y, colW, boxH, 6).fill(LIGHT);

  doc.fillColor(ORANGE).font('Helvetica-Bold').fontSize(9).text('CUSTOMER', M + 14, y + 12);
  doc.fillColor(DARK).font('Helvetica-Bold').fontSize(12).text(data.customerName || '-', M + 14, y + 28, { width: colW - 28 });
  doc.fillColor(GREY).font('Helvetica').fontSize(10).text(data.customerMobile || '-', M + 14, y + 48, { width: colW - 28 });

  const dx = M + colW + 20 + 14;
  doc.fillColor(ORANGE).font('Helvetica-Bold').fontSize(9).text('DRIVER', dx, y + 12);
  doc.fillColor(DARK).font('Helvetica-Bold').fontSize(12).text(data.driverName || '-', dx, y + 28, { width: colW - 28 });
  doc.fillColor(GREY).font('Helvetica').fontSize(10)
    .text(data.driverPhone || '-', dx, y + 48, { width: colW - 28 });
  const veh = [data.vehicle, data.vehicleNumber].filter(Boolean).join(' • ');
  if (veh) doc.text(veh, dx, y + 62, { width: colW - 28 });

  y += boxH + 18;

  // ── Trip details (compact 2-column zebra table — keeps the invoice one page) ─
  doc.fillColor(DARK).font('Helvetica-Bold').fontSize(13).text('Trip Details', M, y);
  y += 20;
  const carLine = [data.carName, data.carClass].filter(Boolean).join(' • ');
  const carExtra = [
    data.carSeats ? `${data.carSeats} seats` : '',
    data.carFuel || '',
    data.carBags || '',
  ].filter(Boolean).join(' • ');
  const isLocalTrip = data.subType === 'Local';
  type TEntry = { k: string; v: string; full?: boolean };
  const entries: TEntry[] = [
    { k: 'Service', v: [prettyService(data.serviceType), data.subType].filter(Boolean).join(' — ') },
    ...(carLine ? [{ k: 'Cab', v: carLine }] : []),
    ...((data.ratePerKm && data.ratePerKm > 0) ? [{ k: 'Rate', v: `Rs.${data.ratePerKm}/km` }] : []),
    ...(carExtra ? [{ k: 'Vehicle', v: carExtra, full: true }] : []),
    { k: 'Pickup', v: data.pickup || data.pickupCity || '-', full: true },
    // Local is an in-city package — no drop point, so skip the empty "Drop" row.
    ...((!isLocalTrip && (data.drop || data.dropCity)) ? [{ k: 'Drop', v: data.drop || data.dropCity || '-', full: true }] : []),
    { k: 'Trip start', v: fmtDate(data.startedAt) },
    { k: 'Trip end', v: fmtDate(data.completedAt) },
    ...(fmtDuration(data.startedAt, data.completedAt) ? [{ k: 'Duration', v: fmtDuration(data.startedAt, data.completedAt) }] : []),
    ...(data.returnDate ? [{ k: 'Return date', v: data.returnDate }] : []),
    ...((data.packageHours && data.packageHours > 0)
      ? [
          { k: 'Package', v: `${data.packageHours} hrs${data.includedKm ? ` · ${data.includedKm} km` : ''}` },
          ...((data.extraHourPrice && data.extraHourPrice > 0) ? [{ k: 'Extra hr rate', v: `Rs.${data.extraHourPrice}/hr` }] : []),
          ...((data.extraHours && data.extraHours > 0) ? [{ k: 'Extra hours', v: `${data.extraHours} hr` }] : []),
        ]
      : []),
    ...((!data.packageHours || data.packageHours <= 0)
      ? [{ k: 'Distance', v: data.distanceKm ? `${data.distanceKm} km${data.subType === 'Round Trip' ? ' (round)' : ''}` : '-' }]
      : []),
    { k: 'Passengers', v: data.passengers ? String(data.passengers) : '-' },
    ...((data.includedKm && data.includedKm > 0)
      ? [
          { k: 'Included KM', v: `${data.includedKm} km` },
          { k: 'Travelled (GPS)', v: `${(data.trackedKm ?? 0).toFixed(1)} km` },
          ...((data.extraKm && data.extraKm > 0) ? [{ k: 'Extra KM', v: `${data.extraKm} km` }] : []),
        ]
      : []),
  ];

  const LBL = 88;
  const half = contentW / 2;
  const tableTop = y;
  const drawKV = (k: string, v: string, x: number, w: number, vy: number) => {
    doc.fillColor(GREY).font('Helvetica').fontSize(7.5).text(k.toUpperCase(), x + 8, vy + 1, { width: LBL - 12 });
    doc.fillColor(DARK).font('Helvetica-Bold').fontSize(9.5).text(v || '-', x + LBL, vy, { width: w - LBL - 10, lineBreak: false, ellipsis: true });
  };
  let rowStripe = false;
  let ei = 0;
  while (ei < entries.length) {
    const e = entries[ei];
    if (e.full) {
      const vw = contentW - LBL - 10;
      doc.font('Helvetica-Bold').fontSize(9.5);
      const h = Math.max(19, doc.heightOfString(e.v || '-', { width: vw }) + 8);
      doc.rect(M, y, contentW, h).fill(rowStripe ? LIGHT : '#FFFFFF');
      doc.fillColor(GREY).font('Helvetica').fontSize(7.5).text(e.k.toUpperCase(), M + 8, y + 5, { width: LBL - 12 });
      doc.fillColor(DARK).font('Helvetica-Bold').fontSize(9.5).text(e.v || '-', M + LBL, y + 4, { width: vw });
      y += h; rowStripe = !rowStripe; ei += 1;
    } else {
      const e2 = ei + 1 < entries.length && !entries[ei + 1].full ? entries[ei + 1] : null;
      const h = 19;
      doc.rect(M, y, contentW, h).fill(rowStripe ? LIGHT : '#FFFFFF');
      drawKV(e.k, e.v, M, half, y + 4);
      if (e2) drawKV(e2.k, e2.v, M + half, half, y + 4);
      y += h; rowStripe = !rowStripe; ei += e2 ? 2 : 1;
    }
  }
  doc.rect(M, tableTop, contentW, y - tableTop).lineWidth(0.5).strokeColor('#E5E7EB').stroke();

  y += 16;

  // ── Fare breakdown table ─────────────────────────────────────────────────
  const extraCharge = data.extraCharge && data.extraCharge > 0 ? data.extraCharge : 0;
  const extraHourCharge = data.extraHourCharge && data.extraHourCharge > 0 ? data.extraHourCharge : 0;
  const parkingCharge = data.parkingCharge && data.parkingCharge > 0 ? data.parkingCharge : 0;
  const otherCharge = data.otherCharge && data.otherCharge > 0 ? data.otherCharge : 0;
  const allowance = data.driverAllowance && data.driverAllowance > 0 ? Math.round(data.driverAllowance) : 0;
  const gst = data.gstAmount && data.gstAmount > 0 ? Math.round(data.gstAmount) : 0;
  // "Base fare" is whatever is left after every line we itemise below. GST and
  // driver allowance are only broken out for new bookings that store them; older
  // bookings have gst/allowance = 0, so the base stays the full pre-tax ride fare.
  const base = Math.max(0, Math.round(
    (data.fare || 0) - (data.tollAmount || 0) - extraCharge - extraHourCharge - parkingCharge - otherCharge - allowance - gst,
  ));
  const baseLabel = (gst > 0 || allowance > 0) ? 'Base fare' : 'Ride fare';
  const items: [string, number][] = [[baseLabel + (data.fareMode ? ` (${data.fareMode})` : ''), base]];
  if (allowance > 0) items.push(['Driver allowance', allowance]);
  if (extraCharge > 0) items.push([`Extra ${data.extraKm} km @ Rs.${data.extraKmPrice}/km`, extraCharge]);
  if (extraHourCharge > 0) items.push([`Extra ${data.extraHours} hr @ Rs.${data.extraHourPrice}/hr`, extraHourCharge]);
  if (data.tollAmount && data.tollAmount > 0) items.push(['Toll', data.tollAmount]);
  if (parkingCharge > 0) items.push(['Parking', parkingCharge]);
  if (otherCharge > 0) items.push(['Other charges', otherCharge]);
  if (gst > 0) {
    // GST is charged on (base + driver allowance); derive the rate for the label.
    const pct = (base + allowance) > 0 ? Math.round((gst / (base + allowance)) * 100) : 0;
    items.push([`GST${pct > 0 ? ` (${pct}%)` : ''}`, gst]);
  }
  const advance = Math.max(0, Math.round(data.advanceAmount || 0));

  doc.fillColor(DARK).font('Helvetica-Bold').fontSize(13).text('Fare Summary', M, y);
  y += 20;

  // header row
  doc.rect(M, y, contentW, 24).fill(DARK);
  doc.fillColor('#FFFFFF').font('Helvetica-Bold').fontSize(10)
    .text('DESCRIPTION', M + 12, y + 7)
    .text('AMOUNT', M, y + 7, { width: contentW - 12, align: 'right' });
  y += 24;

  doc.font('Helvetica').fontSize(10.5);
  let stripe = false;
  for (const [label, amt] of items) {
    doc.rect(M, y, contentW, 22).fill(stripe ? LIGHT : '#FFFFFF');
    doc.fillColor(DARK).text(label, M + 12, y + 6, { width: contentW - 120 });
    doc.text(money(amt), M, y + 6, { width: contentW - 12, align: 'right' });
    y += 22;
    stripe = !stripe;
  }

  // total row
  doc.rect(M, y, contentW, 30).fill(ORANGE);
  doc.fillColor('#FFFFFF').font('Helvetica-Bold').fontSize(13)
    .text('TOTAL', M + 12, y + 8)
    .text(money(data.fare), M, y + 8, { width: contentW - 12, align: 'right' });
  y += 30;

  // Advance paid (online) + the cash balance due to the driver.
  if (advance > 0) {
    const balance = Math.max(0, Math.round((data.fare || 0) - advance));
    doc.font('Helvetica').fontSize(10.5);
    doc.rect(M, y, contentW, 22).fill('#FFFFFF');
    doc.fillColor(DARK).text('Advance paid (online)', M + 12, y + 6, { width: contentW - 120 });
    doc.text(`- ${money(advance)}`, M, y + 6, { width: contentW - 12, align: 'right' });
    y += 22;
    doc.rect(M, y, contentW, 26).fill(LIGHT);
    doc.font('Helvetica-Bold').fontSize(12).fillColor(DARK)
      .text('Balance (cash to driver)', M + 12, y + 7, { width: contentW - 120 })
      .text(money(balance), M, y + 7, { width: contentW - 12, align: 'right' });
    y += 30;
  } else {
    y += 8;
  }

  // ── Payment note ─────────────────────────────────────────────────────────
  doc.roundedRect(M, y, contentW, 40, 6).fill(LIGHT);
  doc.fillColor(GREY).font('Helvetica-Bold').fontSize(9).text('PAYMENT', M + 14, y + 9);
  doc.fillColor(DARK).font('Helvetica').fontSize(11)
    .text(data.paymentMode || 'Cash — paid directly to the driver', M + 14, y + 21, { width: contentW - 28 });
  y += 60;

  // ── Footer ───────────────────────────────────────────────────────────────
  const footY = doc.page.height - 70;
  doc.moveTo(M, footY).lineTo(pageW - M, footY).lineWidth(1).strokeColor('#E5E7EB').stroke();
  doc.fillColor(GREY).font('Helvetica').fontSize(9)
    .text('This is a computer-generated invoice and does not require a signature.', M, footY + 10, { width: contentW, align: 'center' })
    .text('Thank you for riding with Gora Cabs — Har Safar, Gora Ke Saath.', M, footY + 24, { width: contentW, align: 'center' });

  doc.end();
  return done;
}

function prettyService(s?: string): string {
  switch (s) {
    case 'cab': return 'Cab Booking';
    case 'hire_driver': return 'Hire a Driver';
    case 'luxury': return 'Luxury';
    case 'car_pool': return 'Car Pool';
    default: return s || 'Booking';
  }
}
