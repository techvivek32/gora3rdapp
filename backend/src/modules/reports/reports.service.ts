import { Injectable } from '@nestjs/common';
import { InjectModel } from '@nestjs/mongoose';
import { Model, Types } from 'mongoose';
import { Report, ReportDocument } from '../../database/schemas/report.schema';

@Injectable()
export class ReportsService {
  constructor(@InjectModel(Report.name) private reportModel: Model<ReportDocument>) {}

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
    return { message: 'Reports retrieved', data: reports };
  }
}
