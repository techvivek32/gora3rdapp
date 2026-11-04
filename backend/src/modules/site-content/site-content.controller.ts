import { Body, Controller, Delete, Get, Param, Put, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { SiteContentService } from './site-content.service';
import { Public, Roles } from '../../common/decorators/roles.decorator';
import { UserRole } from '../../common/enums/user-role.enum';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { RolesGuard } from '../../common/guards/roles.guard';

@ApiTags('Site Content')
@Controller('site-content')
export class SiteContentController {
  constructor(private readonly service: SiteContentService) {}

  // The website reads this before anyone identifies themselves, so it is
  // @Public like the rest of the home payload. It is admin-authored copy —
  // there is nothing private in it.
  @Get()
  @Public()
  @ApiOperation({ summary: 'Website copy an operator can edit' })
  getPublic() {
    return this.service.getPublic();
  }

  @Get('admin')
  @ApiBearerAuth('access-token')
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(UserRole.ADMIN, UserRole.SUPER_ADMIN)
  @ApiOperation({ summary: 'The editable fields, with their labels and values' })
  getForAdmin() {
    return this.service.getForAdmin();
  }

  @Put('admin')
  @ApiBearerAuth('access-token')
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(UserRole.ADMIN, UserRole.SUPER_ADMIN)
  @ApiOperation({ summary: 'Save the website copy' })
  update(@Body() body: { items: { key: string; value: string }[] }) {
    return this.service.update(body?.items);
  }

  @Delete('admin/:key')
  @ApiBearerAuth('access-token')
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(UserRole.ADMIN, UserRole.SUPER_ADMIN)
  @ApiOperation({ summary: 'Drop one override and go back to the shipped copy' })
  reset(@Param('key') key: string) {
    return this.service.reset(key);
  }
}
