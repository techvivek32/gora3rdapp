import { Module } from '@nestjs/common';
import { MongooseModule } from '@nestjs/mongoose';
import { JwtModule } from '@nestjs/jwt';
import { ConfigModule, ConfigService } from '@nestjs/config';
import { ImpersonationController } from './impersonation.controller';
import { ImpersonationService } from './impersonation.service';
import { User, UserSchema } from '../../database/schemas/user.schema';
import { Franchise, FranchiseSchema } from '../../database/schemas/franchise.schema';
import {
  ImpersonationLog,
  ImpersonationLogSchema,
} from '../../database/schemas/impersonation-log.schema';

@Module({
  imports: [
    JwtModule.registerAsync({
      imports: [ConfigModule],
      useFactory: async (configService: ConfigService) => ({
        secret: configService.get<string>('jwt.secret'),
        signOptions: { expiresIn: configService.get<string>('jwt.expiresIn', '1h') },
      }),
      inject: [ConfigService],
    }),
    MongooseModule.forFeature([
      { name: User.name, schema: UserSchema },
      { name: Franchise.name, schema: FranchiseSchema },
      { name: ImpersonationLog.name, schema: ImpersonationLogSchema },
    ]),
  ],
  controllers: [ImpersonationController],
  providers: [ImpersonationService],
})
export class ImpersonationModule {}
