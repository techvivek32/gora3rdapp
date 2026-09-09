import { Module } from '@nestjs/common';
import { MongooseModule } from '@nestjs/mongoose';
import {
  CustomerComplaint,
  CustomerComplaintSchema,
} from '../../database/schemas/customer-complaint.schema';
import { CustomerComplaintsService } from './customer-complaints.service';
import { CustomerComplaintsController } from './customer-complaints.controller';

@Module({
  imports: [
    MongooseModule.forFeature([
      { name: CustomerComplaint.name, schema: CustomerComplaintSchema },
    ]),
  ],
  controllers: [CustomerComplaintsController],
  providers: [CustomerComplaintsService],
})
export class CustomerComplaintsModule {}
