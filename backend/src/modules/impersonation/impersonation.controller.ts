import { Controller, Param, Post, Req, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { ImpersonationService } from './impersonation.service';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { RolesGuard } from '../../common/guards/roles.guard';
import { Roles } from '../../common/decorators/roles.decorator';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { UserRole } from '../../common/enums/user-role.enum';

@ApiTags('Impersonation (Login As)')
@ApiBearerAuth('access-token')
@Controller('admin')
export class ImpersonationController {
  constructor(private readonly service: ImpersonationService) {}

  /** Super Admin ONLY — start a "Login As" session for a franchise. */
  @Post('franchises/:id/login-as')
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(UserRole.SUPER_ADMIN)
  @ApiOperation({ summary: 'Super Admin: start a Login As (impersonation) session for a franchise' })
  loginAs(@Param('id') id: string, @CurrentUser() admin: any, @Req() req: any) {
    return this.service.loginAs(admin, id, req);
  }

  /** Called with the impersonation token — ends the session, restores the admin token. */
  @Post('login-as/exit')
  @UseGuards(JwtAuthGuard)
  @ApiOperation({ summary: 'Exit the current Login As session and restore the admin token' })
  exit(@CurrentUser() user: any) {
    return this.service.exit(user);
  }
}
