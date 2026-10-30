import { ExecutionContext, Injectable, Logger } from '@nestjs/common';
import { ThrottlerGuard } from '@nestjs/throttler';
// Not re-exported from the package index in v5 — import it from where it lives.
import { ThrottlerLimitDetail } from '@nestjs/throttler/dist/throttler.guard.interface';

/**
 * Rate-limits by ACCOUNT rather than by IP.
 *
 * Two reasons, and the second is the one that matters:
 *
 *   1. Most of our users are on mobile carriers, which put thousands of phones
 *      behind a handful of NAT addresses. An IP-keyed limit either has to be set
 *      so high it stops nothing, or it punishes a whole carrier for one device.
 *
 *   2. A lead scraper simply changes IP. It cannot change the account, because
 *      the feed is behind JwtAuthGuard and a request only succeeds with a real
 *      token. Keying on the account is therefore the only limit that costs an
 *      abuser something — a fresh bucket means a fresh registration.
 *
 * The token is DECODED here, not verified. That is deliberate and safe for this
 * use: the signature is checked moments later by JwtAuthGuard, so a forged `sub`
 * buys an attacker a different counter on a request that is about to 401 anyway.
 * Verifying twice on the hot path would cost us for nothing. Anything without a
 * readable token falls back to the IP, which is the right key for login and the
 * other public routes.
 *
 * (Global guards run before controller-level ones, so `req.user` is not
 * populated yet when this executes — hence reading the header directly.)
 */
@Injectable()
export class AccountThrottlerGuard extends ThrottlerGuard {
  private readonly logger = new Logger('Throttle');

  protected async getTracker(req: Record<string, any>): Promise<string> {
    const sub = AccountThrottlerGuard.subjectFromAuthHeader(req?.headers?.authorization);
    return sub ? `u:${sub}` : `ip:${req?.ip ?? 'unknown'}`;
  }

  /**
   * A tripped limit is the clearest bot signal we get, so make sure it lands in
   * the log with the account on it. Identifying the last scraper meant sampling
   * `lastActive` against nginx timestamps for an hour; this turns that into a
   * line we can grep.
   */
  protected async throwThrottlingException(
    context: ExecutionContext,
    detail: ThrottlerLimitDetail,
  ): Promise<void> {
    const req = context.switchToHttp().getRequest();
    this.logger.warn(
      `RATE LIMIT ${await this.getTracker(req)} ${req?.method} ${req?.originalUrl ?? req?.url} ` +
        `(${detail.limit}/${detail.ttl}ms) ip=${req?.ip} ua="${req?.headers?.['user-agent'] ?? ''}"`,
    );
    return super.throwThrottlingException(context, detail);
  }

  /** The `sub` claim, or null if there is no readable bearer token. */
  private static subjectFromAuthHeader(header?: string): string | null {
    if (typeof header !== 'string' || !header.startsWith('Bearer ')) return null;
    const payload = header.slice(7).split('.')[1];
    if (!payload) return null;
    try {
      const json = JSON.parse(Buffer.from(payload, 'base64url').toString('utf8'));
      const sub = json?.sub;
      return typeof sub === 'string' && sub.length > 0 ? sub : null;
    } catch {
      return null; // malformed token — let the IP bucket handle it
    }
  }
}
