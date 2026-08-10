import { IsArray, IsBoolean, IsEnum, IsNotEmpty, IsNumber, IsOptional, IsString, Min, ValidateNested } from 'class-validator';
import { Type } from 'class-transformer';
import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { VehicleType, TripType } from '../../../common/enums/vehicle-type.enum';

export class StopDto {
  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  address?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsNumber()
  lat?: number;

  @ApiPropertyOptional()
  @IsOptional()
  @IsNumber()
  lng?: number;
}

export class CreateRequirementDto {
  @ApiProperty({ example: 'Jaipur' })
  @IsString()
  @IsNotEmpty()
  pickupCity: string;

  @ApiProperty({ example: 'Ajmer' })
  @IsString()
  @IsNotEmpty()
  dropCity: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  pickupState?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  dropState?: string;

  @ApiPropertyOptional({ example: 'Ahmedabad' })
  @IsOptional()
  @IsString()
  pickupCityName?: string;

  @ApiPropertyOptional({ example: 'Ahmedabad' })
  @IsOptional()
  @IsString()
  dropCityName?: string;

  @ApiProperty({ enum: VehicleType })
  @IsEnum(VehicleType)
  vehicleType: VehicleType;

  @ApiProperty({ enum: TripType })
  @IsEnum(TripType)
  tripType: TripType;

  @ApiPropertyOptional({ example: 'any', description: 'any | diesel | petrol | cng' })
  @IsOptional()
  @IsString()
  fuelType?: string;

  @ApiProperty({ example: '2024-12-15' })
  @IsNotEmpty()
  travelDate: Date;

  @ApiProperty({ example: '06:00 PM' })
  @IsString()
  @IsNotEmpty()
  travelTime: string;

  @ApiPropertyOptional({ example: '2024-12-17' })
  @IsOptional()
  returnDate?: Date;

  @ApiPropertyOptional({ example: '06:00 PM' })
  @IsOptional()
  @IsString()
  returnTime?: string;

  @ApiPropertyOptional({ default: 1 })
  @IsOptional()
  @IsNumber()
  @Min(1)
  numberOfVehicles?: number;

  @ApiPropertyOptional()
  @IsOptional()
  @IsNumber()
  estimatedDistance?: number;

  @ApiPropertyOptional()
  @IsOptional()
  @IsNumber()
  fare?: number;

  @ApiPropertyOptional()
  @IsOptional()
  @IsNumber()
  commission?: number;

  @ApiPropertyOptional()
  @IsOptional()
  @IsNumber()
  totalAmount?: number;

  @ApiPropertyOptional({ description: 'true = app-suggested fare, false = custom fare' })
  @IsOptional()
  @IsBoolean()
  isAppSuggested?: boolean;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  notes?: string;

  // 'app' (default) or 'whatsapp'. Set by the WhatsApp intake, not by clients.
  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  source?: string;

  // Customer's contact number for a forwarded WhatsApp booking.
  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  contactMobile?: string;

  @ApiPropertyOptional()
  @IsOptional()
  pickupCoordinates?: { lat: number; lng: number; address?: string };

  @ApiPropertyOptional()
  @IsOptional()
  dropCoordinates?: { lat: number; lng: number; address?: string };

  // Intermediate stops between pickup and drop.
  @ApiPropertyOptional({ type: [StopDto] })
  @IsOptional()
  @IsArray()
  @ValidateNested({ each: true })
  @Type(() => StopDto)
  stops?: StopDto[];
}
