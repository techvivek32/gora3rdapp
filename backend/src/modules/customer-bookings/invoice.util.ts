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
  pickup?: string;
  drop?: string;
  pickupCity?: string;
  dropCity?: string;
  travelDate?: Date | string;
  travelTime?: string;
  startedAt?: Date | string;
  completedAt?: Date | string;
  distanceKm?: number;
  passengers?: number;
  fare: number;
  tollAmount?: number;
  fareMode?: string;
  paymentMode?: string;
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

  y += boxH + 24;

  // ── Trip details ─────────────────────────────────────────────────────────
  doc.fillColor(DARK).font('Helvetica-Bold').fontSize(13).text('Trip Details', M, y);
  y += 22;
  const rows: [string, string][] = [
    ['Service', [prettyService(data.serviceType), data.subType].filter(Boolean).join(' — ')],
    ['Pickup', data.pickup || data.pickupCity || '-'],
    ['Drop', data.drop || data.dropCity || '-'],
    ['Trip start', fmtDate(data.startedAt)],
    ['Trip end', fmtDate(data.completedAt)],
    ['Distance', data.distanceKm ? `${data.distanceKm} km` : '-'],
    ['Passengers', data.passengers ? String(data.passengers) : '-'],
  ];
  doc.font('Helvetica').fontSize(10);
  for (const [k, v] of rows) {
    doc.fillColor(GREY).text(k, M, y, { width: 110 });
    doc.fillColor(DARK).text(v, M + 120, y, { width: contentW - 120 });
    y = doc.y + 8;
  }

  y += 8;

  // ── Fare breakdown table ─────────────────────────────────────────────────
  doc.fillColor(DARK).font('Helvetica-Bold').fontSize(13).text('Fare Summary', M, y);
  y += 22;

  const base = Math.max(0, Math.round((data.fare || 0) - (data.tollAmount || 0)));
  const items: [string, number][] = [['Ride fare' + (data.fareMode ? ` (${data.fareMode})` : ''), base]];
  if (data.tollAmount && data.tollAmount > 0) items.push(['Toll / taxes', data.tollAmount]);

  // header row
  doc.rect(M, y, contentW, 26).fill(DARK);
  doc.fillColor('#FFFFFF').font('Helvetica-Bold').fontSize(10)
    .text('DESCRIPTION', M + 12, y + 8)
    .text('AMOUNT', M, y + 8, { width: contentW - 12, align: 'right' });
  y += 26;

  doc.font('Helvetica').fontSize(11);
  let stripe = false;
  for (const [label, amt] of items) {
    doc.rect(M, y, contentW, 24).fill(stripe ? LIGHT : '#FFFFFF');
    doc.fillColor(DARK).text(label, M + 12, y + 6, { width: contentW - 120 });
    doc.text(money(amt), M, y + 6, { width: contentW - 12, align: 'right' });
    y += 24;
    stripe = !stripe;
  }

  // total row
  doc.rect(M, y, contentW, 32).fill(ORANGE);
  doc.fillColor('#FFFFFF').font('Helvetica-Bold').fontSize(13)
    .text('TOTAL', M + 12, y + 9)
    .text(money(data.fare), M, y + 9, { width: contentW - 12, align: 'right' });
  y += 44;

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
