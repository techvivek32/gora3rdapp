import { Injectable, Logger, BadRequestException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';

@Injectable()
export class SmsService {
  private readonly logger = new Logger(SmsService.name);

  constructor(private readonly config: ConfigService) {}

  /// Sends the OTP via the configured SMS Indori gateway. If no gateway is
  /// configured, the OTP is logged so the flow can be tested locally.
  async sendOtp(mobile: string, otp: string): Promise<void> {
    const sms = this.config.get<any>('sms');
    const message = String(sms.messageTemplate)
      .replace('{#numeric#}', otp)
      .replace('{#otp#}', otp);

    const local10 = mobile.replace(/\D/g, '').slice(-10);

    if (!sms.apiUrl) {
      this.logger.warn(`[SMS gateway not configured] OTP for ${mobile}: ${otp}`);
      return;
    }

    const isIndori = sms.apiUrl.includes('smsindori') || sms.apiUrl.includes('tokenkeyapi');

    let url: string;
    if (sms.apiUrl.includes('{mobile}') || sms.apiUrl.includes('{message}') || sms.apiUrl.includes('{otp}')) {
      // Provider-agnostic: the env URL already has the right param names.
      url = sms.apiUrl
        .replace('{mobile}', encodeURIComponent(local10))
        .replace('{message}', encodeURIComponent(message))
        .replace('{otp}', encodeURIComponent(otp));
    } else if (isIndori) {
      // SMS Indori token-key HTTP API (http-tokenkeyapi.php).
      // Build the query with encodeURIComponent so spaces become %20, NOT '+'
      // (URLSearchParams uses '+'). This gateway forwards the message verbatim, so
      // a literal '+' in place of spaces breaks the DLT template match and the
      // operator silently drops it. It also delivers to the bare 10-digit number.
      const q = [
        `authentic-key=${encodeURIComponent(sms.authKey)}`,
        `senderid=${encodeURIComponent(sms.senderId)}`,
        `route=${encodeURIComponent(sms.route)}`,
        `number=${encodeURIComponent(local10)}`,
        `message=${encodeURIComponent(message)}`,
      ];
      if (sms.templateId) q.push(`templateid=${encodeURIComponent(sms.templateId)}`);
      // NOTE: do NOT send entityid — this gateway drops the message (operator-side)
      // when entityid is included, even though it still returns a msg-id.
      const sep = sms.apiUrl.includes('?') ? '&' : '?';
      url = `${sms.apiUrl}${sep}${q.join('&')}`;
    } else {
      // Common DLT HTTP API shape. Adjust param names to match your gateway if needed.
      const params = new URLSearchParams({
        authkey: sms.authKey,
        sender: sms.senderId,
        mobiles: `91${local10}`,
        message,
      });
      if (sms.route) params.set('route', sms.route);
      if (sms.templateId) params.set('DLT_TE_ID', sms.templateId);
      if (sms.entityId) params.set('entityid', sms.entityId);
      const sep = sms.apiUrl.includes('?') ? '&' : '?';
      url = `${sms.apiUrl}${sep}${params.toString()}`;
    }

    try {
      const res = await fetch(url, { method: 'GET' });
      const body = (await res.text()).trim();
      // SMS Indori returns "msg-id : ..." on success and a plain error string
      // (still HTTP 200) on failure, so also require a msg-id for that gateway.
      const accepted = res.ok && (!isIndori || /msg-?id/i.test(body));
      if (!accepted) {
        this.logger.error(`SMS send failed (${res.status}): ${body}`);
        throw new Error(`gateway error: ${body || res.status}`);
      }
      this.logger.log(`OTP sent to ${mobile} (gateway response: ${body.slice(0, 200)})`);
    } catch (e) {
      this.logger.error(`SMS send error: ${e.message}`);
      throw new BadRequestException('Could not send OTP. Please try again.');
    }
  }
}
