import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { S3Client, PutObjectCommand, DeleteObjectCommand } from '@aws-sdk/client-s3';
import { getSignedUrl } from '@aws-sdk/s3-request-presigner';
import { v4 as uuidv4 } from 'uuid';
import sharp from 'sharp';

@Injectable()
export class StorageService {
  private readonly logger = new Logger(StorageService.name);
  private s3Client: S3Client;
  private bucketName: string;
  private publicUrl: string;

  constructor(private configService: ConfigService) {
    this.bucketName = configService.get<string>('storage.bucketName');
    this.publicUrl = configService.get<string>('storage.publicUrl');

    this.s3Client = new S3Client({
      region: 'auto',
      endpoint: configService.get<string>('storage.endpoint'),
      credentials: {
        accessKeyId: configService.get<string>('storage.accessKeyId'),
        secretAccessKey: configService.get<string>('storage.secretAccessKey'),
      },
    });
  }

  async uploadFile(
    file: Express.Multer.File,
    folder: string = 'uploads',
    options?: { resize?: { width: number; height: number }; quality?: number },
  ): Promise<string> {
    let buffer = file.buffer;

    // Process image if it's an image file
    if (file.mimetype.startsWith('image/') && options?.resize) {
      buffer = await sharp(buffer)
        .resize(options.resize.width, options.resize.height, { fit: 'cover' })
        .webp({ quality: options.quality || 85 })
        .toBuffer();
    }

    const ext = file.mimetype.startsWith('image/') && options?.resize ? 'webp' : file.originalname.split('.').pop();
    const key = `${folder}/${uuidv4()}.${ext}`;

    await this.s3Client.send(
      new PutObjectCommand({
        Bucket: this.bucketName,
        Key: key,
        Body: buffer,
        ContentType: file.mimetype.startsWith('image/') && options?.resize ? 'image/webp' : file.mimetype,
        CacheControl: 'public, max-age=31536000',
      }),
    );

    return `${this.publicUrl}/${key}`;
  }

  async uploadProfileImage(file: Express.Multer.File): Promise<string> {
    return this.uploadFile(file, 'profiles', { resize: { width: 400, height: 400 }, quality: 85 });
  }

  async uploadBannerImage(file: Express.Multer.File): Promise<string> {
    return this.uploadFile(file, 'banners', { resize: { width: 1200, height: 400 }, quality: 90 });
  }

  async deleteFile(url: string): Promise<void> {
    const key = url.replace(`${this.publicUrl}/`, '');
    await this.s3Client.send(
      new DeleteObjectCommand({ Bucket: this.bucketName, Key: key }),
    );
  }

  async getPresignedUploadUrl(folder: string, contentType: string): Promise<{ url: string; key: string; publicUrl: string }> {
    const ext = contentType.split('/')[1];
    const key = `${folder}/${uuidv4()}.${ext}`;

    const command = new PutObjectCommand({
      Bucket: this.bucketName,
      Key: key,
      ContentType: contentType,
    });

    const url = await getSignedUrl(this.s3Client, command, { expiresIn: 3600 });

    return { url, key, publicUrl: `${this.publicUrl}/${key}` };
  }
}
