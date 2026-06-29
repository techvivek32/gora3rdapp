import { IsArray, IsEnum, IsNotEmpty, IsNumber, IsOptional, IsString, Min } from 'class-validator';
import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { VehicleType, TripType } from '../../../common/enums/vehicle-type.enum';

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

  @ApiProperty({ example: '2024-12-15' })
  @IsNotEmpty()
  travelDate: Date;

  @ApiProperty({ example: '06:00 PM' })
  @IsString()
  @IsNotEmpty()
  travelTime: string;

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

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  notes?: string;

  @ApiPropertyOptional()
  @IsOptional()
  pickupCoordinates?: { lat: number; lng: number; address?: string };

  @ApiPropertyOptional()
  @IsOptional()
  dropCoordinates?: { lat: number; lng: number; address?: string };

  // Intermediate stops between pickup and drop.
  @ApiPropertyOptional()
  @IsOptional()
  @IsArray()
  stops?: { address?: string; lat?: number; lng?: number }[];
}
