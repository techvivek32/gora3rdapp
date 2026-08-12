import { Injectable, Logger } from '@nestjs/common';
import Anthropic from '@anthropic-ai/sdk';

/** Structured result of parsing a free-form WhatsApp taxi message. Empty strings for missing fields. */
export interface ParsedWhatsappBooking {
  kind: 'requirement' | 'available' | 'unknown';
  pickupCity: string;
  dropCity: string;
  date: string; // as written, e.g. "15/07/2026", "tomorrow", or ""
  time: string; // e.g. "09:00 PM" or ""
  vehicle: string; // free text e.g. "sedan", "innova crysta", or ""
  tripType: string; // one_way | round_trip | airport | local | outstation | ""
  driverEarning: string; // digits only, or ""
  commission: string; // digits only, or ""
  contactNumber: string; // customer's number (digits), or ""
  notes: string;
}

const EMPTY: ParsedWhatsappBooking = {
  kind: 'unknown', pickupCity: '', dropCity: '', date: '', time: '',
  vehicle: '', tripType: '', driverEarning: '', commission: '', contactNumber: '', notes: '',
};

const SCHEMA = {
  type: 'object',
  additionalProperties: false,
  properties: {
    kind: { type: 'string', enum: ['requirement', 'available', 'unknown'] },
    pickupCity: { type: 'string' },
    dropCity: { type: 'string' },
    date: { type: 'string' },
    time: { type: 'string' },
    vehicle: { type: 'string' },
    tripType: { type: 'string' },
    driverEarning: { type: 'string' },
    commission: { type: 'string' },
    contactNumber: { type: 'string' },
    notes: { type: 'string' },
  },
  required: [
    'kind', 'pickupCity', 'dropCity', 'date', 'time', 'vehicle',
    'tripType', 'driverEarning', 'commission', 'contactNumber', 'notes',
  ],
};

const SYSTEM_PROMPT = `You extract structured fields from a single WhatsApp message posted in an Indian taxi/cab operators group. Messages are short, informal, and often mix Hindi and English (e.g. "urgent Mumbai to Goa sedan kal 9 baje, 5000, contact 9876543210").

Classify "kind":
- "requirement" = someone NEEDS a car / booking / duty (words like required, need, chahiye, booking, duty, urgent).
- "available" = someone is OFFERING an empty/free car (available, khali gaadi, free car, return empty).
- "unknown" = not a booking/availability message.

Extract, using "" for anything not stated:
- pickupCity / dropCity: the from and to places (city or area names only).
- date: the travel date exactly as written ("15/07/2026", "kal", "tomorrow", "aaj").
- time: travel time if present ("09:00 PM", "9 baje").
- vehicle: the car/vehicle words as written ("sedan", "innova crysta", "ertiga").
- tripType: one of one_way, round_trip, airport, local, outstation — only if clearly stated, else "".
- driverEarning: the driver's fare/earning amount as digits only (e.g. "5000"), else "".
- commission: the commission amount as digits only, else "".
- contactNumber: the customer/contact phone number as digits only (a 10-digit Indian mobile), else "".
- notes: anything important not captured above, short.

Return ONLY the JSON object.`;

@Injectable()
export class WhatsappAiService {
  private readonly logger = new Logger(WhatsappAiService.name);
  private client: Anthropic | null = null;

  /** Whether AI parsing is configured (an API key is present). */
  get enabled(): boolean {
    return !!process.env.ANTHROPIC_API_KEY;
  }

  private get anthropic(): Anthropic | null {
    const key = process.env.ANTHROPIC_API_KEY;
    if (!key) return null;
    if (!this.client) this.client = new Anthropic({ apiKey: key });
    return this.client;
  }

  /**
   * Parse a free-form WhatsApp message into structured booking fields.
   * Returns null when AI is not configured or the call fails — callers then
   * fall back to the fixed-format parser.
   */
  async parse(text: string): Promise<ParsedWhatsappBooking | null> {
    const client = this.anthropic;
    const body = (text || '').trim();
    if (!client || !body) return null;

    const model = process.env.WHATSAPP_AI_MODEL || 'claude-opus-5';
    try {
      const res: any = await client.messages.create({
        model,
        max_tokens: 1024,
        system: SYSTEM_PROMPT,
        // Constrain the reply to our JSON shape. NOTE: no `effort` here — the
        // effort param is rejected (400) on Haiku 4.5, which broke every parse.
        output_config: { format: { type: 'json_schema', schema: SCHEMA } },
        messages: [{ role: 'user', content: body.slice(0, 4000) }],
      } as any);

      const textBlock = (res?.content || []).find((b: any) => b?.type === 'text');
      if (!textBlock?.text) return null;
      const parsed = JSON.parse(textBlock.text);
      return { ...EMPTY, ...parsed };
    } catch (e: any) {
      this.logger.warn(`WhatsApp AI parse failed (${model}): ${e?.message ?? e}`);
      return null;
    }
  }
}
