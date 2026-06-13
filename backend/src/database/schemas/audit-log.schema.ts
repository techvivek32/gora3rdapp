import { Prop, Schema, SchemaFactory } from '@nestjs/mongoose';
import { Document, Types } from 'mongoose';

export type AuditLogDocument = AuditLog & Document;

@Schema({ timestamps: true, collection: 'auditLogs' })
export class AuditLog {
  @Prop({ type: Types.ObjectId, ref: 'User' })
  userId: Types.ObjectId;

  @Prop({ required: true })
  action: string;

  @Prop({ required: true })
  resource: string;

  @Prop()
  resourceId: string;

  @Prop({ type: Object })
  changes: {
    before: Record<string, any>;
    after: Record<string, any>;
  };

  @Prop()
  ipAddress: string;

  @Prop()
  userAgent: string;

  @Prop()
  endpoint: string;

  @Prop()
  method: string;

  @Prop({ default: 200 })
  statusCode: number;

  @Prop({ type: Object })
  metadata: Record<string, any>;
}

export const AuditLogSchema = SchemaFactory.createForClass(AuditLog);

AuditLogSchema.index({ userId: 1, createdAt: -1 });
AuditLogSchema.index({ action: 1, resource: 1 });
AuditLogSchema.index({ createdAt: -1 });
AuditLogSchema.index({ resourceId: 1, resource: 1 });
