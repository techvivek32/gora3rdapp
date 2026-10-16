import { Body, Controller, Post, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { VerificationService } from './verification.service';
import { InjectModel } from '@nestjs/mongoose';
import { Model } from 'mongoose';
import { User, UserDocument } from '../../database/schemas/user.schema';

@ApiTags('Verification')
@ApiBearerAuth('access-token')
@UseGuards(JwtAuthGuard)
@Controller('verification')
export class VerificationController {
  constructor(
    private readonly service: VerificationService,
    @InjectModel(User.name) private readonly userModel: Model<UserDocument>,
  ) {}

  /**
   * Vehicle RC lookup. The name to compare against is taken from the caller's own
   * account - never from the request body, or anyone could claim any match.
   */
  @Post('rc')
  @ApiOperation({ summary: 'Fetch vehicle details from the registration number' })
  async rc(@CurrentUser('sub') userId: string, @Body('registrationNumber') registrationNumber: string) {
    const me: any = await this.userModel.findById(userId).select('fullName agencyName').lean();
    const claimed = (me?.fullName || me?.agencyName || '').trim();
    const data = await this.service.lookupRc(registrationNumber, claimed);
    return { message: data.message, data };
  }

  @Post('digilocker/start')
  @ApiOperation({ summary: 'Begin DigiLocker verification (Aadhaar OTP + DL)' })
  async start(@CurrentUser('sub') userId: string, @Body('redirectUrl') redirectUrl?: string) {
    const data = await this.service.startDigilocker(userId, redirectUrl);
    return { message: data.message, data };
  }

  @Post('digilocker/fetch')
  @ApiOperation({ summary: 'Read back a completed DigiLocker verification' })
  async fetch(@Body('requestId') requestId: string) {
    const data = await this.service.fetchDigilocker(requestId);
    return { message: data.message, data };
  }
}
