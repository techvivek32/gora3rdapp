import { CanActivate, ExecutionContext, ForbiddenException, Injectable } from '@nestjs/common';

/**
 * Blocks sensitive self-service actions (password/email change, delete account,
 * subscription, security settings) while the caller is inside a "Login As" session.
 * A super-admin impersonating a franchise gets FRANCHISE permissions only — they
 * must never mutate account-security state as the impersonated user. Apply AFTER
 * JwtAuthGuard so `req.user` is populated.
 */
@Injectable()
export class BlockImpersonationGuard implements CanActivate {
  canActivate(context: ExecutionContext): boolean {
    const req = context.switchToHttp().getRequest();
    if (req.user?.isImpersonating) {
      throw new ForbiddenException('This action is disabled while using Login As.');
    }
    return true;
  }
}
