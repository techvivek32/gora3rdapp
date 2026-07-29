import {
  BadRequestException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { InjectModel } from '@nestjs/mongoose';
import { Model, Types } from 'mongoose';
import { JwtService } from '@nestjs/jwt';
import { ConfigService } from '@nestjs/config';
import { User, UserDocument } from '../../database/schemas/user.schema';
import { Franchise, FranchiseDocument } from '../../database/schemas/franchise.schema';
import {
  ImpersonationLog,
  ImpersonationLogDocument,
} from '../../database/schemas/impersonation-log.schema';

/** Minimal user-agent → {browser, os} parser (no extra dependency). */
function parseUserAgent(ua = ''): { browser: string; os: string } {
  const browser =
    /Edg\//.test(ua) ? 'Edge'
      : /OPR\/|Opera/.test(ua) ? 'Opera'
        : /Chrome\//.test(ua) ? 'Chrome'
          : /Firefox\//.test(ua) ? 'Firefox'
            : /Safari\//.test(ua) ? 'Safari'
              : ua ? 'Unknown' : '';
  const os =
    /Windows NT 10/.test(ua) ? 'Windows 10/11'
      : /Windows/.test(ua) ? 'Windows'
        : /Android/.test(ua) ? 'Android'
          : /iPhone|iPad|iOS/.test(ua) ? 'iOS'
            : /Mac OS X/.test(ua) ? 'macOS'
              : /Linux/.test(ua) ? 'Linux'
                : ua ? 'Unknown' : '';
  return { browser, os };
}

function clientIp(req: any): string {
  const xff = (req?.headers?.['x-forwarded-for'] as string) || '';
  return (xff.split(',')[0] || req?.ip || req?.socket?.remoteAddress || '').trim();
}

@Injectable()
export class ImpersonationService {
  constructor(
    @InjectModel(User.name) private userModel: Model<UserDocument>,
    @InjectModel(Franchise.name) private franchiseModel: Model<FranchiseDocument>,
    @InjectModel(ImpersonationLog.name) private logModel: Model<ImpersonationLogDocument>,
    private readonly jwtService: JwtService,
    private readonly configService: ConfigService,
  ) {}

  /** Super-admin → franchise: mint an impersonation JWT + open an audit row. */
  async loginAs(admin: any, franchiseId: string, req: any) {
    if (!Types.ObjectId.isValid(franchiseId)) {
      throw new NotFoundException('Franchise not found');
    }
    const franchise = await this.franchiseModel.findById(franchiseId).lean();
    if (!franchise) throw new NotFoundException('Franchise not found'); // deleted → hard-removed
    if ((franchise as any).isActive === false) {
      throw new ForbiddenException('This franchise account is disabled');
    }

    const superAdminId = (admin?.sub || admin?._id)?.toString();
    // The JWT user has no name — fetch it for the audit trail.
    const adminDoc = await this.userModel.findById(superAdminId).select('fullName email').lean();

    const accessToken = await this.jwtService.signAsync(
      {
        sub: franchiseId,
        email: (franchise as any).email,
        role: 'franchise',
        type: 'franchise',
        isImpersonating: true,
        impersonatedBy: superAdminId,
        originalRole: admin?.role || 'super_admin',
      },
      {
        secret: this.configService.get<string>('jwt.secret'),
        expiresIn: this.configService.get<string>('jwt.expiresIn', '1h'),
      },
    );

    const { browser, os } = parseUserAgent(req?.headers?.['user-agent']);
    // Safety: close any stale open sessions for this pair before opening a new one.
    await this.logModel.updateMany(
      { adminId: new Types.ObjectId(superAdminId), franchiseId: new Types.ObjectId(franchiseId), active: true },
      { $set: { active: false, endTime: new Date() } },
    );
    await this.logModel.create({
      adminId: new Types.ObjectId(superAdminId),
      adminName: (adminDoc as any)?.fullName || (adminDoc as any)?.email || 'Super Admin',
      franchiseId: new Types.ObjectId(franchiseId),
      franchiseName: (franchise as any).name || '',
      ipAddress: clientIp(req),
      browser,
      os,
      userAgent: (req?.headers?.['user-agent'] as string) || '',
      startTime: new Date(),
      active: true,
    });

    return {
      message: 'Impersonation started',
      data: {
        accessToken,
        franchise: {
          id: franchiseId,
          name: (franchise as any).name,
          email: (franchise as any).email ?? null,
          city: (franchise as any).city ?? null,
          state: (franchise as any).state ?? null,
          cities: (franchise as any).cities ?? [],
          states: (franchise as any).states ?? [],
          agencyName: (franchise as any).agencyName ?? null,
          role: 'franchise',
        },
      },
    };
  }

  /** Exit impersonation: re-issue the original admin's token + close the audit row. */
  async exit(impUser: any) {
    if (!impUser?.isImpersonating || !impUser?.impersonatedBy) {
      throw new BadRequestException('Not in a Login As session');
    }
    const superAdminId = impUser.impersonatedBy.toString();
    if (!Types.ObjectId.isValid(superAdminId)) {
      throw new ForbiddenException('Original admin not found');
    }
    const admin = await this.userModel.findById(superAdminId);
    if (!admin || !admin.isActive || !['admin', 'super_admin'].includes(admin.role)) {
      throw new ForbiddenException('Original admin session can no longer be restored');
    }

    const accessToken = await this.jwtService.signAsync(
      {
        sub: admin._id.toString(),
        email: admin.email,
        mobile: admin.mobile,
        role: admin.role,
        membershipType: admin.membershipType,
      },
      {
        secret: this.configService.get<string>('jwt.secret'),
        expiresIn: this.configService.get<string>('jwt.expiresIn', '1h'),
      },
    );

    // Close the open audit row for this admin + franchise.
    const now = new Date();
    const open = await this.logModel
      .findOne({
        adminId: admin._id,
        franchiseId: new Types.ObjectId((impUser.sub || impUser._id).toString()),
        active: true,
      })
      .sort({ startTime: -1 });
    if (open) {
      open.endTime = now;
      open.durationSeconds = Math.max(0, Math.round((now.getTime() - new Date(open.startTime).getTime()) / 1000));
      open.active = false;
      await open.save();
    }

    return {
      message: 'Impersonation ended',
      data: {
        accessToken,
        user: {
          id: admin._id.toString(),
          name: admin.fullName,
          email: admin.email,
          role: admin.role,
        },
      },
    };
  }
}
