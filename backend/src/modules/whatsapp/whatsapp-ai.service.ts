import { Injectable, Logger } from '@nestjs/common';
import OpenAI from 'openai';

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
  private client: OpenAI | null = null;

  /** Whether AI parsing is configured (an API key is present). */
  get enabled(): boolean {
    return !!process.env.OPENAI_API_KEY;
  }

  private get openai(): OpenAI | null {
    const key = process.env.OPENAI_API_KEY;
    if (!key) return null;
    if (!this.client) this.client = new OpenAI({ apiKey: key });
    return this.client;
  }

  /**
   * Parse a free-form WhatsApp message into structured booking fields.
   * Returns null when AI is not configured or the call fails — callers then
   * fall back to the fixed-format parser.
   */
  /**
   * The model this runs on, newest-first.
   *
   * There IS a fallback list because a single hard-coded model is a time bomb:
   * `gpt-4.1-nano` was deprecated by OpenAI around 25 Oct 2026 and every parse
   * 404'd for days before anyone noticed — to a customer on WhatsApp that just
   * looked like "duty is off". If the first entry dies, the next one answers
   * while someone updates the list.
   *
   * `WHATSAPP_AI_MODEL` still overrides and is tried first.
   */
  private static readonly MODELS = ['gpt-5.4-nano', 'gpt-4.1-mini', 'gpt-4o-mini'];

  /**
   * GPT-5 and newer reject `max_tokens` outright ("Unsupported parameter") and
   * want `max_completion_tokens`; the 4.x family only understands the old name.
   * Sending the wrong one fails the call entirely, so pick per model.
   */
  private tokenLimitField(model: string): 'max_tokens' | 'max_completion_tokens' {
    return /^(gpt-5|o[1-9])/i.test(model) ? 'max_completion_tokens' : 'max_tokens';
  }

  private async callModel(client: OpenAI, model: string, body: string): Promise<ParsedWhatsappBooking | null> {
    const res = await client.chat.completions.create({
      model,
      // Reasoning models spend this budget thinking before they emit anything,
      // so keep it roomy — too small and the reply comes back empty.
      [this.tokenLimitField(model)]: 1024,
      // Constrain the reply to our JSON shape via OpenAI structured outputs.
      response_format: {
        type: 'json_schema',
        json_schema: { name: 'whatsapp_booking', schema: SCHEMA, strict: true },
      },
      messages: [
        { role: 'system', content: SYSTEM_PROMPT },
        { role: 'user', content: body.slice(0, 4000) },
      ],
    } as any);

    const content = res?.choices?.[0]?.message?.content;
    // A reasoning model that burns its whole budget thinking returns an empty
    // string with no error. Treat that as a failure so the next model is tried,
    // rather than silently parsing nothing.
    if (!content || !content.trim()) return null;
    return { ...EMPTY, ...JSON.parse(content) };
  }

  async parse(text: string): Promise<ParsedWhatsappBooking | null> {
    const client = this.openai;
    const body = (text || '').trim();
    if (!client || !body) return null;

    const override = (process.env.WHATSAPP_AI_MODEL || '').trim();
    const models = override
      ? [override, ...WhatsappAiService.MODELS.filter((m) => m !== override)]
      : [...WhatsappAiService.MODELS];

    const failures: string[] = [];
    for (const model of models) {
      try {
        const parsed = await this.callModel(client, model, body);
        if (parsed) {
          // Worth knowing: the configured model is dead and a fallback is
          // carrying WhatsApp bookings. Someone should update the list/env.
          if (model !== models[0]) {
            this.logger.warn(`WhatsApp AI fell back to "${model}" — "${models[0]}" failed. Update WHATSAPP_AI_MODEL.`);
          }
          return parsed;
        }
        failures.push(`${model}: empty reply`);
      } catch (e: any) {
        failures.push(`${model}: ${e?.message ?? e}`);
      }
    }

    // Every model failed — the fixed-format parser is all that is left, so most
    // free-form messages will go unanswered. Log loudly; this is an outage.
    this.logger.error(`WhatsApp AI parse FAILED on every model — free-form messages will not be understood. ${failures.join(' | ')}`);
    return null;
  }
}
