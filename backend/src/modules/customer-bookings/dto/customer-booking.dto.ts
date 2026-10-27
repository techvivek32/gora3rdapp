import { IsEmail, IsEnum, IsNotEmpty, IsOptional, IsString, IsNumber, IsInt, Matches, MaxLength, Min, ValidateNested } from 'class-validator';
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
  // Revealed only to the selected driver — see CustomerBooking.contactName.
  @IsOptional() @IsString() @MaxLength(80) contactName?: string;
  @IsOptional() @IsString() @MaxLength(20) contactMobile?: string;
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

/**
 * A booking placed from the website WITHOUT signing in — the customer gives only
 * a name and a mobile number.
 *
 * The number is NOT verified (no OTP), which is a deliberate product choice, so
 * everything downstream treats it as a claim rather than proof: the endpoint
 * issues no tokens and returns no account data, and the booking is simply filed
 * against whoever owns that number.
 */
export class CreateGuestBookingDto extends CreateCustomerBookingDto {
  @IsString() @IsNotEmpty() @MaxLength(80) guestName: string;

  @IsString() @Matches(/^[6-9]\d{9}$/, { message: 'Enter a valid 10-digit mobile number' })
  guestMobile: string;

  @IsOptional() @IsEmail() guestEmail?: string;
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
  // Revealed only to the selected driver — see CustomerBooking.contactName.
  @IsOptional() @IsString() @MaxLength(80) contactName?: string;
  @IsOptional() @IsString() @MaxLength(20) contactMobile?: string;
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
