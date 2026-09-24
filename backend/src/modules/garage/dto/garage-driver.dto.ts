import { ApiProperty, ApiPropertyOptional, PartialType } from '@nestjs/swagger';
import { IsNotEmpty, IsOptional, IsString, MaxLength } from 'class-validator';

export class CreateGarageDriverDto {
  @ApiProperty({ example: 'Suresh Kumar' })
  @IsString()
  @IsNotEmpty()
  @MaxLength(80)
  fullName: string;

  @ApiPropertyOptional({ example: '+919876543210' })
  @IsOptional()
  @IsString()
  @MaxLength(20)
  phone?: string;

  @ApiPropertyOptional({ example: 'GJ0120210001234' })
  @IsOptional()
  @IsString()
  @MaxLength(30)
  dlNumber?: string;

  @ApiPropertyOptional({ example: '1234 5678 9012' })
  @IsOptional()
  @IsString()
  @MaxLength(20)
  aadharNumber?: string;

  @ApiPropertyOptional({ example: '12 Green Park, Rajkot' })
  @IsOptional()
  @IsString()
  @MaxLength(200)
  address?: string;

  @ApiPropertyOptional({ description: 'Driver photo URL' })
  @IsOptional()
  @IsString()
  photo?: string;

  @ApiPropertyOptional({ description: 'Driving licence FRONT image URL' })
  @IsOptional()
  @IsString()
  dlFrontImage?: string;

  @ApiPropertyOptional({ description: 'Driving licence BACK image URL' })
  @IsOptional()
  @IsString()
  dlBackImage?: string;

  @ApiPropertyOptional({ description: 'Aadhaar FRONT image URL' })
  @IsOptional()
  @IsString()
  aadharFrontImage?: string;

  @ApiPropertyOptional({ description: 'Aadhaar BACK image URL' })
  @IsOptional()
  @IsString()
  aadharBackImage?: string;

  @ApiPropertyOptional({ example: 'Available on weekends' })
  @IsOptional()
  @IsString()
  @MaxLength(200)
  notes?: string;
}

export class UpdateGarageDriverDto extends PartialType(CreateGarageDriverDto) {}
