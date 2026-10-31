import { Injectable, ExecutionContext, UnauthorizedException } from '@nestjs/common';
import { AuthGuard } from '@nestjs/passport';
import { Reflector } from '@nestjs/core';
import { IS_PUBLIC_KEY } from '../decorators/roles.decorator';

/** Marks a request as being on a @Public() route, so handleRequest never rejects. */
const OPTIONAL_AUTH = Symbol('optionalAuth');

@Injectable()
export class JwtAuthGuard extends AuthGuard('jwt') {
  constructor(private reflector: Reflector) {
    super();
  }

  /**
   * `@Public()` means "a token is not REQUIRED here" — it never meant "ignore the
   * token that was sent".
   *
   * Returning true early skipped passport entirely, so `req.user` stayed empty
   * even for a perfectly valid Authorization header, and every
   * `@CurrentUser('sub')` on a public route received `undefined`. That is not a
   * cosmetic gap: on the car-pool feed it meant `driverId: { $ne: userId }` never
   * excluded anything, so drivers saw their OWN ride in the passenger search; and
   * on ride details `isOwner` and `myBooking` were false and null for everybody,
   * so the driver — and anyone who had already booked — was shown a live "Book
   * Seats" button that the (authenticated) POST then correctly rejected with 400.
   *
   * So on a public route we still run the strategy to identify the caller, and
   * simply decline to reject one who is anonymous or carrying a stale token.
   */
  async canActivate(context: ExecutionContext): Promise<boolean> {
    const isPublic = this.reflector.getAllAndOverride<boolean>(IS_PUBLIC_KEY, [
      context.getHandler(),
      context.getClass(),
    ]);

    if (!isPublic) return (await super.canActivate(context)) as boolean;

    context.switchToHttp().getRequest()[OPTIONAL_AUTH] = true;
    try {
      await super.canActivate(context);
    } catch {
      // No token, or one the strategy refused (expired, blocked account). A
      // public route must still answer — just anonymously.
    }
    return true;
  }

  handleRequest(err: any, user: any, info: any, context?: ExecutionContext) {
    const req = context?.switchToHttp?.().getRequest?.();
    if (req?.[OPTIONAL_AUTH]) return user || undefined; // public: never throw
    if (err || !user) {
      throw err || new UnauthorizedException('Invalid or expired token');
    }
    return user;
  }
}
