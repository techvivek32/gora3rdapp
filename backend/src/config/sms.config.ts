import { registerAs } from '@nestjs/config';

// SMS Indori DLT credentials + gateway config. All values come from .env.
export default registerAs('sms', () => ({
  // Full send-SMS endpoint of the gateway. May contain {mobile}, {message} or
  // {otp} placeholders; if it does, they are substituted and the URL is used
  // verbatim. If left blank, the OTP is logged to the server console instead of
  // being sent (useful for local development).
  apiUrl: process.env.SMS_API_URL || '',
  authKey: process.env.SMS_AUTH_KEY || '',
  senderId: process.env.SMS_SENDER_ID || 'GORAOT',
  templateId: process.env.SMS_TEMPLATE_ID || '',
  entityId: process.env.SMS_ENTITY_ID || '',
  route: process.env.SMS_ROUTE || '',
  // TESTING ONLY: when set, this code is accepted as a valid OTP for any number.
  // Leave blank in production.
  bypassOtp: process.env.SMS_BYPASS_OTP || '',
  // {#numeric#} (or {#otp#}) is replaced with the generated code.
  messageTemplate:
    process.env.SMS_MESSAGE_TEMPLATE ||
    'Your Gora Cabs OTP is {#numeric#}. It is valid for 5 minutes. Do not share it with anyone.',
}));
