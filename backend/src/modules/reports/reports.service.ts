import { Injectable } from '@nestjs/common';
import { InjectModel } from '@nestjs/mongoose';
import { Model, Types } from 'mongoose';
import { Report, ReportDocument } from '../../database/schemas/report.schema';
import { User, UserDocument } from '../../database/schemas/user.schema';

@Injectable()
export class ReportsService {
  constructor(
    @InjectModel(Report.name) private reportModel: Model<ReportDocument>,
    @InjectModel(User.name) private userModel: Model<UserDocument>,
  ) {}

  async createReport(userId: string, data: any) {
    const report = await this.reportModel.create({
      reportedBy: new Types.ObjectId(userId),
      ...data,
    });
    return { message: 'Report submitted successfully', data: report };
  }

  async getMyReports(userId: string) {
    const reports = await this.reportModel
      .find({ reportedBy: new Types.ObjectId(userId) })
      .sort({ createdAt: -1 })
      .lean();

    // Resolve reported users (targetId is polymorphic, so fetch manually).
    const userTargetIds = reports
      .filter((r: any) => r.targetType === 'user' && r.targetId)
      .map((r: any) => r.targetId);
    if (userTargetIds.length) {
      const targets = await this.userModel
        .find({ _id: { $in: userTargetIds } })
        .select('fullName agencyName profileImage')
        .lean();
      const map = Object.fromEntries(targets.map((t: any) => [t._id.toString(), t]));
      for (const r of reports as any[]) {
        if (r.targetType === 'user') r.target = map[r.targetId?.toString()] ?? null;
      }
    }

    return { message: 'Reports retrieved', data: reports };
  }
}
