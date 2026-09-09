import { Injectable, NotFoundException } from '@nestjs/common';
import { InjectModel } from '@nestjs/mongoose';
import { Model, Types } from 'mongoose';
import {
  CustomerComplaint,
  CustomerComplaintDocument,
} from '../../database/schemas/customer-complaint.schema';
import { CreateComplaintDto, UpdateComplaintDto } from './dto/customer-complaint.dto';

@Injectable()
export class CustomerComplaintsService {
  constructor(
    @InjectModel(CustomerComplaint.name)
    private readonly model: Model<CustomerComplaintDocument>,
  ) {}

  // ── Customer ──
  async create(customerId: string, dto: CreateComplaintDto) {
    const complaint = await this.model.create({
      customerId: new Types.ObjectId(customerId),
      category: dto.category,
      message: dto.message || '',
      bookingRef: dto.bookingRef ? new Types.ObjectId(dto.bookingRef) : undefined,
      bookingId: dto.bookingId || '',
    });
    return { message: 'Complaint submitted', data: complaint };
  }

  async myComplaints(customerId: string) {
    const data = await this.model
      .find({ customerId: new Types.ObjectId(customerId) })
      .sort({ createdAt: -1 })
      .lean();
    return { message: 'My complaints', data };
  }

  // ── Admin ──
  async listAll(status?: string) {
    const filter: any = {};
    if (status) filter.status = status;
    const data = await this.model
      .find(filter)
      .sort({ createdAt: -1 })
      .populate('customerId', 'fullName mobile city profileImage')
      .limit(500)
      .lean();
    return { message: 'Complaints', data };
  }

  async update(id: string, dto: UpdateComplaintDto) {
    const complaint = await this.model.findByIdAndUpdate(
      id,
      { $set: { ...(dto.status && { status: dto.status }), ...(dto.adminNote !== undefined && { adminNote: dto.adminNote }) } },
      { new: true },
    );
    if (!complaint) throw new NotFoundException('Complaint not found');
    return { message: 'Complaint updated', data: complaint };
  }
}
