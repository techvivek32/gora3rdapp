export enum UserRole {
  DRIVER = 'driver',
  TRAVEL_AGENCY = 'travel_agency',
  FLEET_OWNER = 'fleet_owner',
  ADMIN = 'admin',
  SUPER_ADMIN = 'super_admin',
}

export enum MembershipType {
  NEW = 'new',
  ACTIVE = 'active',
  VERIFIED = 'verified',
  PREMIUM = 'premium',
  GOLDEN = 'golden',
}

export enum MembershipBadge {
  NEW = 'new',
  ACTIVE = 'active',
  VERIFIED = 'verified',
  PREMIUM = 'premium',
  GOLDEN = 'golden',
}

export enum VerificationStatus {
  NONE = 'none',
  PENDING = 'pending',
  VERIFIED = 'verified',
  REJECTED = 'rejected',
}
