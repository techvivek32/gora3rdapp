import { Injectable, UnauthorizedException } from '@nestjs/common';
import { PassportStrategy } from '@nestjs/passport';
import { ExtractJwt, Strategy } from 'passport-jwt';
import { ConfigService } from '@nestjs/config';
import { InjectModel } from '@nestjs/mongoose';
import { Model } from 'mongoose';
import { User, UserDocument } from '../../../database/schemas/user.schema';
import { Franchise, FranchiseDocument } from '../../../database/schemas/franchise.schema';

@Injectable()
export class JwtStrategy extends PassportStrategy(Strategy, 'jwt') {
  constructor(
    private configService: ConfigService,
    @InjectModel(User.name) private userModel: Model<UserDocument>,
    @InjectModel(Franchise.name) private franchiseModel: Model<FranchiseDocument>,
  ) {
    super({
      jwtFromRequest: ExtractJwt.fromAuthHeaderAsBearerToken(),
      ignoreExpiration: false,
      secretOrKey: configService.get<string>('jwt.secret'),
    });
  }

  async validate(payload: any) {
    // Franchise tokens are a separate identity space (franchises collection),
    // so they must NOT be looked up in the users collection.
    if (payload.type === 'franchise') {
      const franchise = await this.franchiseModel.findById(payload.sub);
      if (!franchise || !franchise.isActive) {
        throw new UnauthorizedException('Franchise not found or inactive');
      }
      return {
        sub: payload.sub,
        _id: payload.sub,
        email: payload.email,
        role: 'franchise',
        type: 'franchise',
        // Scope the franchise is restricted to — every list/detail endpoint filters
        // by this. Despite the legacy name it is a SCOPE OBJECT: the franchise's
        // explicit cities (plus its legacy single `city`) and any whole states it
        // covers. A franchise with an empty scope sees NOTHING (never everything).
        franchiseCity: {
          cities: [
            ...((franchise as any).cities || []),
            ...(franchise.city ? [franchise.city] : []),
          ]
            .map((c: string) => (c || '').trim())
            .filter(Boolean),
          states: [...((franchise as any).states || [])]
            .map((s: string) => (s || '').trim())
            .filter(Boolean),
        },
        franchiseId: payload.sub,
        franchiseName: (franchise as any).name,
        // "Login As": a super-admin impersonating this franchise. Carries only
        // franchise permissions (role stays 'franchise'); these flags let /auth/me,
        // the banner, and BlockImpersonationGuard know the session is impersonated.
        ...(payload.isImpersonating
          ? {
              isImpersonating: true,
              impersonatedBy: payload.impersonatedBy,
              originalRole: payload.originalRole || 'super_admin',
            }
          : {}),
      };
    }

    const user = await this.userModel.findById(payload.sub).select('-password -refreshToken');
    if (!user || !user.isActive || user.isBlocked) {
      throw new UnauthorizedException('User not found or inactive');
    }

    // Update last active
    await this.userModel.findByIdAndUpdate(payload.sub, { lastActive: new Date() });

    return {
      sub: payload.sub,
      _id: payload.sub,
      email: payload.email,
      mobile: payload.mobile,
      role: payload.role,
      membershipType: payload.membershipType,
      isVerified: user.isVerified,
      isPremium: user.isPremium,
      isGolden: user.isGolden,
    };
  }
}
