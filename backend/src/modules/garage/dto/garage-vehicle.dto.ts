import { ApiProperty, ApiPropertyOptional, PartialType } from '@nestjs/swagger';
import { IsInt, IsNotEmpty, IsOptional, IsString, Max, MaxLength, Min } from 'class-validator';

export class CreateGarageVehicleDto {
  @ApiProperty({ example: 'crysta' })
  @IsString()
  @IsNotEmpty()
  vehicleType: string;

  @ApiPropertyOptional({ example: 'Toyota Innova Crysta 2022' })
  @IsOptional()
  @IsString()
  @MaxLength(80)
  modelName?: string;

  @ApiPropertyOptional({ example: 'GJ01AB1234' })
  @IsOptional()
  @IsString()
  @MaxLength(20)
  registrationNumber?: string;

  @ApiPropertyOptional({ example: 'diesel' })
  @IsOptional()
  @IsString()
  fuelType?: string;

  @ApiPropertyOptional({ example: 7 })
  @IsOptional()
  @IsInt()
  @Min(1)
  @Max(60)
  seatingCapacity?: number;

  @ApiPropertyOptional({ example: 'White' })
  @IsOptional()
  @IsString()
  @MaxLength(30)
  color?: string;

  @ApiPropertyOptional({ example: 'Carrier fitted' })
  @IsOptional()
  @IsString()
  @MaxLength(200)
  notes?: string;
}

export class UpdateGarageVehicleDto extends PartialType(CreateGarageVehicleDto) {}
