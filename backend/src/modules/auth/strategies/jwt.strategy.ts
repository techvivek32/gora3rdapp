import { Injectable, UnauthorizedException } from '@nestjs/common';
import { PassportStrategy } from '@nestjs/passport';
import { ExtractJwt, Strategy } from 'passport-jwt';
import { ConfigService } from '@nestjs/config';
import { InjectModel } from '@nestjs/mongoose';
import { Model } from 'mongoose';
import { User, UserDocument } from '../../../database/schemas/user.schema';

@Injectable()
export class JwtStrategy extends PassportStrategy(Strategy, 'jwt') {
  constructor(
    private configService: ConfigService,
    @InjectModel(User.name) private userModel: Model<UserDocument>,
  ) {
    super({
      jwtFromRequest: ExtractJwt.fromAuthHeaderAsBearerToken(),
      ignoreExpiration: false,
      secretOrKey: configService.get<string>('jwt.secret'),
    });
  }

  async validate(payload: any) {
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
