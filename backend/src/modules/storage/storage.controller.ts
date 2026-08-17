import { Controller, Post, Body, Req, UseGuards, UploadedFile, UseInterceptors } from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import { ApiTags, ApiOperation, ApiBearerAuth } from '@nestjs/swagger';
import { Request } from 'express';
import { StorageService } from './storage.service';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';

@ApiTags('Storage')
@ApiBearerAuth('access-token')
@UseGuards(JwtAuthGuard)
@Controller('storage')
export class StorageController {
  constructor(private readonly storageService: StorageService) {}

  /**
   * Public origin the caller reached us on (e.g. https://backend.goracabs.com),
   * from the proxy headers. Used to build reachable local-storage URLs instead
   * of the server's private LAN IP.
   */
  private baseUrl(req: Request): string | undefined {
    const proto = ((req.headers['x-forwarded-proto'] as string) || req.protocol || 'https').split(',')[0].trim();
    const host = (req.headers['x-forwarded-host'] as string) || req.get('host');
    return host ? `${proto}://${host}` : undefined;
  }

  @Post('presigned-url')
  @ApiOperation({ summary: 'Get presigned URL for direct upload' })
  getPresignedUrl(@Body() data: { folder: string; contentType: string }) {
    return this.storageService.getPresignedUploadUrl(data.folder, data.contentType);
  }

  @Post('upload')
  @UseInterceptors(FileInterceptor('file'))
  @ApiOperation({ summary: 'Upload a file' })
  uploadFile(@UploadedFile() file: Express.Multer.File, @Body('folder') folder: string, @Req() req: Request) {
    return this.storageService.uploadFile(file, folder || 'uploads', { baseUrl: this.baseUrl(req) });
  }

  @Post('upload/profile')
  @UseInterceptors(FileInterceptor('file'))
  @ApiOperation({ summary: 'Upload profile image' })
  uploadProfile(@UploadedFile() file: Express.Multer.File, @Req() req: Request) {
    return this.storageService.uploadProfileImage(file, this.baseUrl(req));
  }

  @Post('upload/banner')
  @UseInterceptors(FileInterceptor('file'))
  @ApiOperation({ summary: 'Upload banner image (1080×528, WebP)' })
  async uploadBanner(@UploadedFile() file: Express.Multer.File, @Req() req: Request) {
    const url = await this.storageService.uploadBannerImage(file, this.baseUrl(req));
    return { url };
  }

  @Post('upload/notification')
  @UseInterceptors(FileInterceptor('file'))
  @ApiOperation({ summary: 'Upload notification image (1024×512, WebP)' })
  async uploadNotification(@UploadedFile() file: Express.Multer.File, @Req() req: Request) {
    const url = await this.storageService.uploadNotificationImage(file, this.baseUrl(req));
    return { url };
  }

  @Post('upload/ringtone')
  @UseInterceptors(FileInterceptor('file'))
  @ApiOperation({ summary: 'Upload a ringtone audio file' })
  async uploadRingtone(@UploadedFile() file: Express.Multer.File, @Req() req: Request) {
    const url = await this.storageService.uploadRingtone(file, this.baseUrl(req));
    return { url };
  }
}
