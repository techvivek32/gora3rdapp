export enum VehicleType {
  HATCHBACK = 'hatchback',
  SEDAN = 'sedan',
  SUV = 'suv',
  INNOVA = 'innova',
  ERTIGA = 'ertiga',
  TEMPO_TRAVELLER = 'tempo_traveller',
  MINI_BUS = 'mini_bus',
  BUS = 'bus',
  AUTO = 'auto',
  BIKE = 'bike',
}

export enum TripType {
  ONE_WAY = 'one_way',
  ROUND_TRIP = 'round_trip',
  AIRPORT_TRANSFER = 'airport_transfer',
  LOCAL = 'local',
  OUTSTATION = 'outstation',
}

export enum BookingStatus {
  ACTIVE = 'active',
  ACCEPTED = 'accepted',
  COMPLETED = 'completed',
  CANCELLED = 'cancelled',
  EXPIRED = 'expired',
}

export enum AvailabilityStatus {
  AVAILABLE = 'available',
  BOOKED = 'booked',
  EXPIRED = 'expired',
}
