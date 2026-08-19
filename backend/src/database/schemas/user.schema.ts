import { Prop, Schema, SchemaFactory } from '@nestjs/mongoose';
import { Document, Types } from 'mongoose';
import { UserRole, MembershipType, VerificationStatus } from '../../common/enums/user-role.enum';

export type UserDocument = User & Document;

/** Per-document review state. Absent `status` means 'pending' (legacy rows). */
export type DocumentStatus = 'pending' | 'approved' | 'rejected';

export interface DocumentEntry {
  number?: string;
  image?: string; // front
  backImage?: string; // back
  status?: DocumentStatus;
  rejectionReason?: string;
  reviewedAt?: Date;
}

/** Every KYC document key the platform knows about. */
export const DOCUMENT_KEYS = ['aadhar', 'pan', 'drivingLicense', 'vehicleRc'] as const;

@Schema({ timestamps: true, collection: 'users' })
export class User {
  @Prop({ required: true, trim: true })
  fullName: string;

  // Email is optional (registration only needs a mobile number). The unique+sparse
  // index is declared once at the bottom via UserSchema.index() — don't also set
  // `unique` here or Mongoose warns about a duplicate index definition.
  @Prop({ trim: true, lowercase: true })
  email: string;

  @Prop({ required: true, trim: true })
  mobile: string;

  @Prop({ select: false })
  password: string;

  @Prop({ trim: true })
  agencyName: string;

  @Prop({ trim: true })
  city: string;

  @Prop({ trim: true })
  state: string;

  // ─── Last known GPS location (captured on app open; shown as "Last Login: …") ──
  @Prop({ type: Number })
  lastLat?: number;

  @Prop({ type: Number })
  lastLng?: number;

  /** Reverse-geocoded human address of the last location (e.g. "Raghunathpura 313001, Rajasthan"). */
  @Prop({ trim: true })
  lastLocationAddress?: string;

  /** When the last location was captured. */
  @Prop({ type: Date })
  lastLocationAt?: Date;

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

  // Off by default — booking alerts (ring + pop-up) are opt-in. The user turns
  // them on from the home screen; only then does the server push new bookings.
  @Prop({ default: false })
  notificationsEnabled: boolean;

  // Alert filters: only notify this user for requirements matching these vehicle
  // and trip types. Empty array = no filter (match all).
  @Prop({ type: [String], default: [] })
  alertVehicleTypes: string[];

  @Prop({ type: [String], default: [] })
  alertTripTypes: string[];

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

  // KYC documents: each entry holds the document id/number, the front (`image`)
  // and back (`backImage`) photo URLs, and its OWN review status — an admin can
  // approve the Aadhaar while rejecting the PAN, and the user then only has to
  // re-upload the PAN. Missing `status` is treated as 'pending' (legacy rows).
  @Prop({ type: Object, default: {} })
  documents: {
    [key: string]: DocumentEntry | undefined;
    aadhar?: DocumentEntry;
    pan?: DocumentEntry;
    drivingLicense?: DocumentEntry;
    vehicleRc?: DocumentEntry;
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

  // Current active login session. Every login rotates this; tokens carry it and
  // are rejected once it changes — enforces single-device login for app users.
  @Prop({ type: String })
  sessionId: string;

  @Prop({ default: 0 })
  loginAttempts: number;

  @Prop()
  lockUntil: Date;
}

export const UserSchema = SchemaFactory.createForClass(User);

// Indexes for performance
UserSchema.index({ email: 1 }, { unique: true, sparse: true });
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
