import { Body, Controller, Delete, Get, Param, Post, Put, Query, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { Roles } from '../../common/decorators/roles.decorator';
import { UserRole } from '../../common/enums/user-role.enum';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { RolesGuard } from '../../common/guards/roles.guard';
import { HomeContentService } from './home-content.service';
import {
  CreateCabCategoryDto,
  CreateShowcaseDto,
  UpdateCabCategoryDto,
  UpdateShowcaseDto,
  UpsertCityImageDto,
} from './dto/home-content.dto';

@ApiTags('Home Content')
@ApiBearerAuth('access-token')
@UseGuards(JwtAuthGuard)
@Controller('home-content')
export class HomeContentController {
  constructor(private readonly service: HomeContentService) {}

  // Customer: the whole home payload for their city.
  @Get()
  @ApiOperation({ summary: 'Customer: dynamic home content for a city' })
  getForCustomer(@Query('city') city?: string) {
    return this.service.getForCustomer(city);
  }

  // Customer: active cab categories for the Explore Cabs results.
  @Get('cab-categories')
  @ApiOperation({ summary: 'Customer: active cab categories (name, image, price/km, seats)' })
  cabCategories() {
    return this.service.listCabCategories(true);
  }

  // Customer: the "All Inclusive" list shown on the cab-results screen.
  @Get('inclusions')
  @ApiOperation({ summary: 'Customer: admin-managed "all inclusive" items' })
  inclusions() {
    return this.service.listInclusions();
  }

  // ── Admin: cab categories ──
  @Get('admin/cab-categories')
  @UseGuards(RolesGuard)
  @Roles(UserRole.ADMIN, UserRole.SUPER_ADMIN)
  adminCabCategories() {
    return this.service.listCabCategories(false);
  }

  @Post('admin/cab-categories')
  @UseGuards(RolesGuard)
  @Roles(UserRole.ADMIN, UserRole.SUPER_ADMIN)
  createCabCategory(@Body() dto: CreateCabCategoryDto) {
    return this.service.createCabCategory(dto);
  }

  @Put('admin/cab-categories/:id')
  @UseGuards(RolesGuard)
  @Roles(UserRole.ADMIN, UserRole.SUPER_ADMIN)
  updateCabCategory(@Param('id') id: string, @Body() dto: UpdateCabCategoryDto) {
    return this.service.updateCabCategory(id, dto);
  }

  @Delete('admin/cab-categories/:id')
  @UseGuards(RolesGuard)
  @Roles(UserRole.ADMIN, UserRole.SUPER_ADMIN)
  deleteCabCategory(@Param('id') id: string) {
    return this.service.deleteCabCategory(id);
  }

  // ── Admin: showcase ──
  @Get('admin/sections')
  @UseGuards(RolesGuard)
  @Roles(UserRole.ADMIN, UserRole.SUPER_ADMIN)
  listShowcase(@Query('section') section?: string) {
    return this.service.listShowcase(section);
  }

  @Post('admin/sections')
  @UseGuards(RolesGuard)
  @Roles(UserRole.ADMIN, UserRole.SUPER_ADMIN)
  createShowcase(@Body() dto: CreateShowcaseDto) {
    return this.service.createShowcase(dto);
  }

  @Put('admin/sections/:id')
  @UseGuards(RolesGuard)
  @Roles(UserRole.ADMIN, UserRole.SUPER_ADMIN)
  updateShowcase(@Param('id') id: string, @Body() dto: UpdateShowcaseDto) {
    return this.service.updateShowcase(id, dto);
  }

  @Delete('admin/sections/:id')
  @UseGuards(RolesGuard)
  @Roles(UserRole.ADMIN, UserRole.SUPER_ADMIN)
  deleteShowcase(@Param('id') id: string) {
    return this.service.deleteShowcase(id);
  }

  // ── Admin: city hero images ──
  @Get('admin/city-images')
  @UseGuards(RolesGuard)
  @Roles(UserRole.ADMIN, UserRole.SUPER_ADMIN)
  listCityImages() {
    return this.service.listCityImages();
  }

  @Post('admin/city-images')
  @UseGuards(RolesGuard)
  @Roles(UserRole.ADMIN, UserRole.SUPER_ADMIN)
  upsertCityImage(@Body() dto: UpsertCityImageDto) {
    return this.service.upsertCityImage(dto);
  }

  @Delete('admin/city-images/:id')
  @UseGuards(RolesGuard)
  @Roles(UserRole.ADMIN, UserRole.SUPER_ADMIN)
  deleteCityImage(@Param('id') id: string) {
    return this.service.deleteCityImage(id);
  }
}
