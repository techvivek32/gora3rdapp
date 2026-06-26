import { IsEnum, IsNotEmpty, IsNumber, IsOptional, IsString, Matches } from 'class-validator';
import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { VehicleType } from '../../../common/enums/vehicle-type.enum';

export class CreateAvailableVehicleDto {
  @ApiProperty({ example: 'Jaipur' }) @IsString() @IsNotEmpty() currentCity: string;
  @ApiPropertyOptional({ example: 'Ajmer' }) @IsOptional() @IsString() destinationCity?: string;
  @ApiPropertyOptional({ example: 'Rajasthan' }) @IsOptional() @IsString() currentState?: string;
  @ApiPropertyOptional() @IsOptional() currentCoordinates?: { lat: number; lng: number; address?: string };
  @ApiPropertyOptional() @IsOptional() destinationCoordinates?: { lat: number; lng: number; address?: string };
  @ApiProperty({ enum: VehicleType }) @IsEnum(VehicleType) vehicleType: VehicleType;
  @ApiProperty({ example: 'RJ14AB1234' }) @IsString() @IsNotEmpty() vehicleNumber: string;
  @ApiProperty({ example: 'Suresh Kumar' }) @IsString() @IsNotEmpty() driverName: string;
  @ApiProperty({ example: '+919876543210' }) @IsString() @IsNotEmpty() driverMobile: string;
  @ApiProperty({ example: '2024-12-15' }) @IsNotEmpty() availableDate: Date;
  @ApiProperty({ example: '10:00 AM' }) @IsString() @IsNotEmpty() availableTime: string;
  @ApiPropertyOptional() @IsOptional() @IsString() notes?: string;
  @ApiPropertyOptional() @IsOptional() @IsString() vehicleModel?: string;
  @ApiPropertyOptional() @IsOptional() @IsString() vehicleColor?: string;
  @ApiPropertyOptional() @IsOptional() @IsNumber() estimatedDistance?: number;
  @ApiPropertyOptional() @IsOptional() @IsNumber() fare?: number;
  @ApiPropertyOptional() @IsOptional() @IsNumber() commission?: number;
  @ApiPropertyOptional() @IsOptional() @IsNumber() totalAmount?: number;
}
