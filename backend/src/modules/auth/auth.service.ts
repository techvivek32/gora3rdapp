import {
  Injectable,
  UnauthorizedException,
  ConflictException,
  BadRequestException,
  NotFoundException,
} from '@nestjs/common';
import { InjectModel } from '@nestjs/mongoose';
import { Model, Types } from 'mongoose';
import { JwtService } from '@nestjs/jwt';
import { ConfigService } from '@nestjs/config';
import { randomInt, randomUUID } from 'crypto';
import * as bcrypt from 'bcryptjs';
import { User, UserDocument } from '../../database/schemas/user.schema';
import { Franchise, FranchiseDocument } from '../../database/schemas/franchise.schema';
import { AuditLog } from '../../database/schemas/audit-log.schema';
import { OtpVerification, OtpVerificationDocument } from '../../database/schemas/otp-verification.schema';
import { FirebaseService } from '../firebase/firebase.service';
import { SmsService } from './sms.service';
import { RegisterDto } from './dto/register.dto';
import { SendOtpDto } from './dto/send-otp.dto';
import { LoginSendOtpDto, LoginVerifyOtpDto } from './dto/login-otp.dto';
import { LoginDto } from './dto/login.dto';
import { VerifyOtpDto } from './dto/verify-otp.dto';
import { MembershipType, UserRole } from '../../common/enums/user-role.enum';

const OTP_TTL_MS = 5 * 60 * 1000; // 5 minutes
const OTP_MAX_ATTEMPTS = 5;

@Injectable()
export class AuthService {
  constructor(
    @InjectModel(User.name) private userModel: Model<UserDocument>,
    @InjectModel(Franchise.name) private franchiseModel: Model<FranchiseDocument>,
    @InjectModel(AuditLog.name) private auditLogModel: Model<AuditLog>,
    @InjectModel(OtpVerification.name) private otpModel: Model<OtpVerificationDocument>,
    private jwtService: JwtService,
    private configService: ConfigService,
    private firebaseService: FirebaseService,
    private smsService: SmsService,
  ) {}

  private async generateAndSendOtp(mobile: string) {
    const otp = randomInt(100000, 1000000).toString();
    const otpHash = await bcrypt.hash(otp, 10);
    const expiresAt = new Date(Date.now() + OTP_TTL_MS);

    await this.otpModel.findOneAndUpdate(
      { mobile },
      { mobile, otpHash, expiresAt, attempts: 0 },
      { upsert: true, new: true },
    );

    await this.smsService.sendOtp(mobile, otp);
  }

  // Step 1 of registration: validate uniqueness, then text an OTP to the mobile.
  async sendRegistrationOtp(dto: SendOtpDto) {
    await this.ensureUnique(dto.email, dto.mobile);
    await this.generateAndSendOtp(dto.mobile);
    return { message: 'OTP sent successfully' };
  }

  // Login step 1: the number must already be registered, then text an OTP.
  async sendLoginOtp(dto: LoginSendOtpDto) {
    const user = await this.userModel.findOne({ mobile: dto.mobile });
    if (!user) throw new NotFoundException('This number is not registered');
    if (user.isBlocked) throw new UnauthorizedException('Account has been blocked');
    if (!user.isActive) throw new UnauthorizedException('Account is inactive');

    await this.generateAndSendOtp(dto.mobile);
    return { message: 'OTP sent successfully' };
  }

  // Login step 2: verify the OTP and issue tokens.
  async loginWithOtp(dto: LoginVerifyOtpDto) {
    await this.verifyOtp(dto.mobile, dto.otp);

    const user = await this.userModel.findOne({ mobile: dto.mobile });
    if (!user) throw new NotFoundException('This number is not registered');
    if (user.isBlocked) throw new UnauthorizedException('Account has been blocked');
    if (!user.isActive) throw new UnauthorizedException('Account is inactive');

    const sessionId = randomUUID();
    const tokens = await this.generateTokens(user, sessionId);
    await this.saveRefreshToken(user._id.toString(), tokens.refreshToken, sessionId);
    await this.userModel.findByIdAndUpdate(user._id, {
      lastActive: new Date(),
      ...(dto.fcmToken ? { $addToSet: { fcmTokens: dto.fcmToken } } : {}),
    });
    await this.otpModel.deleteOne({ mobile: dto.mobile });
    await this.auditLog(user._id.toString(), 'LOGIN_OTP', 'user', user._id.toString());

    return {
      message: 'Login successful',
      data: { user: this.sanitizeUser(user), ...tokens },
    };
  }

  private async ensureUnique(email: string | undefined, mobile: string) {
    // Email is optional; only include it in the uniqueness check when provided.
    const or: Record<string, any>[] = [{ mobile }];
    if (email) or.push({ email: email.toLowerCase() });

    const existingUser = await this.userModel.findOne({ $or: or });
    if (existingUser) {
      if (email && existingUser.email === email.toLowerCase()) {
        throw new ConflictException('Email already registered');
      }
      throw new ConflictException('Mobile number already registered');
    }
  }

  private async verifyOtp(mobile: string, otp: string) {
    // TESTING ONLY: a configured bypass code is accepted for any number.
    const bypass = this.configService.get<string>('sms.bypassOtp');
    if (bypass && otp === bypass) return;

    const record = await this.otpModel.findOne({ mobile });
    if (!record) throw new BadRequestException('Please request an OTP first');
    if (record.expiresAt < new Date()) {
      await this.otpModel.deleteOne({ _id: record._id });
      throw new BadRequestException('OTP has expired. Please request a new one');
    }
    if (record.attempts >= OTP_MAX_ATTEMPTS) {
      throw new BadRequestException('Too many attempts. Please request a new OTP');
    }
    const valid = await bcrypt.compare(otp, record.otpHash);
    if (!valid) {
      await this.otpModel.updateOne({ _id: record._id }, { $inc: { attempts: 1 } });
      throw new BadRequestException('Invalid OTP');
    }
  }

  // ─── Admin / super-admin forgot password (phone OTP) ────────────────────────
  // Restricted to admin & super_admin accounts only — never regular users or
  // franchises. Reuses the same OTP machinery as registration/login.
  async adminForgotPasswordSendOtp(mobile: string) {
    const m = (mobile || '').trim();
    if (!m) throw new BadRequestException('Mobile number is required');
    const user = await this.userModel
      .findOne({ mobile: m, role: { $in: ['admin', 'super_admin'] } })
      .select('_id')
      .lean();
    // Only send when it's genuinely an admin account, but never reveal whether
    // one exists (avoids account enumeration).
    if (user) await this.generateAndSendOtp(m);
    return { message: 'If an admin account is registered with this number, an OTP has been sent.' };
  }

  async adminForgotPasswordReset(mobile: string, otp: string, newPassword: string) {
    const m = (mobile || '').trim();
    if (!m || !otp || !newPassword) {
      throw new BadRequestException('Mobile, OTP and new password are required');
    }
    if (newPassword.length < 6) {
      throw new BadRequestException('New password must be at least 6 characters');
    }
    const user = await this.userModel
      .findOne({ mobile: m, role: { $in: ['admin', 'super_admin'] } })
      .select('+password');
    if (!user) throw new BadRequestException('No admin account found for this mobile number');
    await this.verifyOtp(m, otp); // throws on invalid / expired / too many attempts
    user.password = await bcrypt.hash(newPassword, 12);
    await user.save();
    await this.otpModel.deleteOne({ mobile: m });
    return { message: 'Password reset successful. You can now sign in with your new password.' };
  }

  async register(dto: RegisterDto) {
    // Account is only created after the OTP is verified.
    await this.verifyOtp(dto.mobile, dto.otp);
    await this.ensureUnique(dto.email, dto.mobile);

    // Email and password are optional (mobile users sign in with an OTP). Only set
    // them when provided so the sparse unique email index isn't hit with a null.
    const hashedPassword = dto.password ? await bcrypt.hash(dto.password, 12) : undefined;

    // Resolve the referrer (if a valid code was entered).
    const referredBy = await this.resolveReferrer(dto.referralCode);

    const user = await this.userModel.create({
      fullName: dto.fullName,
      ...(dto.email ? { email: dto.email.toLowerCase() } : {}),
      mobile: dto.mobile,
      ...(hashedPassword ? { password: hashedPassword } : {}),
      agencyName: dto.agencyName,
      city: dto.city,
      state: dto.state,
      role: dto.role || UserRole.DRIVER,
      membershipType: MembershipType.NEW,
      isActive: true,
      // The referral code IS the user's mobile number — one less thing to explain
      // to someone sharing it. `mobile` is uniquely indexed, so it's collision-free.
      referralCode: dto.mobile,
      referredBy,
    });

    // Credit the referrer's invite count.
    if (referredBy) {
      await this.userModel.findByIdAndUpdate(referredBy, { $inc: { referralCount: 1 } });
    }

    const sessionId = randomUUID();
    const tokens = await this.generateTokens(user, sessionId);
    await this.saveRefreshToken(user._id.toString(), tokens.refreshToken, sessionId);

    // OTP consumed — remove it so it can't be reused.
    await this.otpModel.deleteOne({ mobile: dto.mobile });

    await this.auditLog(user._id.toString(), 'REGISTER', 'user', user._id.toString());

    return {
      message: 'Registration successful',
      data: {
        user: this.sanitizeUser(user),
        ...tokens,
      },
    };
  }

  /**
   * Find who referred this signup. The code is now a mobile number, so match on
   * the last 10 digits — the sharer may type "9876543210" while the account is
   * stored as "+919876543210". Falls back to the old GORAxxxxxx codes so invites
   * shared before this change still work.
   */
  private async resolveReferrer(code?: string): Promise<Types.ObjectId | null> {
    const entered = (code || '').trim();
    if (!entered) return null;

    const digits = entered.replace(/\D/g, '');
    if (digits.length >= 10) {
      const byMobile = await this.userModel
        .findOne({ mobile: new RegExp(`${digits.slice(-10)}$`) })
        .select('_id');
      if (byMobile) return byMobile._id;
    }

    const legacy = await this.userModel
      .findOne({ referralCode: entered.toUpperCase() })
      .select('_id');
    return legacy?._id ?? null;
  }

  async login(dto: LoginDto) {
    const user = await this.userModel
      .findOne({ $or: [{ email: dto.identifier.toLowerCase() }, { mobile: dto.identifier }] })
      .select('+password +refreshToken');

    if (!user) throw new UnauthorizedException('Invalid credentials');
    if (user.isBlocked) throw new UnauthorizedException('Account has been blocked');
    if (!user.isActive) throw new UnauthorizedException('Account is inactive');

    if (user.lockUntil && user.lockUntil > new Date()) {
      throw new UnauthorizedException('Account temporarily locked. Try again later');
    }

    const isPasswordValid = await bcrypt.compare(dto.password, user.password);
    if (!isPasswordValid) {
      await this.handleFailedLogin(user);
      throw new UnauthorizedException('Invalid credentials');
    }

    // Reset login attempts on success
    await this.userModel.findByIdAndUpdate(user._id, {
      loginAttempts: 0,
      lockUntil: null,
      lastActive: new Date(),
    });

    const sessionId = randomUUID();
    const tokens = await this.generateTokens(user, sessionId);
    await this.saveRefreshToken(user._id.toString(), tokens.refreshToken, sessionId);

    // Update FCM token if provided
    if (dto.fcmToken) {
      await this.userModel.findByIdAndUpdate(user._id, {
        $addToSet: { fcmTokens: dto.fcmToken },
        deviceInfo: dto.deviceInfo,
      });
    }

    await this.auditLog(user._id.toString(), 'LOGIN', 'user', user._id.toString());

    return {
      message: 'Login successful',
      data: {
        user: this.sanitizeUser(user),
        ...tokens,
      },
    };
  }

  async verifyFirebaseOtp(dto: VerifyOtpDto) {
    const decodedToken = await this.firebaseService.verifyIdToken(dto.firebaseIdToken);
    if (!decodedToken) throw new BadRequestException('Invalid Firebase token');

    const mobile = decodedToken.phone_number;
    let user = await this.userModel.findOne({ mobile });

    if (!user) {
      user = await this.userModel.create({
        mobile,
        fullName: dto.fullName || 'New User',
        email: dto.email || `${mobile.replace('+', '')}@goracabs.com`,
        firebaseUid: decodedToken.uid,
        membershipType: MembershipType.NEW,
        isActive: true,
        role: UserRole.DRIVER,
      });
    } else {
      await this.userModel.findByIdAndUpdate(user._id, {
        firebaseUid: decodedToken.uid,
        lastActive: new Date(),
      });
    }

    const sessionId = randomUUID();
    const tokens = await this.generateTokens(user, sessionId);
    await this.saveRefreshToken(user._id.toString(), tokens.refreshToken, sessionId);

    return {
      message: 'OTP verified successfully',
      data: {
        user: this.sanitizeUser(user),
        ...tokens,
        isNewUser: !user.fullName || user.fullName === 'New User',
      },
    };
  }

  // ---------------------------------------------------------------------------
  // Franchise authentication (separate identity space from app users / admins).
  // A franchise logs into the SAME admin login form; NextAuth tries the normal
  // /auth/login first, then falls back to this endpoint. Tokens carry
  // `type: 'franchise'` + `role: 'franchise'` so JwtStrategy scopes them.
  // ---------------------------------------------------------------------------
  async franchiseLogin(dto: LoginDto) {
    const email = (dto.identifier || '').toLowerCase().trim();
    const franchise = await this.franchiseModel
      .findOne({ email })
      .select('+password');

    if (!franchise || !franchise.password) {
      throw new UnauthorizedException('Invalid credentials');
    }
    if (!franchise.isActive) {
      throw new UnauthorizedException('Franchise account is inactive');
    }

    const ok = await bcrypt.compare(dto.password, franchise.password);
    if (!ok) throw new UnauthorizedException('Invalid credentials');

    const tokens = await this.generateFranchiseTokens(franchise);
    await this.saveFranchiseRefreshToken(franchise._id.toString(), tokens.refreshToken);

    return {
      message: 'Franchise login successful',
      data: {
        franchise: {
          id: franchise._id.toString(),
          name: franchise.name,
          email: franchise.email,
          city: franchise.city || null,
          state: franchise.state || null,
          agencyName: franchise.agencyName || null,
          role: 'franchise',
        },
        ...tokens,
      },
    };
  }

  // The logged-in franchise's own profile (password/refreshToken excluded by select:false).
  async franchiseProfile(franchiseId: string) {
    const franchise = await this.franchiseModel.findById(franchiseId).lean();
    if (!franchise) throw new NotFoundException('Franchise not found');
    return { data: franchise };
  }

  private async generateFranchiseTokens(franchise: FranchiseDocument) {
    const payload = {
      sub: franchise._id.toString(),
      email: franchise.email,
      role: 'franchise',
      type: 'franchise',
      city: franchise.city || null,
    };

    const [accessToken, refreshToken] = await Promise.all([
      this.jwtService.signAsync(payload, {
        secret: this.configService.get<string>('jwt.secret'),
        expiresIn: this.configService.get<string>('jwt.expiresIn', '1h'),
      }),
      this.jwtService.signAsync(payload, {
        secret: this.configService.get<string>('jwt.refreshSecret'),
        expiresIn: this.configService.get<string>('jwt.refreshExpiresIn', '30d'),
      }),
    ]);

    return { accessToken, refreshToken };
  }

  private async saveFranchiseRefreshToken(franchiseId: string, refreshToken: string) {
    const hashedToken = await bcrypt.hash(refreshToken, 10);
    await this.franchiseModel.findByIdAndUpdate(franchiseId, { refreshToken: hashedToken });
  }

  // Refresh a franchise's access token. Mirrors refreshTokens() (no rotation).
  private async refreshFranchiseTokens(franchise: FranchiseDocument, refreshToken: string) {
    const accessToken = await this.jwtService.signAsync(
      {
        sub: franchise._id.toString(),
        email: franchise.email,
        role: 'franchise',
        type: 'franchise',
        city: franchise.city || null,
      },
      {
        secret: this.configService.get<string>('jwt.secret'),
        expiresIn: this.configService.get<string>('jwt.expiresIn', '1h'),
      },
    );
    return { message: 'Tokens refreshed', data: { accessToken, refreshToken } };
  }

  async refreshTokens(userId: string, refreshToken: string) {
    // A refresh may belong to either a normal user/admin OR a franchise; both
    // share the /auth/refresh endpoint. Try the franchise space first only when
    // the user space has no such id, to avoid an extra query on the hot path.
    const user = await this.userModel.findById(userId).select('+refreshToken');
    if (!user) {
      const franchise = await this.franchiseModel.findById(userId).select('+refreshToken');
      if (franchise && franchise.refreshToken) {
        const valid = await bcrypt.compare(refreshToken, franchise.refreshToken);
        if (!valid) throw new UnauthorizedException('Invalid refresh token');
        return this.refreshFranchiseTokens(franchise, refreshToken);
      }
      throw new UnauthorizedException('Access denied');
    }
    if (!user.refreshToken) throw new UnauthorizedException('Access denied');

    // Single-device: a newer login on another phone rotated user.sessionId, so a
    // refresh carrying the old session belongs to a replaced device — reject with
    // a clear marker so the app can show "logged in on another device". Admins /
    // super-admins are exempt (they legitimately use several devices/browsers).
    const isAdmin = user.role === UserRole.ADMIN || user.role === UserRole.SUPER_ADMIN;
    const decodedRefresh: any = this.jwtService.decode(refreshToken);
    if (!isAdmin && decodedRefresh?.sessionId && user.sessionId && decodedRefresh.sessionId !== user.sessionId) {
      throw new UnauthorizedException('SESSION_REPLACED');
    }

    const isTokenValid = await bcrypt.compare(refreshToken, user.refreshToken);
    if (!isTokenValid) throw new UnauthorizedException('Invalid refresh token');

    // A blocked / deactivated account must not be able to renew its session.
    // Without this the app refreshes forever (access token 401s, refresh succeeds,
    // repeat) and the user is never actually logged out. Throwing here makes the
    // client's refresh call fail with 401 → it signs the user out immediately.
    if (user.isBlocked) throw new UnauthorizedException('Account has been blocked');
    if (!user.isActive) throw new UnauthorizedException('Account is inactive');

    // Issue only a fresh access token and KEEP the same refresh token (no rotation).
    // Rotating here caused logouts: on a page reload NextAuth fires the refresh from
    // both the server (getServerSession) and the client at once with the same token —
    // rotation invalidates one of them, and server-side rotations can't be persisted
    // back into the cookie. A stable refresh token (still valid its full 30d) avoids
    // that race entirely, so the admin stays logged in across refreshes / tab reopens.
    const accessToken = await this.jwtService.signAsync(
      {
        sub: user._id.toString(),
        email: user.email,
        mobile: user.mobile,
        role: user.role,
        membershipType: user.membershipType,
        ...(user.sessionId ? { sessionId: user.sessionId } : {}),
      },
      {
        secret: this.configService.get<string>('jwt.secret'),
        expiresIn: this.configService.get<string>('jwt.expiresIn', '1h'),
      },
    );

    return { message: 'Tokens refreshed', data: { accessToken, refreshToken } };
  }

  async logout(userId: string, fcmToken?: string) {
    const update: any = { refreshToken: null };
    if (fcmToken) {
      await this.userModel.findByIdAndUpdate(userId, { $pull: { fcmTokens: fcmToken } });
    } else {
      await this.userModel.findByIdAndUpdate(userId, { $set: update });
    }
    await this.auditLog(userId, 'LOGOUT', 'user', userId);
    return { message: 'Logged out successfully' };
  }

  private async generateTokens(user: UserDocument, sessionId?: string) {
    const payload = {
      sub: user._id.toString(),
      email: user.email,
      mobile: user.mobile,
      role: user.role,
      membershipType: user.membershipType,
      // Single-device: this login's session. Rotated on every new login.
      ...(sessionId ? { sessionId } : {}),
    };

    const [accessToken, refreshToken] = await Promise.all([
      this.jwtService.signAsync(payload, {
        secret: this.configService.get<string>('jwt.secret'),
        expiresIn: this.configService.get<string>('jwt.expiresIn', '1h'),
      }),
      this.jwtService.signAsync(payload, {
        secret: this.configService.get<string>('jwt.refreshSecret'),
        expiresIn: this.configService.get<string>('jwt.refreshExpiresIn', '30d'),
      }),
    ]);

    return { accessToken, refreshToken };
  }

  private async saveRefreshToken(userId: string, refreshToken: string, sessionId?: string) {
    const hashedToken = await bcrypt.hash(refreshToken, 10);
    await this.userModel.findByIdAndUpdate(userId, {
      refreshToken: hashedToken,
      ...(sessionId ? { sessionId } : {}),
    });
  }

  private async handleFailedLogin(user: UserDocument) {
    const attempts = (user.loginAttempts || 0) + 1;
    const update: any = { loginAttempts: attempts };
    if (attempts >= 5) {
      update.lockUntil = new Date(Date.now() + 15 * 60 * 1000); // 15 min lock
    }
    await this.userModel.findByIdAndUpdate(user._id, update);
  }

  private sanitizeUser(user: UserDocument) {
    const { password, refreshToken, fcmTokens, ...safeUser } = user.toObject();
    return safeUser;
  }

  private async auditLog(userId: string, action: string, resource: string, resourceId: string) {
    await this.auditLogModel.create({ userId, action, resource, resourceId });
  }
}
