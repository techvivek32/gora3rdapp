import { IsArray, IsBoolean, IsEnum, IsInt, IsNumber, IsOptional, IsString, Max, Min, ValidateNested } from 'class-validator';
import { Type } from 'class-transformer';
import { HomeSectionType } from '../../../database/schemas/home-content.schema';

export class StatePriceDto {
  @IsString() state: string;
  @IsOptional() @IsNumber() petrol?: number;
  @IsOptional() @IsNumber() diesel?: number;
  @IsOptional() @IsNumber() cng?: number;
}

export class CreateShowcaseDto {
  @IsEnum(HomeSectionType) section: HomeSectionType;
  @IsOptional() @IsString() title?: string;
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

export class CreateCabCategoryDto {
  @IsString() name: string;
  @IsOptional() @IsString() vehicleClass?: string;
  @IsOptional() @IsString() imageUrl?: string;
  @IsNumber() pricePerKm: number;
  @IsOptional() @IsNumber() pricePerKmPetrol?: number;
  @IsOptional() @IsNumber() pricePerKmDiesel?: number;
  @IsOptional() @IsNumber() pricePerKmCng?: number;
  @IsOptional() @IsArray() @ValidateNested({ each: true }) @Type(() => StatePriceDto) statePricing?: StatePriceDto[];
  @IsOptional() @IsNumber() @Min(0) @Max(100) discountPercent?: number;
  @IsOptional() @IsNumber() allowanceDailyRate?: number;
  @IsOptional() @IsNumber() allowanceDistanceThreshold?: number;
  @IsOptional() @IsNumber() allowanceBaseRate?: number;
  @IsOptional() @IsNumber() allowanceMaxRate?: number;
  @IsOptional() @IsNumber() dailyKmLimit?: number;
  @IsOptional() @IsNumber() extraKmPrice?: number;
  @IsOptional() @IsNumber() packageKmPerHour?: number;
  @IsOptional() @IsNumber() extraHourPrice?: number;
  @IsOptional() @IsInt() seats?: number;
  @IsOptional() @IsString() bags?: string;
  @IsOptional() @IsArray() @IsString({ each: true }) inclusions?: string[];
  @IsOptional() @IsArray() @IsString({ each: true }) exclusions?: string[];
  @IsOptional() @IsArray() @IsString({ each: true }) facilities?: string[];
  @IsOptional() @IsArray() @IsString({ each: true }) terms?: string[];
  @IsOptional() @IsInt() order?: number;
  @IsOptional() @IsBoolean() isActive?: boolean;
}

export class UpdateCabCategoryDto {
  @IsOptional() @IsString() name?: string;
  @IsOptional() @IsString() vehicleClass?: string;
  @IsOptional() @IsString() imageUrl?: string;
  @IsOptional() @IsNumber() pricePerKm?: number;
  @IsOptional() @IsNumber() pricePerKmPetrol?: number;
  @IsOptional() @IsNumber() pricePerKmDiesel?: number;
  @IsOptional() @IsNumber() pricePerKmCng?: number;
  @IsOptional() @IsArray() @ValidateNested({ each: true }) @Type(() => StatePriceDto) statePricing?: StatePriceDto[];
  @IsOptional() @IsNumber() @Min(0) @Max(100) discountPercent?: number;
  @IsOptional() @IsNumber() allowanceDailyRate?: number;
  @IsOptional() @IsNumber() allowanceDistanceThreshold?: number;
  @IsOptional() @IsNumber() allowanceBaseRate?: number;
  @IsOptional() @IsNumber() allowanceMaxRate?: number;
  @IsOptional() @IsNumber() dailyKmLimit?: number;
  @IsOptional() @IsNumber() extraKmPrice?: number;
  @IsOptional() @IsNumber() packageKmPerHour?: number;
  @IsOptional() @IsNumber() extraHourPrice?: number;
  @IsOptional() @IsInt() seats?: number;
  @IsOptional() @IsString() bags?: string;
  @IsOptional() @IsArray() @IsString({ each: true }) inclusions?: string[];
  @IsOptional() @IsArray() @IsString({ each: true }) exclusions?: string[];
  @IsOptional() @IsArray() @IsString({ each: true }) facilities?: string[];
  @IsOptional() @IsArray() @IsString({ each: true }) terms?: string[];
  @IsOptional() @IsInt() order?: number;
  @IsOptional() @IsBoolean() isActive?: boolean;
}
