import { Prop, Schema, SchemaFactory } from '@nestjs/mongoose';
import { Document } from 'mongoose';

export type InvoiceTemplateDocument = InvoiceTemplate & Document;

/**
 * The sections an invoice can be built from. The admin arranges these in the
 * Invoice Design page; the order of `blocks` IS the order they are drawn in,
 * so moving a block in the panel moves it on the PDF.
 */
export const INVOICE_BLOCK_TYPES = [
  'logo',
  'title',
  'parties',
  'trip',
  'fare',
  'amountInWords',
  'terms',
  'note',
  'text',
  'divider',
  'spacer',
] as const;

export type InvoiceBlockType = (typeof INVOICE_BLOCK_TYPES)[number];

export interface InvoiceBlock {
  /** Stable id so the builder can reorder without React remounting rows. */
  id: string;
  type: InvoiceBlockType;
  enabled: boolean;
  /** Per-type options (see DEFAULT_INVOICE_TEMPLATE for the shape of each). */
  props: Record<string, any>;
}

/**
 * The fields a `parties` or `trip` block may show. Kept as a whitelist so the
 * admin picks from real booking data instead of typing a key that renders blank.
 */
export const INVOICE_COMPANY_FIELDS = [
  'invoiceNo', 'invoiceDate', 'companyName', 'address', 'phone', 'email', 'gstin', 'placeOfSupply',
] as const;

export const INVOICE_CUSTOMER_FIELDS = [
  'customerName', 'phone', 'email', 'address', 'cabType', 'package', 'serviceCategory', 'paymentMode',
] as const;

export const INVOICE_TRIP_FIELDS = [
  'pickup', 'drop', 'pickupCity', 'dropCity', 'travelDate', 'travelTime', 'returnDate',
  'tripStart', 'tripEnd', 'duration', 'distance', 'passengers', 'driverName', 'driverPhone',
  'vehicle', 'vehicleNumber', 'includedKm', 'trackedKm', 'extraKm', 'packageHours',
] as const;

@Schema({ timestamps: true, collection: 'invoice_templates' })
export class InvoiceTemplate {
  /** Only one template today ('default'); the key leaves room for more later. */
  @Prop({ required: true, unique: true, default: 'default' })
  key: string;

  /** Colours, margins and base type size for the whole page. */
  @Prop({ type: Object, default: {} })
  paper: Record<string, any>;

  /** The seller's own details — printed on every invoice. */
  @Prop({ type: Object, default: {} })
  company: Record<string, any>;

  /** CGST/SGST vs IGST, the rates, and whether to round the final amount. */
  @Prop({ type: Object, default: {} })
  tax: Record<string, any>;

  /** Invoice title text and the number prefix. */
  @Prop({ type: Object, default: {} })
  invoice: Record<string, any>;

  /** The design itself: which sections appear, in what order, configured how. */
  @Prop({ type: Array, default: [] })
  blocks: InvoiceBlock[];

  /** Who last saved the design (for the audit trail). */
  @Prop()
  updatedBy: string;
}

export const InvoiceTemplateSchema = SchemaFactory.createForClass(InvoiceTemplate);

/**
 * The invoice a fresh install starts with: a GST tax invoice laid out like the
 * one the business already issues — title band, company vs customer details,
 * trip details, a fare table with the tax split, amount in words, terms, note.
 *
 * This is also what "Reset to default" restores, so it must always be a
 * complete, valid design on its own.
 */
export const DEFAULT_INVOICE_TEMPLATE = {
  key: 'default',
  paper: {
    accent: '#F26522',
    text: '#1F2430',
    muted: '#6B7280',
    border: '#D1D5DB',
    headerBg: '#F3F4F6',
    margin: 36,
    fontSize: 9,
  },
  company: {
    legalName: 'GORA CABS & TRAVELS PRIVATE LIMITED',
    tradeName: 'GORA CABS & TRAVELS PRIVATE LIMITED',
    address: '132, Nayak Bhawan, Haripura Vyas Colony, Tempo Stand Airforce, Jodhpur, Rajasthan, 342011',
    phone: '',
    email: '',
    gstin: '08AAMCG5008P1Z3',
    placeOfSupply: 'Rajasthan (08)',
    logoUrl: '',
  },
  tax: {
    // 5% GST on cab service, split half CGST / half SGST for an intra-state ride.
    mode: 'cgst_sgst',
    cgstPercent: 2.5,
    sgstPercent: 2.5,
    igstPercent: 5,
    showRoundOff: true,
    // The stored fare already includes GST, so the invoice shows the tax it
    // contains rather than adding more on top.
    fareIncludesTax: true,
  },
  invoice: {
    title: 'ORIGINAL TAX INVOICE',
    numberPrefix: 'INV',
  },
  blocks: [
    { id: 'logo', type: 'logo', enabled: true, props: { align: 'center', width: 150 } },
    { id: 'title', type: 'title', enabled: true, props: { text: 'ORIGINAL TAX INVOICE', align: 'center', boxed: true } },
    {
      id: 'parties',
      type: 'parties',
      enabled: true,
      props: {
        leftTitle: 'Company Details:',
        rightTitle: 'Customer Details:',
        leftFields: ['invoiceNo', 'invoiceDate', 'companyName', 'address', 'phone', 'gstin', 'placeOfSupply'],
        rightFields: ['customerName', 'phone', 'email', 'cabType', 'package', 'serviceCategory'],
      },
    },
    {
      id: 'trip',
      type: 'trip',
      enabled: true,
      props: {
        title: 'Trip Details',
        fields: ['pickup', 'drop', 'travelDate', 'distance', 'driverName', 'vehicleNumber'],
      },
    },
    {
      id: 'fare',
      type: 'fare',
      enabled: true,
      props: { title: 'Fare Details:', descriptionLabel: 'Particulars', rateLabel: 'Rate', amountLabel: 'Amount' },
    },
    { id: 'words', type: 'amountInWords', enabled: true, props: { label: 'Amount in words:' } },
    {
      id: 'terms',
      type: 'terms',
      enabled: true,
      props: {
        title: 'Terms & Conditions:',
        items: [
          'Fare includes base rate, distance/time charges, and applicable taxes.',
          'Additional charges apply for tolls, parking, waiting time, extra stops.',
          'Cancellations or no-shows may incur a fee as per company policy.',
          'Customers are expected to treat drivers with respect and avoid any disruptive or unlawful behaviour.',
          'Customers are responsible for their own belongings and should ensure they are kept safely during the ride.',
          'Customers may be held responsible for any damage to the vehicle caused by their actions.',
          'Payment must be made in full upon trip completion unless prepaid.',
          'Refunds for cancellations are subject to the terms and conditions of the company.',
        ],
      },
    },
    {
      id: 'note',
      type: 'note',
      enabled: true,
      props: { text: '**This is a computer generated receipt and does not require any signature or stamp**', align: 'center' },
    },
  ] as InvoiceBlock[],
};
