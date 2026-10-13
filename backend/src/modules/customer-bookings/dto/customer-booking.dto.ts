import { IsEnum, IsOptional, IsString, IsNumber, IsInt, Min, ValidateNested } from 'class-validator';
import { Type } from 'class-transformer';
import { CustomerServiceType } from '../../../database/schemas/customer-booking.schema';

class GeoDto {
  @IsOptional() @IsString() address?: string;
  @IsOptional() @IsNumber() lat?: number;
  @IsOptional() @IsNumber() lng?: number;
  // The app resolves a city alongside each picked place (used for stops), so it
  // has to be allowed here — `whitelist` would otherwise reject the request.
  @IsOptional() @IsString() city?: string;
}

export class CreateCustomerBookingDto {
  @IsEnum(CustomerServiceType) serviceType: CustomerServiceType;
  @IsOptional() @IsString() subType?: string;

  @IsOptional() @ValidateNested() @Type(() => GeoDto) pickup?: GeoDto;
  @IsOptional() @ValidateNested() @Type(() => GeoDto) drop?: GeoDto;
  // Needs the element type: without @Type the global ValidationPipe's
  // `whitelist` has no metadata for the array items and strips every field,
  // so each stop arrived at the DB empty.
  @IsOptional() @ValidateNested({ each: true }) @Type(() => GeoDto) stops?: GeoDto[];

  @IsOptional() @IsString() pickupCity?: string;
  @IsOptional() @IsString() dropCity?: string;

  @IsOptional() @IsString() travelDate?: string;
  @IsOptional() @IsString() travelTime?: string;
  @IsOptional() @IsString() tripEndDate?: string;
  @IsOptional() @IsString() tripEndTime?: string;

  @IsOptional() @IsInt() @Min(1) passengers?: number;
  @IsOptional() @IsString() vehicleType?: string;
  @IsOptional() @IsNumber() durationHours?: number;
  @IsOptional() @IsString() notes?: string;
  @IsOptional() @IsNumber() estimatedFare?: number;
  @IsOptional() @IsNumber() baseFare?: number;
  @IsOptional() @IsNumber() driverAllowance?: number;
  @IsOptional() @IsNumber() gstAmount?: number;
  @IsOptional() @IsNumber() estimatedDistance?: number;
  // Round-trip GPS rental snapshot (from the chosen cab category).
  @IsOptional() @IsNumber() dailyKmLimit?: number;
  @IsOptional() @IsNumber() extraKmPrice?: number;
  @IsOptional() @IsNumber() includedKm?: number;
  // Local hourly-package snapshot (from the chosen cab category).
  @IsOptional() @IsNumber() packageHours?: number;
  @IsOptional() @IsNumber() extraHourPrice?: number;
}

/** Customer edits an OPEN booking. serviceType cannot change (that's a new booking). */
export class UpdateCustomerBookingDto {
  @IsOptional() @IsString() subType?: string;
  @IsOptional() @ValidateNested() @Type(() => GeoDto) pickup?: GeoDto;
  @IsOptional() @ValidateNested() @Type(() => GeoDto) drop?: GeoDto;
  // Needs the element type: without @Type the global ValidationPipe's
  // `whitelist` has no metadata for the array items and strips every field,
  // so each stop arrived at the DB empty.
  @IsOptional() @ValidateNested({ each: true }) @Type(() => GeoDto) stops?: GeoDto[];
  @IsOptional() @IsString() pickupCity?: string;
  @IsOptional() @IsString() dropCity?: string;
  @IsOptional() @IsString() travelDate?: string;
  @IsOptional() @IsString() travelTime?: string;
  @IsOptional() @IsString() tripEndDate?: string;
  @IsOptional() @IsString() tripEndTime?: string;
  @IsOptional() @IsInt() @Min(1) passengers?: number;
  @IsOptional() @IsString() vehicleType?: string;
  @IsOptional() @IsNumber() durationHours?: number;
  @IsOptional() @IsString() notes?: string;
  @IsOptional() @IsNumber() estimatedFare?: number;
  @IsOptional() @IsNumber() baseFare?: number;
  @IsOptional() @IsNumber() driverAllowance?: number;
  @IsOptional() @IsNumber() gstAmount?: number;
  @IsOptional() @IsNumber() estimatedDistance?: number;
  // Round-trip GPS rental snapshot (from the chosen cab category).
  @IsOptional() @IsNumber() dailyKmLimit?: number;
  @IsOptional() @IsNumber() extraKmPrice?: number;
  @IsOptional() @IsNumber() includedKm?: number;
  // Local hourly-package snapshot (from the chosen cab category).
  @IsOptional() @IsNumber() packageHours?: number;
  @IsOptional() @IsNumber() extraHourPrice?: number;
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

/** Driver accepts a customer booking, choosing a vehicle + driver from garage. */
export class AcceptBookingDto {
  @IsOptional() @IsString() vehicle?: string;
  @IsOptional() @IsString() vehicleNumber?: string;
  @IsOptional() @IsString() vehicleImage?: string;
  @IsOptional() @IsString() driverName?: string;
  @IsOptional() @IsString() driverPhone?: string;
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
