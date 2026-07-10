import { IsNotEmpty, IsString, MaxLength, MinLength } from 'class-validator';
import { ApiProperty } from '@nestjs/swagger';

export class RequestAccountDeletionDto {
  @ApiProperty({ example: 'I no longer use the app', description: 'Why the user wants the account removed' })
  @IsString()
  @IsNotEmpty()
  @MinLength(3, { message: 'Please tell us why you want to delete your account' })
  @MaxLength(500)
  reason: string;
}
