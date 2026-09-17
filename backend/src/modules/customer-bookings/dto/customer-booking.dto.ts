import { IsEnum, IsOptional, IsString, IsNumber, IsInt, Min, ValidateNested } from 'class-validator';
import { Type } from 'class-transformer';
import { CustomerServiceType } from '../../../database/schemas/customer-booking.schema';

class GeoDto {
  @IsOptional() @IsString() address?: string;
  @IsOptional() @IsNumber() lat?: number;
  @IsOptional() @IsNumber() lng?: number;
}

export class CreateCustomerBookingDto {
  @IsEnum(CustomerServiceType) serviceType: CustomerServiceType;
  @IsOptional() @IsString() subType?: string;

  @IsOptional() @ValidateNested() @Type(() => GeoDto) pickup?: GeoDto;
  @IsOptional() @ValidateNested() @Type(() => GeoDto) drop?: GeoDto;
  @IsOptional() stops?: GeoDto[];

  @IsOptional() @IsString() pickupCity?: string;
  @IsOptional() @IsString() dropCity?: string;

  @IsOptional() @IsString() travelDate?: string;
  @IsOptional() @IsString() travelTime?: string;

  @IsOptional() @IsInt() @Min(1) passengers?: number;
  @IsOptional() @IsString() vehicleType?: string;
  @IsOptional() @IsNumber() durationHours?: number;
  @IsOptional() @IsString() notes?: string;
  @IsOptional() @IsNumber() estimatedFare?: number;
  @IsOptional() @IsNumber() estimatedDistance?: number;
}

/** Customer edits an OPEN booking. serviceType cannot change (that's a new booking). */
export class UpdateCustomerBookingDto {
  @IsOptional() @IsString() subType?: string;
  @IsOptional() @ValidateNested() @Type(() => GeoDto) pickup?: GeoDto;
  @IsOptional() @ValidateNested() @Type(() => GeoDto) drop?: GeoDto;
  @IsOptional() stops?: GeoDto[];
  @IsOptional() @IsString() pickupCity?: string;
  @IsOptional() @IsString() dropCity?: string;
  @IsOptional() @IsString() travelDate?: string;
  @IsOptional() @IsString() travelTime?: string;
  @IsOptional() @IsInt() @Min(1) passengers?: number;
  @IsOptional() @IsString() vehicleType?: string;
  @IsOptional() @IsNumber() durationHours?: number;
  @IsOptional() @IsString() notes?: string;
  @IsOptional() @IsNumber() estimatedFare?: number;
  @IsOptional() @IsNumber() estimatedDistance?: number;
}

export class ApplyBookingDto {
  @IsOptional() @IsNumber() quotedFare?: number;
  @IsOptional() @IsString() vehicle?: string;
  @IsOptional() @IsString() vehicleNumber?: string;
  @IsOptional() @IsString() vehicleImage?: string;
  @IsOptional() @IsString() message?: string;
  // Car Pooling
  @IsOptional() @IsNumber() farePerSeat?: number;
  @IsOptional() @IsInt() seatsAvailable?: number;
}

export class SelectOfferDto {
  @IsString() offerId: string;
}

export class CancelBookingDto {
  @IsOptional() @IsString() reason?: string;
}

export class RateBookingDto {
  @IsNumber() @Min(0) rating: number;
  @IsOptional() @IsString() review?: string;
}
