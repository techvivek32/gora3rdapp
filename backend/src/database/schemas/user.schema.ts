import { Prop, Schema, SchemaFactory } from '@nestjs/mongoose';
import { Document, Types } from 'mongoose';
import { UserRole, MembershipType, VerificationStatus } from '../../common/enums/user-role.enum';

export type UserDocument = User & Document;

@Schema({ timestamps: true, collection: 'users' })
export class User {
  @Prop({ required: true, trim: true })
  fullName: string;

  @Prop({ required: true, unique: true, trim: true, lowercase: true })
  email: string;

  @Prop({ required: true, unique: true, trim: true })
  mobile: string;

  @Prop({ select: false })
  password: string;

  @Prop({ trim: true })
  agencyName: string;

  @Prop({ trim: true })
  city: string;

  @Prop({ trim: true })
  state: string;

  @Prop()
  profileImage: string;

  @Prop()
  coverImage: string;

  @Prop({ type: String, enum: UserRole, default: UserRole.DRIVER })
  role: UserRole;

  @Prop({ type: String, enum: MembershipType, default: MembershipType.NEW })
  membershipType: MembershipType;

  @Prop({ default: false })
  isVerified: boolean;

  @Prop({ default: false })
  isAdminApproved: boolean;

  @Prop({ default: true })
  isActive: boolean;

  @Prop({ default: false })
  isBlocked: boolean;

  @Prop({ default: false })
  isPremium: boolean;

  @Prop({ default: false })
  isGolden: boolean;

  @Prop({ type: [String], default: [] })
  businessCities: string[];

  @Prop({ type: [String], default: [] })
  fcmTokens: string[];

  @Prop({ default: true })
  notificationsEnabled: boolean;

  @Prop({ default: 0, min: 0 })
  walletBalance: number;

  @Prop({ default: 0, min: 0, max: 5 })
  rating: number;

  @Prop({ default: 0 })
  totalRatings: number;

  @Prop()
  lastActive: Date;

  @Prop({ type: Date })
  membershipExpiresAt: Date;

  @Prop({ type: Types.ObjectId, ref: 'Subscription' })
  activeSubscription: Types.ObjectId;

  @Prop({ type: Object, default: {} })
  deviceInfo: {
    deviceId: string;
    platform: string;
    appVersion: string;
    osVersion: string;
  };

  // KYC documents: each entry holds the document id/number and an uploaded image URL.
  @Prop({ type: Object, default: {} })
  documents: {
    aadhar?: { number?: string; image?: string };
    pan?: { number?: string; image?: string };
    drivingLicense?: { number?: string; image?: string };
    vehicleRc?: { number?: string; image?: string };
  };

  @Prop({ type: String, enum: VerificationStatus, default: VerificationStatus.NONE })
  verificationStatus: VerificationStatus;

  @Prop({ type: Date })
  verificationSubmittedAt: Date;

  @Prop({ trim: true })
  verificationRejectionReason: string;

  @Prop({ default: 0 })
  requirementsPosted: number;

  @Prop({ default: 0 })
  vehiclesPosted: number;

  // Referral / invite system
  @Prop({ trim: true, uppercase: true })
  referralCode: string;

  @Prop({ type: Types.ObjectId, ref: 'User' })
  referredBy: Types.ObjectId;

  @Prop({ default: 0 })
  referralCount: number;

  @Prop()
  firebaseUid: string;

  @Prop({ type: String })
  refreshToken: string;

  @Prop({ default: 0 })
  loginAttempts: number;

  @Prop()
  lockUntil: Date;
}

export const UserSchema = SchemaFactory.createForClass(User);

// Indexes for performance
UserSchema.index({ email: 1 }, { unique: true });
UserSchema.index({ mobile: 1 }, { unique: true });
UserSchema.index({ city: 1, membershipType: 1 });
UserSchema.index({ businessCities: 1 });
UserSchema.index({ isActive: 1, isBlocked: 1 });
UserSchema.index({ membershipType: 1, isActive: 1 });
UserSchema.index({ verificationStatus: 1, verificationSubmittedAt: -1 });
UserSchema.index({ createdAt: -1 });
UserSchema.index({ lastActive: -1 });
UserSchema.index({ firebaseUid: 1 });
UserSchema.index({ referralCode: 1 }, { unique: true, sparse: true });
UserSchema.index({ referredBy: 1 });

// Virtual for membership status
UserSchema.virtual('isMembershipActive').get(function () {
  if (!this.membershipExpiresAt) return false;
  return new Date() < this.membershipExpiresAt;
});
