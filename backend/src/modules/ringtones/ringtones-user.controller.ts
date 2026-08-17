import { Controller, Get, UseGuards } from '@nestjs/common';
import { ApiTags, ApiBearerAuth, ApiOperation } from '@nestjs/swagger';
import { RingtonesService } from './ringtones.service';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';

// App-facing: any logged-in user can list the ringtones to choose one for their
// popup / notification alerts. (Admin add/delete lives in RingtonesController.)
@ApiTags('Ringtones')
@ApiBearerAuth('access-token')
@UseGuards(JwtAuthGuard)
@Controller('ringtones')
export class RingtonesUserController {
  constructor(private readonly ringtonesService: RingtonesService) {}

  @Get()
  @ApiOperation({ summary: 'List ringtones the app can choose from' })
  findAll() {
    return this.ringtonesService.findAll();
  }
}
