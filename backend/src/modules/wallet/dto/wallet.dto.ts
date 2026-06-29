import { IsNotEmpty, IsNumber, IsString, Min } from 'class-validator';
import { ApiProperty } from '@nestjs/swagger';

export class CreateTopUpDto {
  @ApiProperty({ example: 500 })
  @IsNumber()
  @Min(1)
  amount: number;
}

export class VerifyTopUpDto {
  @ApiProperty()
  @IsString()
  @IsNotEmpty()
  razorpayOrderId: string;

  @ApiProperty()
  @IsString()
  @IsNotEmpty()
  razorpayPaymentId: string;

  @ApiProperty()
  @IsString()
  @IsNotEmpty()
  razorpaySignature: string;
}
