import {
  Injectable,
  UnauthorizedException,
  ConflictException,
  BadRequestException,
  NotFoundException,
} from '@nestjs/common';
import { InjectModel } from '@nestjs/mongoose';
import { Model } from 'mongoose';
import { JwtService } from '@nestjs/jwt';
import { ConfigService } from '@nestjs/config';
import { randomInt } from 'crypto';
import * as bcrypt from 'bcryptjs';
import { User, UserDocument } from '../../database/schemas/user.schema';
import { AuditLog } from '../../database/schemas/audit-log.schema';
import { OtpVerification, OtpVerificationDocument } from '../../database/schemas/otp-verification.schema';
import { FirebaseService } from '../firebase/firebase.service';
import { SmsService } from './sms.service';
import { RegisterDto } from './dto/register.dto';
import { SendOtpDto } from './dto/send-otp.dto';
import { LoginDto } from './dto/login.dto';
import { VerifyOtpDto } from './dto/verify-otp.dto';
import { MembershipType, UserRole } from '../../common/enums/user-role.enum';

const OTP_TTL_MS = 5 * 60 * 1000; // 5 minutes
const OTP_MAX_ATTEMPTS = 5;

@Injectable()
export class AuthService {
  constructor(
    @InjectModel(User.name) private userModel: Model<UserDocument>,
    @InjectModel(AuditLog.name) private auditLogModel: Model<AuditLog>,
    @InjectModel(OtpVerification.name) private otpModel: Model<OtpVerificationDocument>,
    private jwtService: JwtService,
    private configService: ConfigService,
    private firebaseService: FirebaseService,
    private smsService: SmsService,
  ) {}

  // Step 1 of registration: validate uniqueness, then text an OTP to the mobile.
  async sendRegistrationOtp(dto: SendOtpDto) {
    await this.ensureUnique(dto.email, dto.mobile);

    const otp = randomInt(100000, 1000000).toString();
    const otpHash = await bcrypt.hash(otp, 10);
    const expiresAt = new Date(Date.now() + OTP_TTL_MS);

    await this.otpModel.findOneAndUpdate(
      { mobile: dto.mobile },
      { mobile: dto.mobile, otpHash, expiresAt, attempts: 0 },
      { upsert: true, new: true },
    );

    await this.smsService.sendOtp(dto.mobile, otp);
    return { message: 'OTP sent successfully' };
  }

  private async ensureUnique(email: string, mobile: string) {
    const existingUser = await this.userModel.findOne({
      $or: [{ email: email.toLowerCase() }, { mobile }],
    });
    if (existingUser) {
      if (existingUser.email === email.toLowerCase()) {
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

  async register(dto: RegisterDto) {
    // Account is only created after the OTP is verified.
    await this.verifyOtp(dto.mobile, dto.otp);
    await this.ensureUnique(dto.email, dto.mobile);

    const hashedPassword = await bcrypt.hash(dto.password, 12);

    const user = await this.userModel.create({
      fullName: dto.fullName,
      email: dto.email.toLowerCase(),
      mobile: dto.mobile,
      password: hashedPassword,
      agencyName: dto.agencyName,
      city: dto.city,
      state: dto.state,
      role: dto.role || UserRole.DRIVER,
      membershipType: MembershipType.NEW,
      isActive: true,
    });

    const tokens = await this.generateTokens(user);
    await this.saveRefreshToken(user._id.toString(), tokens.refreshToken);

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

    const tokens = await this.generateTokens(user);
    await this.saveRefreshToken(user._id.toString(), tokens.refreshToken);

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

    const tokens = await this.generateTokens(user);
    await this.saveRefreshToken(user._id.toString(), tokens.refreshToken);

    return {
      message: 'OTP verified successfully',
      data: {
        user: this.sanitizeUser(user),
        ...tokens,
        isNewUser: !user.fullName || user.fullName === 'New User',
      },
    };
  }

  async refreshTokens(userId: string, refreshToken: string) {
    const user = await this.userModel.findById(userId).select('+refreshToken');
    if (!user || !user.refreshToken) throw new UnauthorizedException('Access denied');

    const isTokenValid = await bcrypt.compare(refreshToken, user.refreshToken);
    if (!isTokenValid) throw new UnauthorizedException('Invalid refresh token');

    const tokens = await this.generateTokens(user);
    await this.saveRefreshToken(userId, tokens.refreshToken);

    return { message: 'Tokens refreshed', data: tokens };
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

  private async generateTokens(user: UserDocument) {
    const payload = {
      sub: user._id.toString(),
      email: user.email,
      mobile: user.mobile,
      role: user.role,
      membershipType: user.membershipType,
    };

    const [accessToken, refreshToken] = await Promise.all([
      this.jwtService.signAsync(payload, {
        secret: this.configService.get<string>('jwt.secret'),
        expiresIn: this.configService.get<string>('jwt.expiresIn', '15m'),
      }),
      this.jwtService.signAsync(payload, {
        secret: this.configService.get<string>('jwt.refreshSecret'),
        expiresIn: this.configService.get<string>('jwt.refreshExpiresIn', '30d'),
      }),
    ]);

    return { accessToken, refreshToken };
  }

  private async saveRefreshToken(userId: string, refreshToken: string) {
    const hashedToken = await bcrypt.hash(refreshToken, 10);
    await this.userModel.findByIdAndUpdate(userId, { refreshToken: hashedToken });
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
