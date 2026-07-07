import { NestFactory } from '@nestjs/core';
import { ValidationPipe, VersioningType } from '@nestjs/common';
import { DocumentBuilder, SwaggerModule } from '@nestjs/swagger';
import { ConfigService } from '@nestjs/config';
import { NestExpressApplication } from '@nestjs/platform-express';
import { IoAdapter } from '@nestjs/platform-socket.io';
import helmet from 'helmet';
import compression from 'compression';
import * as path from 'path';
import { AppModule } from './app.module';
import { HttpExceptionFilter } from './common/filters/http-exception.filter';
import { ResponseInterceptor } from './common/interceptors/response.interceptor';
import { LoggingInterceptor } from './common/interceptors/logging.interceptor';

async function bootstrap() {
  const app = await NestFactory.create<NestExpressApplication>(AppModule, {
    // In production keep only errors/warnings — 'log'/'debug' floods the CPU & disk.
    logger: process.env.NODE_ENV === 'production'
        ? ['error', 'warn']
        : ['error', 'warn', 'log', 'debug'],
  });

  const configService = app.get(ConfigService);
  const port = configService.get<number>('app.port', 3001);
  const apiPrefix = configService.get<string>('app.apiPrefix', 'api/v1');
  const corsOrigins = configService.get<string>('app.corsOrigins', '').split(',');

  // Serve locally-uploaded files as static assets (CORS headers for Flutter web / admin)
  app.useStaticAssets(path.join(process.cwd(), 'uploads'), {
    prefix: '/uploads',
    setHeaders: (res) => {
      res.setHeader('Access-Control-Allow-Origin', '*');
      res.setHeader('Cross-Origin-Resource-Policy', 'cross-origin');
    },
  });

  // Security middleware (disable CORP so images load cross-origin)
  app.use(helmet({ contentSecurityPolicy: false, crossOriginResourcePolicy: false }));
  app.use(compression());

  // CORS configuration
  const allowedOrigins = corsOrigins.map((o) => o.trim()).filter(Boolean);
  app.enableCors({
    origin: (origin: string | undefined, callback: (err: Error | null, allow?: boolean) => void) => {
      // Allow non-browser clients (mobile apps / curl) that send no Origin header,
      // any localhost / 127.0.0.1 origin on any port (Flutter web dev), and the
      // configured production origins.
      const isLocalhost = !!origin && /^https?:\/\/(localhost|127\.0\.0\.1)(:\d+)?$/.test(origin);
      if (!origin || isLocalhost || allowedOrigins.includes(origin)) {
        return callback(null, true);
      }
      return callback(null, false);
    },
    methods: ['GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'OPTIONS'],
    allowedHeaders: ['Content-Type', 'Authorization', 'X-Refresh-Token', 'X-Device-ID'],
    credentials: true,
  });

  // Global prefix and versioning
  app.setGlobalPrefix(apiPrefix);
  app.enableVersioning({ type: VersioningType.URI });

  // WebSocket adapter
  app.useWebSocketAdapter(new IoAdapter(app));

  // Global pipes, filters, interceptors
  app.useGlobalPipes(
    new ValidationPipe({
      whitelist: true,
      forbidNonWhitelisted: true,
      transform: true,
      transformOptions: { enableImplicitConversion: true },
    }),
  );
  app.useGlobalFilters(new HttpExceptionFilter());
  app.useGlobalInterceptors(new LoggingInterceptor(), new ResponseInterceptor());

  // Swagger API Documentation
  if (configService.get('NODE_ENV') !== 'production') {
    const swaggerConfig = new DocumentBuilder()
      .setTitle('Gora Cabs API')
      .setDescription('Taxi Requirement & Available Cab Network Platform')
      .setVersion('1.0.0')
      .addBearerAuth({ type: 'http', scheme: 'bearer', bearerFormat: 'JWT' }, 'access-token')
      .addBearerAuth({ type: 'http', scheme: 'bearer', bearerFormat: 'JWT' }, 'refresh-token')
      .addTag('Authentication', 'Auth endpoints')
      .addTag('Users', 'User management')
      .addTag('Requirements', 'Vehicle requirements')
      .addTag('Available Vehicles', 'Available cab listings')
      .addTag('Cities', 'City management')
      .addTag('Chat', 'Messaging system')
      .addTag('Notifications', 'Push notifications')
      .addTag('Payments', 'Payment processing')
      .addTag('Subscriptions', 'Membership plans')
      .addTag('Reports', 'User reports')
      .addTag('Banners', 'Banner management')
      .addTag('Admin', 'Admin operations')
      .addTag('Analytics', 'Analytics & reporting')
      .addServer(`http://localhost:${port}`, 'Local Development')
      .build();

    const document = SwaggerModule.createDocument(app, swaggerConfig);
    SwaggerModule.setup('api/docs', app, document, {
      swaggerOptions: { persistAuthorization: true },
    });
  }

  // Bind to localhost only — nginx reverse-proxies public traffic to it. This
  // keeps the API off the public internet so it can't be hit directly.
  const host = process.env.BIND_HOST || '127.0.0.1';
  await app.listen(port, host);
  console.log(`🚀 Gora Cabs API running on: http://localhost:${port}/${apiPrefix}`);
  console.log(`📄 Swagger docs: http://localhost:${port}/api/docs`);
}

bootstrap().catch(console.error);
