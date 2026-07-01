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

    let url: string;
    if (sms.apiUrl.includes('{mobile}') || sms.apiUrl.includes('{message}') || sms.apiUrl.includes('{otp}')) {
      // Provider-agnostic: the env URL already has the right param names.
      url = sms.apiUrl
        .replace('{mobile}', encodeURIComponent(local10))
        .replace('{message}', encodeURIComponent(message))
        .replace('{otp}', encodeURIComponent(otp));
    } else if (sms.apiUrl.includes('smsindori') || sms.apiUrl.includes('tokenkeyapi')) {
      // SMS Indori token-key HTTP API (http-tokenkeyapi.php).
      const params = new URLSearchParams({
        'authentic-key': sms.authKey,
        senderid: sms.senderId,
        route: sms.route,
        number: `91${local10}`,
        message,
      });
      if (sms.templateId) params.set('templateid', sms.templateId);
      if (sms.entityId) params.set('entityid', sms.entityId);
      const sep = sms.apiUrl.includes('?') ? '&' : '?';
      url = `${sms.apiUrl}${sep}${params.toString()}`;
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
      const body = await res.text();
      if (!res.ok) {
        this.logger.error(`SMS send failed (${res.status}): ${body}`);
        throw new Error(`gateway returned ${res.status}`);
      }
      this.logger.log(`OTP sent to ${mobile} (gateway response: ${body.slice(0, 200)})`);
    } catch (e) {
      this.logger.error(`SMS send error: ${e.message}`);
      throw new BadRequestException('Could not send OTP. Please try again.');
    }
  }
}
