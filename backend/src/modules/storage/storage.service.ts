import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { S3Client, PutObjectCommand, DeleteObjectCommand } from '@aws-sdk/client-s3';
import { getSignedUrl } from '@aws-sdk/s3-request-presigner';
import { v4 as uuidv4 } from 'uuid';
import sharp from 'sharp';
import * as fs from 'fs';
import * as path from 'path';
import * as os from 'os';

@Injectable()
export class StorageService {
  private readonly logger = new Logger(StorageService.name);
  private s3Client: S3Client | null = null;
  private bucketName: string;
  private publicUrl: string;
  private readonly useLocal: boolean;
  private readonly uploadsDir: string;

  constructor(private configService: ConfigService) {
    this.bucketName = configService.get<string>('storage.bucketName');
    this.publicUrl = configService.get<string>('storage.publicUrl');

    const accountId = configService.get<string>('storage.accountId');
    const accessKeyId = configService.get<string>('storage.accessKeyId');
    const secretAccessKey = configService.get<string>('storage.secretAccessKey');

    // Use local disk when R2 credentials are placeholder / missing
    const credsMissing =
      !accountId ||
      accountId.startsWith('your-') ||
      !accessKeyId ||
      accessKeyId.startsWith('your-') ||
      !secretAccessKey ||
      secretAccessKey.startsWith('your-');

    this.useLocal = credsMissing;

    if (this.useLocal) {
      this.uploadsDir = path.join(process.cwd(), 'uploads');
      fs.mkdirSync(this.uploadsDir, { recursive: true });
      this.logger.warn('R2 credentials not configured — using local disk storage at ./uploads/');
    } else {
      this.s3Client = new S3Client({
        region: 'auto',
        endpoint: configService.get<string>('storage.endpoint'),
        credentials: { accessKeyId, secretAccessKey },
      });
    }
  }

  // ── Local disk helpers ──────────────────────────────────────────────────────

  private getLocalBaseUrl(): string {
    // Allow explicit override via SERVER_BASE_URL env var
    const override = process.env.SERVER_BASE_URL;
    if (override) return override.replace(/\/$/, '');

    const port = this.configService.get<number>('app.port', 3001);

    // Auto-detect the machine's outward-facing LAN IP so mobile devices can reach it
    for (const ifaces of Object.values(os.networkInterfaces())) {
      for (const iface of ifaces ?? []) {
        if (iface.family === 'IPv4' && !iface.internal) {
          return `http://${iface.address}:${port}`;
        }
      }
    }
    return `http://localhost:${port}`;
  }

  private async saveLocally(buffer: Buffer, folder: string, ext: string): Promise<string> {
    const dir = path.join(this.uploadsDir, folder);
    fs.mkdirSync(dir, { recursive: true });
    const filename = `${uuidv4()}.${ext}`;
    fs.writeFileSync(path.join(dir, filename), buffer);
    return `${this.getLocalBaseUrl()}/uploads/${folder}/${filename}`;
  }

  private deleteLocally(url: string): void {
    try {
      // url = http://localhost:3001/uploads/folder/file.ext
      const rel = url.split('/uploads/')[1];
      if (rel) fs.unlinkSync(path.join(this.uploadsDir, rel));
    } catch {
      // ignore missing file
    }
  }

  // ── Public API ──────────────────────────────────────────────────────────────

  async uploadFile(
    file: Express.Multer.File,
    folder: string = 'uploads',
    options?: { resize?: { width: number; height: number }; quality?: number },
  ): Promise<string> {
    let buffer = file.buffer;
    let ext = file.originalname.split('.').pop() || 'jpg';

    if (file.mimetype.startsWith('image/') && options?.resize) {
      buffer = await sharp(buffer)
        .resize(options.resize.width, options.resize.height, { fit: 'cover' })
        .webp({ quality: options.quality || 85 })
        .toBuffer();
      ext = 'webp';
    }

    if (this.useLocal) {
      return this.saveLocally(buffer, folder, ext);
    }

    const key = `${folder}/${uuidv4()}.${ext}`;
    const contentType = ext === 'webp' ? 'image/webp' : file.mimetype;
    await this.s3Client.send(
      new PutObjectCommand({
        Bucket: this.bucketName,
        Key: key,
        Body: buffer,
        ContentType: contentType,
        CacheControl: 'public, max-age=31536000',
      }),
    );
    return `${this.publicUrl}/${key}`;
  }

  async uploadProfileImage(file: Express.Multer.File): Promise<string> {
    return this.uploadFile(file, 'profiles', { resize: { width: 400, height: 400 }, quality: 85 });
  }

  async uploadBannerImage(file: Express.Multer.File): Promise<string> {
    // 1080×528 keeps the exact aspect ratio the mobile app renders banners at
    // (the home + requirement-feed banner box is 358×175 pt ≈ 2.05:1). Matching it
    // here means the app shows the image with no extra cropping. 3× the display box
    // for crisp rendering on high-DPI screens.
    return this.uploadFile(file, 'banners', { resize: { width: 1080, height: 528 }, quality: 90 });
  }

  async uploadNotificationImage(file: Express.Multer.File): Promise<string> {
    // 1024×512 (2:1) is the aspect ratio Android's "big picture" notification style
    // and the iOS attachment preview both render at, so it lands uncropped.
    return this.uploadFile(file, 'notifications', { resize: { width: 1024, height: 512 }, quality: 85 });
  }

  async deleteFile(url: string): Promise<void> {
    if (this.useLocal) {
      this.deleteLocally(url);
      return;
    }
    const key = url.replace(`${this.publicUrl}/`, '');
    await this.s3Client.send(
      new DeleteObjectCommand({ Bucket: this.bucketName, Key: key }),
    );
  }

  async getPresignedUploadUrl(
    folder: string,
    contentType: string,
  ): Promise<{ url: string; key: string; publicUrl: string }> {
    if (this.useLocal) {
      const base = this.getLocalBaseUrl();
      const key = `${folder}/${uuidv4()}.${contentType.split('/')[1]}`;
      return {
        url: `${base}/api/v1/storage/upload`,
        key,
        publicUrl: `${base}/uploads/${key}`,
      };
    }

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
