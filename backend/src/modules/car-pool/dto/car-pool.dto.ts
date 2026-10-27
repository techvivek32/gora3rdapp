import { IsArray, IsEmail, IsInt, IsNotEmpty, IsNumber, IsOptional, IsString, Matches, MaxLength, Min, ValidateNested } from 'class-validator';
import { Type } from 'class-transformer';

class GeoDto {
  @IsOptional() @IsString() address?: string;
  @IsOptional() @IsNumber() lat?: number;
  @IsOptional() @IsNumber() lng?: number;
}

export class CreatePoolRideDto {
  @IsOptional() @ValidateNested() @Type(() => GeoDto) from?: GeoDto;
  @IsOptional() @ValidateNested() @Type(() => GeoDto) to?: GeoDto;
  @IsOptional() @IsString() fromCity?: string;
  @IsOptional() @IsString() toCity?: string;
  @IsOptional() @IsString() travelDate?: string; // ISO / yyyy-MM-dd
  @IsOptional() @IsString() departureTime?: string;
  @IsInt() @Min(1) totalSeats: number;
  @IsNumber() @Min(0) pricePerSeat: number;
  @IsOptional() @IsString() vehicle?: string;
  @IsOptional() @IsString() vehicleNumber?: string;
  @IsOptional() @IsNumber() @Min(0) distanceKm?: number;
  @IsOptional() @IsString() notes?: string;
}

export class UpdatePoolRideDto {
  @IsOptional() @ValidateNested() @Type(() => GeoDto) from?: GeoDto;
  @IsOptional() @ValidateNested() @Type(() => GeoDto) to?: GeoDto;
  @IsOptional() @IsString() fromCity?: string;
  @IsOptional() @IsString() toCity?: string;
  @IsOptional() @IsString() travelDate?: string;
  @IsOptional() @IsString() departureTime?: string;
  @IsOptional() @IsInt() @Min(1) totalSeats?: number;
  @IsOptional() @IsNumber() @Min(0) pricePerSeat?: number;
  @IsOptional() @IsString() vehicle?: string;
  @IsOptional() @IsString() vehicleNumber?: string;
  @IsOptional() @IsNumber() @Min(0) distanceKm?: number;
  @IsOptional() @IsString() notes?: string;
}

export class BookSeatsDto {
  @IsInt() @Min(1) seats: number;
  @IsOptional() @IsString() pickupPoint?: string;
}

/** Booking a seat from the website without signing in: name + mobile only.
 *  The number is unverified by design — see `resolveGuestUser`. */
export class GuestBookSeatsDto extends BookSeatsDto {
  @IsString() @IsNotEmpty() @MaxLength(80) guestName: string;

  @IsString() @Matches(/^[6-9]\d{9}$/, { message: 'Enter a valid 10-digit mobile number' })
  guestMobile: string;

  @IsOptional() @IsEmail() guestEmail?: string;
}

export class PickupDto {
  @IsArray() @IsString({ each: true }) bookingIds: string[];
}

export class CompleteRideDto {
  @IsOptional() @IsNumber() @Min(0) distanceTravelled?: number;
}

export class CancelDto {
  @IsOptional() @IsString() reason?: string;
}

export class RatePoolRideDto {
  @IsNumber() @Min(0) rating: number;
  @IsOptional() @IsString() review?: string;
}
