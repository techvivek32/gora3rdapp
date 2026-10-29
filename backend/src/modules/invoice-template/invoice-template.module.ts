import { Module } from '@nestjs/common';
import { MongooseModule } from '@nestjs/mongoose';
import { InvoiceTemplateService } from './invoice-template.service';
import { InvoiceTemplate, InvoiceTemplateSchema } from '../../database/schemas/invoice-template.schema';

@Module({
  imports: [
    MongooseModule.forFeature([
      { name: InvoiceTemplate.name, schema: InvoiceTemplateSchema },
    ]),
  ],
  providers: [InvoiceTemplateService],
  exports: [InvoiceTemplateService],
})
export class InvoiceTemplateModule {}
