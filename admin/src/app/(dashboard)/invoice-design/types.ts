/** Shared shapes + sample data for the Invoice Design page and its preview. */

export type InvoiceBlockType =
  | 'logo' | 'title' | 'parties' | 'trip' | 'fare'
  | 'amountInWords' | 'terms' | 'note' | 'text' | 'divider' | 'spacer';

export interface InvoiceBlock {
  id: string;
  type: InvoiceBlockType;
  enabled: boolean;
  props: Record<string, any>;
}

export interface InvoiceTemplate {
  paper: Record<string, any>;
  company: Record<string, any>;
  tax: Record<string, any>;
  invoice: Record<string, any>;
  blocks: InvoiceBlock[];
}

export const BLOCK_LABELS: Record<InvoiceBlockType, string> = {
  logo: 'Logo / Brand',
  title: 'Invoice title',
  parties: 'Company & Customer details',
  trip: 'Trip details',
  fare: 'Fare table (with tax)',
  amountInWords: 'Amount in words',
  terms: 'Terms & conditions',
  note: 'Footer note',
  text: 'Free text',
  divider: 'Divider line',
  spacer: 'Blank space',
};

/** Blocks that only make sense once — the "Add block" menu hides duplicates. */
export const SINGLE_USE: InvoiceBlockType[] = [
  'logo', 'title', 'parties', 'trip', 'fare', 'amountInWords', 'terms',
];

export const COMPANY_FIELDS: Array<[string, string]> = [
  ['invoiceNo', 'Invoice No'],
  ['invoiceDate', 'Invoice Date'],
  ['companyName', 'Company Name'],
  ['address', 'Address'],
  ['phone', 'Phone'],
  ['email', 'Email'],
  ['gstin', 'GSTIN No'],
  ['placeOfSupply', 'Place of Supply'],
];

export const CUSTOMER_FIELDS: Array<[string, string]> = [
  ['customerName', 'Customer Name'],
  ['phone', 'Phone'],
  ['email', 'Email ID'],
  ['address', 'Address'],
  ['cabType', 'Cab Type'],
  ['package', 'Package'],
  ['serviceCategory', 'Service Category'],
  ['paymentMode', 'Payment Mode'],
];

export const TRIP_FIELDS: Array<[string, string]> = [
  ['pickup', 'Pick-Up'],
  ['drop', 'Drop'],
  ['pickupCity', 'Pickup City'],
  ['dropCity', 'Drop City'],
  ['travelDate', 'Travel Date'],
  ['travelTime', 'Travel Time'],
  ['returnDate', 'Return Date'],
  ['tripStart', 'Trip Start'],
  ['tripEnd', 'Trip End'],
  ['duration', 'Duration'],
  ['distance', 'Distance'],
  ['passengers', 'Passengers'],
  ['driverName', 'Driver'],
  ['driverPhone', 'Driver Phone'],
  ['vehicle', 'Vehicle'],
  ['vehicleNumber', 'Vehicle No'],
  ['includedKm', 'Included KM'],
  ['trackedKm', 'Travelled (GPS)'],
  ['extraKm', 'Extra KM'],
  ['packageHours', 'Package'],
];

/** Mirrors sampleInvoiceData() on the server so the preview matches the PDF. */
export const SAMPLE = {
  bookingId: 'CB2025000123',
  serviceCategory: 'Cab Service',
  subType: 'One Way',
  customerName: 'Chandan Patel',
  customerMobile: '9088861449',
  customerEmail: 'chandanpatel@example.com',
  customerAddress: 'SLC Homes I, 14, 2nd Cross, Tavarekere, Bengaluru, 560029',
  driverName: 'Suresh Kumar',
  driverPhone: '9876543210',
  vehicle: 'Toyota Innova Crysta',
  vehicleNumber: 'GJ03AB1234',
  cabType: 'Innova Crysta A/C Sedan',
  pickup: 'Rajkot Railway Station, Rajkot',
  drop: 'Jamnagar Airport, Jamnagar',
  pickupCity: 'Rajkot',
  dropCity: 'Jamnagar',
  travelDate: '29 Oct 2026',
  travelTime: '09:30',
  duration: '3h 0m',
  distanceKm: 92,
  // Billed on the 200 km minimum at Rs 100/km, less the cab's 10% discount.
  includedKm: 200,
  ratePerKm: 100,
  passengers: 3,
  // The GST — and so the total — follow the tax setting being previewed; see
  // previewFare. These are the net figures everything else is built from.
  netBeforeTax: 18300,
  driverAllowance: 300,
  paymentMode: 'Cash',
};

/** The same arithmetic the PDF renderer does, so the preview totals agree. */
export function previewFare(tax: Record<string, any>) {
  const n = (v: any) => (typeof v === 'number' && isFinite(v) ? v : Number(v) || 0);
  const mode = tax?.mode || 'cgst_sgst';
  const cg = n(tax?.cgstPercent), sg = n(tax?.sgstPercent), ig = n(tax?.igstPercent);
  const totalPct = mode === 'igst' ? ig : mode === 'none' ? 0 : cg + sg;

  const allowance = SAMPLE.driverAllowance;
  // The sample is taxed at the rate being previewed, exactly as the server
  // does it, so a real booking and this preview take the same code path.
  const storedGst = Math.round((n(SAMPLE.netBeforeTax) * Math.max(0, totalPct)) / 100);
  const base = n(SAMPLE.netBeforeTax) - allowance;
  // Mirror the PDF: the ride is billed at the admin's per-km rate and THEN
  // discounted, so the gross (km x rate) and the discount are separate lines.
  const billedKm = n(SAMPLE.includedKm) || n(SAMPLE.distanceKm);
  const rate = n(SAMPLE.ratePerKm);
  const gross = billedKm > 0 && rate > 0 && Math.round(billedKm * rate) >= base
    ? Math.round(billedKm * rate) : base;
  const discount = gross > base ? gross - base : 0;

  const lines: { label: string; rate: string; amount: number; qty?: number; unit?: string; rateValue?: number }[] = [
    {
      label: `${SAMPLE.serviceCategory} - ${SAMPLE.pickupCity} to ${SAMPLE.dropCity}${billedKm > 0 ? ` (${billedKm} km)` : ''}`,
      rate: '', qty: billedKm, unit: 'km', rateValue: discount > 0 || gross === base ? rate : 0, amount: gross,
    },
  ];
  if (discount > 0) {
    lines.push({ label: `Discount (${Math.round((discount / gross) * 100)}%)`, rate: '', amount: -discount });
  }
  lines.push({ label: 'Driver allowance', rate: '', amount: allowance });
  const itemTotal = lines.reduce((s, l) => s + l.amount, 0);

  let taxable = itemTotal, taxTotal = 0;
  let rescaled = false;
  if (storedGst > 0) {
    taxTotal = storedGst;
  } else if (totalPct > 0 && tax?.fareIncludesTax !== false) {
    rescaled = true;
    taxable = itemTotal / (1 + totalPct / 100);
    taxTotal = itemTotal - taxable;
    lines.forEach((l) => { l.amount = l.amount / (1 + totalPct / 100); });
  } else if (totalPct > 0) {
    taxTotal = (itemTotal * totalPct) / 100;
  }

  // Same rule as the PDF: print the rate the ride was priced at, and nothing
  // at all once the tax has been pulled back out of the line amounts.
  const round2 = (v: number) => {
    const r = Math.round(v * 100) / 100;
    return Number.isInteger(r) ? String(r) : r.toFixed(2);
  };
  lines.forEach((l) => {
    if (rescaled || !l.qty || l.qty <= 0 || !l.rateValue || l.rateValue <= 0) return;
    l.rate = `Rs. ${round2(l.rateValue)}/${l.unit || 'km'}`;
  });

  let cgst = 0, sgst = 0, igst = 0;
  if (mode === 'igst') igst = taxTotal;
  else if (mode === 'cgst_sgst') {
    const split = cg + sg;
    cgst = split > 0 ? (taxTotal * cg) / split : taxTotal / 2;
    sgst = taxTotal - cgst;
  }
  const total = taxable + taxTotal;
  const rounded = Math.round(total);
  const showRound = tax?.showRoundOff !== false;
  return {
    lines, taxable, cgst, sgst, igst, taxTotal, total,
    roundOff: showRound ? rounded - total : 0,
    finalAmount: showRound ? rounded : total,
  };
}

export const money2 = (v: number) =>
  (Math.round(v * 100) / 100).toLocaleString('en-IN', { minimumFractionDigits: 2, maximumFractionDigits: 2 });

const ONES = ['', 'One', 'Two', 'Three', 'Four', 'Five', 'Six', 'Seven', 'Eight', 'Nine', 'Ten',
  'Eleven', 'Twelve', 'Thirteen', 'Fourteen', 'Fifteen', 'Sixteen', 'Seventeen', 'Eighteen', 'Nineteen'];
const TENS = ['', '', 'Twenty', 'Thirty', 'Forty', 'Fifty', 'Sixty', 'Seventy', 'Eighty', 'Ninety'];
const two = (x: number) => (x < 20 ? ONES[x] : (TENS[Math.floor(x / 10)] + (x % 10 ? ' ' + ONES[x % 10] : '')).trim());

export function amountInWords(amount: number): string {
  const nn = Math.floor(Math.abs(amount));
  if (nn === 0) return 'Rupees Zero Only';
  const parts: string[] = [];
  const cr = Math.floor(nn / 10000000);
  const lk = Math.floor((nn % 10000000) / 100000);
  const th = Math.floor((nn % 100000) / 1000);
  const hu = Math.floor((nn % 1000) / 100);
  const rest = nn % 100;
  if (cr) parts.push(two(cr) + ' Crore');
  if (lk) parts.push(two(lk) + ' Lakh');
  if (th) parts.push(two(th) + ' Thousand');
  if (hu) parts.push(ONES[hu] + ' Hundred');
  if (rest) parts.push(two(rest));
  return 'Rupees ' + parts.join(' ') + ' Only';
}

export const companyFieldValue = (key: string, c: Record<string, any>, inv: Record<string, any>): [string, string] | null => {
  switch (key) {
    case 'invoiceNo': return ['Invoice No', `${inv?.numberPrefix || 'INV'}-${SAMPLE.bookingId}`];
    case 'invoiceDate': return ['Invoice Date', SAMPLE.travelDate];
    case 'companyName': return ['Company Name', c?.tradeName || c?.legalName || ''];
    case 'address': return ['Address', c?.address || ''];
    case 'phone': return ['Phone', c?.phone || ''];
    case 'email': return ['Email', c?.email || ''];
    case 'gstin': return ['GSTIN No', c?.gstin || ''];
    case 'placeOfSupply': return ['Place of Supply', c?.placeOfSupply || ''];
    default: return null;
  }
};

export const customerFieldValue = (key: string): [string, string] | null => {
  switch (key) {
    case 'customerName': return ['Customer Name', SAMPLE.customerName];
    case 'phone': return ['Phone', SAMPLE.customerMobile];
    case 'email': return ['Email ID', SAMPLE.customerEmail];
    case 'address': return ['Address', SAMPLE.customerAddress];
    case 'cabType': return ['Cab Type', SAMPLE.cabType];
    case 'package': return ['Package', SAMPLE.subType];
    case 'serviceCategory': return ['Service Category', SAMPLE.serviceCategory];
    case 'paymentMode': return ['Payment Mode', SAMPLE.paymentMode];
    default: return null;
  }
};

export const tripFieldValue = (key: string): [string, string] | null => {
  switch (key) {
    case 'pickup': return ['Pick-Up', SAMPLE.pickup];
    case 'drop': return ['Drop', SAMPLE.drop];
    case 'pickupCity': return ['Pickup City', SAMPLE.pickupCity];
    case 'dropCity': return ['Drop City', SAMPLE.dropCity];
    case 'travelDate': return ['Travel Date', SAMPLE.travelDate];
    case 'travelTime': return ['Travel Time', SAMPLE.travelTime];
    case 'returnDate': return ['Return Date', '-'];
    case 'tripStart': return ['Trip Start', `${SAMPLE.travelDate}, 06:30 AM`];
    case 'tripEnd': return ['Trip End', `${SAMPLE.travelDate}, 09:30 AM`];
    case 'duration': return ['Duration', SAMPLE.duration];
    case 'distance': return ['Distance', `${SAMPLE.distanceKm} km`];
    case 'passengers': return ['Passengers', String(SAMPLE.passengers)];
    case 'driverName': return ['Driver', SAMPLE.driverName];
    case 'driverPhone': return ['Driver Phone', SAMPLE.driverPhone];
    case 'vehicle': return ['Vehicle', SAMPLE.vehicle];
    case 'vehicleNumber': return ['Vehicle No', SAMPLE.vehicleNumber];
    case 'includedKm': return ['Included KM', '-'];
    case 'trackedKm': return ['Travelled (GPS)', '-'];
    case 'extraKm': return ['Extra KM', '-'];
    case 'packageHours': return ['Package', '-'];
    default: return null;
  }
};

/** A fresh block of the given type, with sensible starting props. */
export function newBlock(type: InvoiceBlockType): InvoiceBlock {
  const id = `${type}-${Math.random().toString(36).slice(2, 8)}`;
  const props: Record<string, any> = {};
  switch (type) {
    case 'logo': Object.assign(props, { align: 'center', width: 150 }); break;
    case 'title': Object.assign(props, { text: 'TAX INVOICE', align: 'center', boxed: true }); break;
    case 'parties': Object.assign(props, {
      leftTitle: 'Company Details:', rightTitle: 'Customer Details:',
      leftFields: ['invoiceNo', 'invoiceDate', 'companyName', 'address', 'gstin', 'placeOfSupply'],
      rightFields: ['customerName', 'phone', 'email', 'cabType', 'package', 'serviceCategory'],
    }); break;
    case 'trip': Object.assign(props, { title: 'Trip Details', fields: ['pickup', 'drop', 'travelDate', 'distance'] }); break;
    case 'fare': Object.assign(props, { title: 'Fare Details:', descriptionLabel: 'Particulars', rateLabel: 'Rate', amountLabel: 'Amount' }); break;
    case 'amountInWords': Object.assign(props, { label: 'Amount in words:' }); break;
    case 'terms': Object.assign(props, { title: 'Terms & Conditions:', items: ['Fare includes base rate, distance/time charges, and applicable taxes.'] }); break;
    case 'note': Object.assign(props, { text: '**This is a computer generated receipt and does not require any signature or stamp**', align: 'center' }); break;
    case 'text': Object.assign(props, { text: 'Thank you for riding with us.', align: 'center', bold: false, size: 9 }); break;
    case 'spacer': Object.assign(props, { height: 12 }); break;
    default: break;
  }
  return { id, type, enabled: true, props };
}
