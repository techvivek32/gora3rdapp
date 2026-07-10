import { IsIn, IsNotEmpty, IsNumber, IsOptional, IsString, Matches, MaxLength, Min, ValidateIf } from 'class-validator';
import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';

export class CreateTopUpDto {
  @ApiProperty({ example: 500 })
  @IsNumber()
  @Min(1)
  amount: number;
}

/** Wallet-to-wallet transfer to another user, found by their mobile number. */
export class TransferFundsDto {
  @ApiProperty({ example: '9876543210', description: "Recipient's mobile number" })
  @IsString()
  @IsNotEmpty()
  mobile: string;

  @ApiProperty({ example: 500 })
  @IsNumber()
  @Min(1)
  amount: number;

  @ApiPropertyOptional({ example: 'For the Jaipur trip' })
  @IsOptional()
  @IsString()
  @MaxLength(120)
  note?: string;
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

export class RequestWithdrawalDto {
  @ApiProperty({ example: 500 })
  @IsNumber()
  @Min(1)
  amount: number;

  @ApiPropertyOptional({ enum: ['bank', 'upi'], default: 'bank' })
  @IsOptional()
  @IsIn(['bank', 'upi'])
  method?: 'bank' | 'upi';

  @ApiProperty({ example: 'Ramesh Kumar' })
  @IsString()
  @IsNotEmpty()
  @MaxLength(80)
  accountHolderName: string;

  // ── Bank payout (required when method is 'bank') ───────────────────────────
  @ApiPropertyOptional({ example: 'State Bank of India' })
  @ValidateIf((o) => (o.method ?? 'bank') === 'bank')
  @IsString()
  @IsNotEmpty()
  @MaxLength(80)
  bankName?: string;

  @ApiPropertyOptional({ example: '123456789012' })
  @ValidateIf((o) => (o.method ?? 'bank') === 'bank')
  @IsString()
  @IsNotEmpty()
  @MaxLength(30)
  accountNumber?: string;

  @ApiPropertyOptional({ example: 'SBIN0001234' })
  @ValidateIf((o) => (o.method ?? 'bank') === 'bank')
  @IsString()
  @IsNotEmpty()
  @MaxLength(20)
  ifsc?: string;

  // ── UPI payout (required when method is 'upi') ─────────────────────────────
  @ApiPropertyOptional({ example: 'ramesh@okaxis' })
  @ValidateIf((o) => o.method === 'upi')
  @IsString()
  @IsNotEmpty()
  @Matches(/^[\w.\-]{2,}@[a-zA-Z]{2,}$/, { message: 'Enter a valid UPI ID (e.g. name@bank)' })
  @MaxLength(60)
  upiId?: string;
}

export class RejectWithdrawalDto {
  @ApiProperty({ example: 'Invalid bank details' })
  @IsString()
  @IsNotEmpty()
  @MaxLength(200)
  reason: string;
}

export class AdjustWalletDto {
  @ApiProperty({ example: 500, description: 'Amount to add or cut (always positive)' })
  @IsNumber()
  @Min(1)
  amount: number;

  @ApiProperty({ enum: ['credit', 'debit'], description: "'credit' adds money, 'debit' cuts money" })
  @IsString()
  @IsIn(['credit', 'debit'])
  type: 'credit' | 'debit';

  @ApiProperty({ example: 'Refund for cancelled ride', description: 'Reason shown to the user' })
  @IsString()
  @IsNotEmpty()
  @MaxLength(200)
  reason: string;
}
