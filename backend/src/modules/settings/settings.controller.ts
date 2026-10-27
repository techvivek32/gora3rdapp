import { Controller, Get, Put, Body, UseGuards } from '@nestjs/common';
import { ApiTags, ApiOperation, ApiBearerAuth } from '@nestjs/swagger';
import { SettingsService } from './settings.service';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { RolesGuard } from '../../common/guards/roles.guard';
import { Roles } from '../../common/decorators/roles.decorator';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { UserRole } from '../../common/enums/user-role.enum';

@ApiTags('Settings')
@Controller('settings')
export class SettingsController {
  constructor(private readonly settingsService: SettingsService) {}

  @Get()
  @ApiOperation({ summary: 'Get platform settings (public — secrets stripped)' })
  getSettings() {
    return this.settingsService.getPublicSettings();
  }

  // Public: the website shows support numbers to signed-out visitors too. With
  // no user there is no city to match, so this falls back to the global numbers.
  @Get('support-contact')
  @ApiOperation({ summary: "Support numbers for the current user — their city's franchise, else global" })
  getSupportContact(@CurrentUser('sub') userId?: string) {
    return this.settingsService.resolveSupportContact(userId);
  }

  @Get('admin')
  @ApiBearerAuth('access-token')
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(UserRole.ADMIN, UserRole.SUPER_ADMIN)
  @ApiOperation({ summary: 'Get settings for admin dashboard (secrets masked, only "set" flags)' })
  getAdminSettings() {
    return this.settingsService.getAdminSettings();
  }

  @Put()
  @ApiBearerAuth('access-token')
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(UserRole.ADMIN, UserRole.SUPER_ADMIN)
  @ApiOperation({ summary: 'Update platform settings (admin only)' })
  updateSettings(@Body() body: {
    pricePerKm?: number;
    commissionPercent?: number;
    vehiclePrices?: Record<string, number>;
    razorpayKeyId?: string;
    razorpayKeySecret?: string;
    razorpayWebhookSecret?: string;
    supportPhone?: string;
    supportPhone2?: string;
    customerServicePhone?: string;
    customerServiceWhatsapp?: string;
    supportWhatsapp?: string;
    supportEmail?: string;
    minDeposit?: number;
    minWithdrawal?: number;
    minTransfer?: number;
    whatsappAutoBookMinutes?: number;
    appSuggestedFareEnabled?: boolean;
    viewsEnabled?: boolean;
    minBillKm?: number;
    localPackageKm?: { hours: number; km: number }[];
    tollTaxPerKm?: number;
    gstPercent?: number;
    platformCommissionPercent?: number;
    driverHirePerDay?: number;
    verifyClientId?: string;
    verifyClientSecret?: string;
    verifySandbox?: boolean;
    verifyEnforceNameMatch?: boolean;
    driverHireKmPerDay?: number;
    driverHireExtraKmPrice?: number;
    driverHireFoodPerDay?: number;
    driverHireReturnByCustomer?: boolean;
    minWalletToAccept?: number;
    contactRevealHoursBeforePickup?: number;
  }) {
    return this.settingsService.updateSettings(body);
  }
}
