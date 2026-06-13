import { Injectable } from '@nestjs/common';
import { InjectModel } from '@nestjs/mongoose';
import { Model } from 'mongoose';
import { User, UserDocument } from '../../database/schemas/user.schema';
import { Requirement, RequirementDocument } from '../../database/schemas/requirement.schema';
import { Payment, PaymentDocument } from '../../database/schemas/payment.schema';

@Injectable()
export class AnalyticsService {
  constructor(
    @InjectModel(User.name) private userModel: Model<UserDocument>,
    @InjectModel(Requirement.name) private requirementModel: Model<RequirementDocument>,
    @InjectModel(Payment.name) private paymentModel: Model<PaymentDocument>,
  ) {}

  async getTopCities(limit = 10) {
    return this.requirementModel.aggregate([
      { $match: { isDeleted: false } },
      { $group: { _id: '$pickupCity', count: { $sum: 1 }, drops: { $addToSet: '$dropCity' } } },
      { $sort: { count: -1 } },
      { $limit: limit },
    ]);
  }

  async getMembershipConversion() {
    return this.userModel.aggregate([
      { $group: { _id: '$membershipType', count: { $sum: 1 } } },
      { $sort: { count: -1 } },
    ]);
  }

  async getRevenueByPlan() {
    return this.paymentModel.aggregate([
      { $match: { status: 'success' } },
      { $lookup: { from: 'subscriptionPlans', localField: 'planId', foreignField: '_id', as: 'plan' } },
      { $unwind: { path: '$plan', preserveNullAndEmptyArrays: true } },
      { $group: { _id: '$plan.name', revenue: { $sum: '$amount' }, count: { $sum: 1 } } },
      { $sort: { revenue: -1 } },
    ]);
  }
}
