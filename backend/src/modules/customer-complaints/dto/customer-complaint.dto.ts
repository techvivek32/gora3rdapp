import { IsEnum, IsOptional, IsString } from 'class-validator';
import { ComplaintCategory, ComplaintStatus } from '../../../database/schemas/customer-complaint.schema';

export class CreateComplaintDto {
  @IsEnum(ComplaintCategory) category: ComplaintCategory;
  @IsOptional() @IsString() message?: string;
  @IsOptional() @IsString() bookingRef?: string;
  @IsOptional() @IsString() bookingId?: string;
}

export class UpdateComplaintDto {
  @IsOptional() @IsEnum(ComplaintStatus) status?: ComplaintStatus;
  @IsOptional() @IsString() adminNote?: string;
}
