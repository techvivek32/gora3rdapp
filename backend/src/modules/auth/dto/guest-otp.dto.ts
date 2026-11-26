import { ApiProperty } from '@nestjs/swagger';
import { IsString, Matches, Length } from 'class-validator';

/**
 * A website visitor verifying the number they are about to book with.
 *
 * Unlike login and registration this says nothing about whether an account
 * exists — the number is checked, not the person.
 */
export class GuestSendOtpDto {
  @ApiProperty({ example: '9876543210', description: '10-digit Indian mobile number' })
  @IsString()
  @Matches(/^[6-9]\d{9}$/, { message: 'Enter a valid 10-digit mobile number' })
  mobile: string;
}

export class GuestVerifyOtpDto {
  @ApiProperty({ example: '9876543210' })
  @IsString()
  @Matches(/^[6-9]\d{9}$/, { message: 'Enter a valid 10-digit mobile number' })
  mobile: string;

  @ApiProperty({ example: '123456', description: 'The 6-digit code that was texted' })
  @IsString()
  @Length(4, 8, { message: 'Enter the code from the SMS' })
  otp: string;
}
