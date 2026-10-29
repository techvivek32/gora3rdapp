import { Injectable, Logger } from '@nestjs/common';
import { InjectModel } from '@nestjs/mongoose';
import { Model } from 'mongoose';
import {
  InvoiceTemplate,
  InvoiceTemplateDocument,
  DEFAULT_INVOICE_TEMPLATE,
  INVOICE_BLOCK_TYPES,
  InvoiceBlock,
} from '../../database/schemas/invoice-template.schema';
import { SettingsService } from '../settings/settings.service';

const KEY = 'default';

/**
 * Stores the invoice design the admin builds in the Invoice Design page.
 *
 * There is exactly one saved design today. It is read on every invoice render,
 * so a bad save would break every download — hence the normalisation below,
 * which drops unknown block types and fills in anything the payload omitted.
 */
@Injectable()
export class InvoiceTemplateService {
  private readonly logger = new Logger(InvoiceTemplateService.name);

  constructor(
    @InjectModel(InvoiceTemplate.name) private model: Model<InvoiceTemplateDocument>,
    private readonly settings: SettingsService,
  ) {}

  /**
   * Fill in the tax rates from the ONE place GST is configured: Pricing Config.
   *
   * The invoice must charge what the fare engine charged, so the rate is not a
   * second thing to keep in step — it is read, and split: 12%% GST becomes
   * CGST 6%% + SGST 6%% within a state, or IGST 12%% across one.
   */
  async applyTaxRates(tpl: any): Promise<any> {
    let gst = 0;
    try {
      const s: any = await this.settings.getSettings();
      gst = Math.max(0, Math.min(100, Number(s?.gstPercent) || 0));
    } catch {
      gst = 0;
    }
    const half = Math.round((gst / 2) * 100) / 100;
    return {
      ...tpl,
      tax: {
        ...(tpl?.tax || {}),
        gstPercent: gst,
        cgstPercent: half,
        sgstPercent: gst - half,
        igstPercent: gst,
      },
    };
  }

  /** The saved design, or the built-in default when nothing has been saved. */
  async get(): Promise<any> {
    const doc = await this.model.findOne({ key: KEY }).lean();
    if (!doc) return this.applyTaxRates({ ...DEFAULT_INVOICE_TEMPLATE });
    return this.applyTaxRates({
      key: KEY,
      paper: { ...DEFAULT_INVOICE_TEMPLATE.paper, ...(doc.paper || {}) },
      company: { ...DEFAULT_INVOICE_TEMPLATE.company, ...(doc.company || {}) },
      tax: { ...DEFAULT_INVOICE_TEMPLATE.tax, ...(doc.tax || {}) },
      invoice: { ...DEFAULT_INVOICE_TEMPLATE.invoice, ...(doc.invoice || {}) },
      blocks: (doc.blocks && doc.blocks.length ? doc.blocks : DEFAULT_INVOICE_TEMPLATE.blocks) as InvoiceBlock[],
      updatedAt: (doc as any).updatedAt,
      updatedBy: doc.updatedBy,
    });
  }

  /**
   * The same read, but it must never throw: an invoice download should not fail
   * because the design could not be loaded — fall back to the default design.
   */
  async getSafe(): Promise<any> {
    try {
      return await this.get();
    } catch (e: any) {
      this.logger.error(`Could not load the invoice template, using the default: ${e?.message}`);
      return this.applyTaxRates({ ...DEFAULT_INVOICE_TEMPLATE });
    }
  }

  async update(body: any, updatedBy?: string): Promise<any> {
    const clean = this.normalise(body);
    await this.model.findOneAndUpdate(
      { key: KEY },
      { ...clean, key: KEY, ...(updatedBy ? { updatedBy } : {}) },
      { upsert: true, new: true, setDefaultsOnInsert: true },
    );
    return { message: 'Invoice design saved', data: await this.get() };
  }

  async reset(): Promise<any> {
    await this.model.deleteOne({ key: KEY });
    return { message: 'Invoice design reset to default', data: await this.get() };
  }

  /**
   * Keep only what the renderer understands.
   *
   * A block with an unknown `type` would simply be skipped when drawing, but it
   * would still take up a row in the builder and confuse the next editor, so it
   * is dropped on the way in instead.
   */
  private normalise(body: any) {
    const b = body || {};
    const blocks: InvoiceBlock[] = Array.isArray(b.blocks)
      ? b.blocks
          .filter((x: any) => x && (INVOICE_BLOCK_TYPES as readonly string[]).includes(x.type))
          .map((x: any, i: number) => ({
            id: String(x.id || `${x.type}-${i}`),
            type: x.type,
            enabled: x.enabled !== false,
            props: typeof x.props === 'object' && x.props ? x.props : {},
          }))
      : DEFAULT_INVOICE_TEMPLATE.blocks;

    const num = (v: any, fallback: number) => {
      const n = Number(v);
      return isFinite(n) ? n : fallback;
    };
    const d = DEFAULT_INVOICE_TEMPLATE;
    return {
      paper: {
        accent: b.paper?.accent || d.paper.accent,
        text: b.paper?.text || d.paper.text,
        muted: b.paper?.muted || d.paper.muted,
        border: b.paper?.border || d.paper.border,
        headerBg: b.paper?.headerBg || d.paper.headerBg,
        margin: Math.min(80, Math.max(16, num(b.paper?.margin, d.paper.margin))),
        fontSize: Math.min(14, Math.max(7, num(b.paper?.fontSize, d.paper.fontSize))),
      },
      company: {
        legalName: String(b.company?.legalName ?? d.company.legalName),
        tradeName: String(b.company?.tradeName ?? d.company.tradeName),
        address: String(b.company?.address ?? d.company.address),
        phone: String(b.company?.phone ?? ''),
        email: String(b.company?.email ?? ''),
        gstin: String(b.company?.gstin ?? d.company.gstin).toUpperCase(),
        placeOfSupply: String(b.company?.placeOfSupply ?? d.company.placeOfSupply),
        logoUrl: String(b.company?.logoUrl ?? ''),
      },
      tax: {
        // The rates are NOT stored: they are read from Pricing Config on every
        // load (see applyTaxRates), so changing GST in one place changes every
        // invoice. Only the choices that are genuinely the invoice's own are
        // kept here.
        mode: ['cgst_sgst', 'igst', 'none'].includes(b.tax?.mode) ? b.tax.mode : d.tax.mode,
        showRoundOff: b.tax?.showRoundOff !== false,
        fareIncludesTax: b.tax?.fareIncludesTax !== false,
      },
      invoice: {
        title: String(b.invoice?.title ?? d.invoice.title),
        numberPrefix: String(b.invoice?.numberPrefix ?? d.invoice.numberPrefix),
      },
      blocks,
    };
  }
}
