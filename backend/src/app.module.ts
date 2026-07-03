import { Module } from '@nestjs/common';
import { ConfigModule, ConfigService } from '@nestjs/config';
import { MongooseModule } from '@nestjs/mongoose';
import { ThrottlerModule } from '@nestjs/throttler';
import { ScheduleModule } from '@nestjs/schedule';
import appConfig from './config/app.config';
import databaseConfig from './config/database.config';
import jwtConfig from './config/jwt.config';
import firebaseConfig from './config/firebase.config';
import storageConfig from './config/storage.config';
import razorpayConfig from './config/razorpay.config';
import smsConfig from './config/sms.config';
import { AuthModule } from './modules/auth/auth.module';
import { UsersModule } from './modules/users/users.module';
import { RequirementsModule } from './modules/requirements/requirements.module';
import { AvailableVehiclesModule } from './modules/available-vehicles/available-vehicles.module';
import { CitiesModule } from './modules/cities/cities.module';
import { NotificationsModule } from './modules/notifications/notifications.module';
import { ChatModule } from './modules/chat/chat.module';
import { PaymentsModule } from './modules/payments/payments.module';
import { SubscriptionsModule } from './modules/subscriptions/subscriptions.module';
import { ReportsModule } from './modules/reports/reports.module';
import { BannersModule } from './modules/banners/banners.module';
import { AdminModule } from './modules/admin/admin.module';
import { AnalyticsModule } from './modules/analytics/analytics.module';
import { StorageModule } from './modules/storage/storage.module';
import { HealthModule } from './modules/health/health.module';
import { SettingsModule } from './modules/settings/settings.module';
import { WalletModule } from './modules/wallet/wallet.module';
import { PlacesModule } from './modules/places/places.module';

@Module({
  imports: [
    // Configuration
    ConfigModule.forRoot({
      isGlobal: true,
      load: [appConfig, databaseConfig, jwtConfig, firebaseConfig, storageConfig, razorpayConfig, smsConfig],
      envFilePath: ['.env.local', '.env'],
      cache: true,
    }),

    // Database
    MongooseModule.forRootAsync({
      imports: [ConfigModule],
      useFactory: async (configService: ConfigService) => ({
        uri: configService.get<string>('database.uri'),
        dbName: configService.get<string>('database.name'),
        connectionFactory: (connection) => {
          connection.on('connected', () => console.log('✅ MongoDB connected'));
          connection.on('error', (err) => console.error('❌ MongoDB error:', err));
          return connection;
        },
        autoIndex: process.env.NODE_ENV !== 'production',
        maxPoolSize: 20,
        serverSelectionTimeoutMS: 5000,
        socketTimeoutMS: 45000,
        bufferCommands: false,
      }),
      inject: [ConfigService],
    }),

    // Rate Limiting
    ThrottlerModule.forRootAsync({
      imports: [ConfigModule],
      useFactory: (configService: ConfigService) => ([{
        ttl: configService.get<number>('app.throttle.ttl', 60),
        limit: configService.get<number>('app.throttle.limit', 100),
      }]),
      inject: [ConfigService],
    }),

    // Scheduler
    ScheduleModule.forRoot(),

    // Feature Modules
    AuthModule,
    UsersModule,
    RequirementsModule,
    AvailableVehiclesModule,
    CitiesModule,
    NotificationsModule,
    ChatModule,
    PaymentsModule,
    SubscriptionsModule,
    ReportsModule,
    BannersModule,
    AdminModule,
    AnalyticsModule,
    StorageModule,
    HealthModule,
    SettingsModule,
    WalletModule,
    PlacesModule,
  ],
})
export class AppModule {}
