import { Type } from 'class-transformer';
import { IsOptional, IsString, ValidateNested } from 'class-validator';

export class DocumentItemDto {
  @IsOptional()
  @IsString()
  number?: string;

  // Front side of the document.
  @IsOptional()
  @IsString()
  image?: string;

  // Back side of the document.
  @IsOptional()
  @IsString()
  backImage?: string;
}

export class SubmitVerificationDto {
  @IsOptional()
  @ValidateNested()
  @Type(() => DocumentItemDto)
  aadhar?: DocumentItemDto;

  @IsOptional()
  @ValidateNested()
  @Type(() => DocumentItemDto)
  pan?: DocumentItemDto;

  @IsOptional()
  @ValidateNested()
  @Type(() => DocumentItemDto)
  drivingLicense?: DocumentItemDto;

  @IsOptional()
  @ValidateNested()
  @Type(() => DocumentItemDto)
  vehicleRc?: DocumentItemDto;

  // Travel agencies may (optionally) update their agency name when submitting.
  @IsOptional()
  @IsString()
  agencyName?: string;
}
