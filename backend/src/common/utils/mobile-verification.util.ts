import { BadRequestException } from '@nestjs/common';
import * as crypto from 'crypto';

/**
 * Proof that a phone number answered an OTP, in a form the next request can
 * carry.
 *
 * The website has no session: a visitor books as a guest, so there is nothing
 * to hang "this number is verified" off between the OTP step and the booking
 * being placed. A signed token is that link. It says only "this number passed
 * an OTP at this time" — it is not a login and grants nothing else.
 *
 * Signed rather than stored because it needs no lookup and cannot be guessed:
 * changing the number invalidates the signature, and the expiry is inside the
 * signed part so it cannot be stretched.
 */

/** Long enough to finish a booking, short enough to be useless afterwards. */
const TTL_MS = 30 * 60 * 1000;

function secret(): string {
  return process.env.JWT_SECRET || process.env.ENCRYPTION_KEY || 'gora-mobile-verify';
}

/** The last ten digits, so +91/0 prefixes cannot produce a different token. */
function normalise(mobile: string): string {
  return `${mobile ?? ''}`.replace(/\D/g, '').slice(-10);
}

export function signMobileVerification(mobile: string, ttlMs: number = TTL_MS): string {
  const payload = `${normalise(mobile)}.${Date.now() + ttlMs}`;
  const sig = crypto.createHmac('sha256', secret()).update(payload).digest('hex');
  return Buffer.from(`${payload}.${sig}`).toString('base64url');
}

/**
 * Throws unless `token` proves `mobile` passed an OTP and has not expired.
 *
 * Every failure says the same thing: the caller does not need to know whether
 * the token was malformed, forged, for a different number or simply old — only
 * that they have to verify the number again.
 */
export function assertMobileVerified(mobile: string, token?: string): void {
  const fail = () =>
    new BadRequestException('Please verify your mobile number with the OTP before booking');
  if (!token) throw fail();

  let decoded = '';
  try {
    decoded = Buffer.from(token, 'base64url').toString('utf8');
  } catch {
    throw fail();
  }

  const parts = decoded.split('.');
  if (parts.length !== 3) throw fail();
  const [num, expStr, sig] = parts;

  const expected = crypto.createHmac('sha256', secret()).update(`${num}.${expStr}`).digest('hex');
  let ok = false;
  try {
    ok = crypto.timingSafeEqual(Buffer.from(expected), Buffer.from(sig));
  } catch {
    throw fail(); // different lengths — not one of ours
  }
  if (!ok) throw fail();

  if (num !== normalise(mobile)) throw fail(); // verified a different number
  if (!(Number(expStr) > Date.now())) throw fail();
}
