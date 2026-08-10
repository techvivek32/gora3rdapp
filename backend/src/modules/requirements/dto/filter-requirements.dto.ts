import { IsEnum, IsOptional, IsString } from 'class-validator';
import { ApiPropertyOptional } from '@nestjs/swagger';
import { VehicleType, TripType } from '../../../common/enums/vehicle-type.enum';
import { MembershipType } from '../../../common/enums/user-role.enum';

export class FilterRequirementsDto {
  @ApiPropertyOptional() @IsOptional() @IsString() pickupCity?: string;
  @ApiPropertyOptional() @IsOptional() @IsString() dropCity?: string;
  @ApiPropertyOptional({ enum: VehicleType }) @IsOptional() @IsEnum(VehicleType) vehicleType?: VehicleType;
  @ApiPropertyOptional({ enum: TripType }) @IsOptional() @IsEnum(TripType) tripType?: TripType;
  @ApiPropertyOptional() @IsOptional() @IsString() bookingId?: string;
  // 'app' → in-app bookings (Booking tab); 'whatsapp' → WhatsApp-sourced (WhatsApp tab).
  @ApiPropertyOptional() @IsOptional() @IsString() source?: string;
  @ApiPropertyOptional() @IsOptional() @IsString() dateFrom?: string;
  @ApiPropertyOptional() @IsOptional() @IsString() dateTo?: string;
  @ApiPropertyOptional({ enum: MembershipType }) @IsOptional() @IsEnum(MembershipType) membershipType?: MembershipType;
  @ApiPropertyOptional() @IsOptional() page?: number;
  @ApiPropertyOptional() @IsOptional() limit?: number;
  @ApiPropertyOptional() @IsOptional() @IsString() sortBy?: string;
  @ApiPropertyOptional() @IsOptional() sortOrder?: 'asc' | 'desc';
}
