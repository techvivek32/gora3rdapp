export enum VehicleType {
  HATCHBACK = 'hatchback',
  EECO = 'eeco',
  SEDAN = 'sedan',
  ERTIGA = 'ertiga',
  RUMION = 'rumion',
  CARENS = 'carens',
  INNOVA = 'innova',
  CRYSTA = 'crysta',
  HYCROSS = 'hycross',
  TEMPO_TRAVELLER = 'tempo_traveller',
  URBANIA = 'urbania',
  TRAX_CRUISER = 'trax_cruiser',
  SMALL_COACH = 'small_coach',
  LUXURY_COACH = 'luxury_coach',
  PREMIUM = 'premium',
  // Legacy values kept for existing records.
  SUV = 'suv',
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
  ON_HOLD = 'on_hold',
  ACCEPTED = 'accepted',
  COMPLETED = 'completed',
  CANCELLED = 'cancelled',
  EXPIRED = 'expired',
}

export enum AvailabilityStatus {
  AVAILABLE = 'available',
  ON_HOLD = 'on_hold',
  BOOKED = 'booked',
  CANCELLED = 'cancelled',
  EXPIRED = 'expired',
}
