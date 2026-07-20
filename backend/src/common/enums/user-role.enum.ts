export enum UserRole {
  DRIVER = 'driver',
  TRAVEL_AGENCY = 'travel_agency',
  FLEET_OWNER = 'fleet_owner',
  ADMIN = 'admin',
  SUPER_ADMIN = 'super_admin',
  // A city-scoped operator. Sees/acts on only their own city's data (enforced in
  // AdminService via the franchiseCity passed from the JWT). Never has cross-city
  // or platform-config access (plans, banners, notifications, other franchises).
  FRANCHISE = 'franchise',
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
