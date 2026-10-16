import { Body, Controller, Post, UploadedFile, UseGuards, UseInterceptors } from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
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

  /**
   * Driving licence lookup. Unlike the RC there is no owner-name gate here: the
   * driver is a different person from the account holder by design, so the name
   * is something we fill in, not something we check against.
   */
  /**
   * Read an uploaded ID photo. The name it is checked against is the one already
   * on the form (from the licence), never a name sent up with the request.
   */
  @Post('ocr')
  @UseInterceptors(FileInterceptor('file'))
  @ApiOperation({ summary: 'Read name/number/address off an uploaded ID photo' })
  async ocr(
    @UploadedFile() file: Express.Multer.File,
    @Body('documentType') documentType: string,
    @Body('compareName') compareName?: string,
  ) {
    const data = await this.service.ocrDocument(file, documentType, compareName);
    return { message: data.message, data };
  }

  @Post('dl')
  @ApiOperation({ summary: 'Fetch licence details from the DL number and date of birth' })
  async dl(@Body('dlNumber') dlNumber: string, @Body('dob') dob: string) {
    const data = await this.service.lookupDl(dlNumber, dob);
    return { message: data.message, data };
  }
}
