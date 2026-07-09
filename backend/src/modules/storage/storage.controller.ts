import { Controller, Post, Body, UseGuards, UploadedFile, UseInterceptors } from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import { ApiTags, ApiOperation, ApiBearerAuth } from '@nestjs/swagger';
import { StorageService } from './storage.service';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';

@ApiTags('Storage')
@ApiBearerAuth('access-token')
@UseGuards(JwtAuthGuard)
@Controller('storage')
export class StorageController {
  constructor(private readonly storageService: StorageService) {}

  @Post('presigned-url')
  @ApiOperation({ summary: 'Get presigned URL for direct upload' })
  getPresignedUrl(@Body() data: { folder: string; contentType: string }) {
    return this.storageService.getPresignedUploadUrl(data.folder, data.contentType);
  }

  @Post('upload')
  @UseInterceptors(FileInterceptor('file'))
  @ApiOperation({ summary: 'Upload a file' })
  uploadFile(@UploadedFile() file: Express.Multer.File, @Body('folder') folder: string) {
    return this.storageService.uploadFile(file, folder || 'uploads');
  }

  @Post('upload/profile')
  @UseInterceptors(FileInterceptor('file'))
  @ApiOperation({ summary: 'Upload profile image' })
  uploadProfile(@UploadedFile() file: Express.Multer.File) {
    return this.storageService.uploadProfileImage(file);
  }

  @Post('upload/banner')
  @UseInterceptors(FileInterceptor('file'))
  @ApiOperation({ summary: 'Upload banner image (1080×528, WebP)' })
  async uploadBanner(@UploadedFile() file: Express.Multer.File) {
    const url = await this.storageService.uploadBannerImage(file);
    return { url };
  }
}
