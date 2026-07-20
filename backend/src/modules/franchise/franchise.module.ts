import { Module } from '@nestjs/common';
import { MongooseModule } from '@nestjs/mongoose';
import { FranchiseController } from './franchise.controller';
import { FranchiseService } from './franchise.service';
import { Franchise, FranchiseSchema } from '../../database/schemas/franchise.schema';

@Module({
  imports: [
    MongooseModule.forFeature([
      { name: Franchise.name, schema: FranchiseSchema },
    ]),
  ],
  controllers: [FranchiseController],
  providers: [FranchiseService],
})
export class FranchiseModule {}
