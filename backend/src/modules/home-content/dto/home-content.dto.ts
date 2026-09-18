import { IsBoolean, IsEnum, IsInt, IsOptional, IsString } from 'class-validator';
import { HomeSectionType } from '../../../database/schemas/home-content.schema';

export class CreateShowcaseDto {
  @IsEnum(HomeSectionType) section: HomeSectionType;
  @IsString() title: string;
  @IsOptional() @IsString() subtitle?: string;
  @IsOptional() @IsString() imageUrl?: string;
  @IsOptional() @IsString() actionUrl?: string;
  @IsOptional() @IsString() category?: string;
  @IsOptional() @IsString() city?: string;
  @IsOptional() @IsInt() order?: number;
  @IsOptional() @IsBoolean() isActive?: boolean;
}

export class UpdateShowcaseDto {
  @IsOptional() @IsEnum(HomeSectionType) section?: HomeSectionType;
  @IsOptional() @IsString() title?: string;
  @IsOptional() @IsString() subtitle?: string;
  @IsOptional() @IsString() imageUrl?: string;
  @IsOptional() @IsString() actionUrl?: string;
  @IsOptional() @IsString() category?: string;
  @IsOptional() @IsString() city?: string;
  @IsOptional() @IsInt() order?: number;
  @IsOptional() @IsBoolean() isActive?: boolean;
}

export class UpsertCityImageDto {
  @IsString() city: string;
  @IsOptional() @IsString() imageUrl?: string;
  @IsOptional() @IsBoolean() isActive?: boolean;
}
