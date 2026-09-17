import { BadRequestException, ForbiddenException, Injectable, NotFoundException } from '@nestjs/common';
import { InjectModel } from '@nestjs/mongoose';
import { Model, Types } from 'mongoose';
import { PoolRide, PoolRideDocument, PoolRideStatus, SeatBookingStatus } from '../../database/schemas/pool-ride.schema';
import { User, UserDocument } from '../../database/schemas/user.schema';
import { NotificationsService } from '../notifications/notifications.service';
import {
  BookSeatsDto,
  CancelDto,
  CompleteRideDto,
  CreatePoolRideDto,
  PickupDto,
  RatePoolRideDto,
  UpdatePoolRideDto,
} from './dto/car-pool.dto';

/// Car Pooling: a driver posts a ride with seats + per-seat price; passengers
/// book seats. Payment is direct (passenger pays the driver, like the rest of
/// the Gora app) — the earnings screen reports what each ride earned; it does
/// NOT credit the withdrawable wallet balance.
@Injectable()
export class CarPoolService {
  constructor(
    @InjectModel(PoolRide.name) private readonly rideModel: Model<PoolRideDocument>,
    @InjectModel(User.name) private readonly userModel: Model<UserDocument>,
    private readonly notifications: NotificationsService,
  ) {}

  private genRideId(): string {
    return `CP${Date.now().toString().slice(-7)}${Math.floor(100 + Math.random() * 900)}`;
  }

  private oid(id: string): Types.ObjectId {
    if (!Types.ObjectId.isValid(id)) throw new BadRequestException('Invalid id');
    return new Types.ObjectId(id);
  }

  // ─── Driver: create / manage ────────────────────────────────────────────────

  async createRide(driverId: string, dto: CreatePoolRideDto) {
    if (dto.pricePerSeat < 0 || dto.totalSeats < 1) throw new BadRequestException('Invalid seats or price');
    const driver = await this.userModel.findById(driverId).select('fullName mobile rating').lean();
    if (!driver) throw new NotFoundException('Driver not found');

    const travelDate = dto.travelDate ? new Date(dto.travelDate) : undefined;
    const expiresAt = travelDate
      ? new Date(travelDate.getTime() + 24 * 60 * 60 * 1000)
      : new Date(Date.now() + 7 * 24 * 60 * 60 * 1000);

    const ride = await this.rideModel.create({
      rideId: this.genRideId(),
      driverId: this.oid(driverId),
      from: dto.from ?? {},
      to: dto.to ?? {},
      fromCity: dto.fromCity ?? '',
      toCity: dto.toCity ?? '',
      travelDate,
      departureTime: dto.departureTime ?? '',
      totalSeats: dto.totalSeats,
      seatsAvailable: dto.totalSeats,
      pricePerSeat: dto.pricePerSeat,
      vehicle: dto.vehicle ?? '',
      vehicleNumber: dto.vehicleNumber ?? '',
      distanceKm: dto.distanceKm ?? 0,
      notes: dto.notes ?? '',
      status: PoolRideStatus.ACTIVE,
      bookings: [],
      driverSnapshot: {
        name: driver.fullName,
        phone: driver.mobile,
        rating: driver.rating ?? 0,
        vehicle: dto.vehicle ?? '',
        vehicleNumber: dto.vehicleNumber ?? '',
      },
      expiresAt,
    });
    return { message: 'Ride posted successfully', data: ride };
  }

  async listMyRides(driverId: string, status?: string) {
    const past = [PoolRideStatus.COMPLETED, PoolRideStatus.CANCELLED];
    const active = [PoolRideStatus.ACTIVE, PoolRideStatus.STARTED];
    const filter: any = { driverId: this.oid(driverId) };
    if (status === 'past') filter.status = { $in: past };
    else if (status === 'active') filter.status = { $in: active };
    const rides = await this.rideModel.find(filter).sort({ createdAt: -1 }).limit(200).lean();
    return { message: 'My rides', data: rides };
  }

  async updateRide(driverId: string, id: string, dto: UpdatePoolRideDto) {
    const ride = await this.rideModel.findById(this.oid(id));
    if (!ride) throw new NotFoundException('Ride not found');
    if (ride.driverId.toString() !== driverId) throw new ForbiddenException('Not your ride');
    if (ride.status !== PoolRideStatus.ACTIVE) throw new BadRequestException('Only active rides can be edited');

    const booked = ride.totalSeats - ride.seatsAvailable;
    if (dto.totalSeats != null) {
      if (dto.totalSeats < booked) throw new BadRequestException(`Already ${booked} seat(s) booked; cannot reduce below that`);
      ride.seatsAvailable = dto.totalSeats - booked;
      ride.totalSeats = dto.totalSeats;
    }
    if (dto.from) ride.from = dto.from;
    if (dto.to) ride.to = dto.to;
    if (dto.fromCity != null) ride.fromCity = dto.fromCity;
    if (dto.toCity != null) ride.toCity = dto.toCity;
    if (dto.travelDate) ride.travelDate = new Date(dto.travelDate);
    if (dto.departureTime != null) ride.departureTime = dto.departureTime;
    if (dto.pricePerSeat != null) ride.pricePerSeat = dto.pricePerSeat;
    if (dto.vehicle != null) {
      ride.vehicle = dto.vehicle;
      ride.driverSnapshot = { ...(ride.driverSnapshot ?? {}), vehicle: dto.vehicle };
    }
    if (dto.vehicleNumber != null) {
      ride.vehicleNumber = dto.vehicleNumber;
      ride.driverSnapshot = { ...(ride.driverSnapshot ?? {}), vehicleNumber: dto.vehicleNumber };
    }
    if (dto.distanceKm != null) ride.distanceKm = dto.distanceKm;
    if (dto.notes != null) ride.notes = dto.notes;
    await ride.save();

    // Tell booked passengers the ride details changed.
    for (const b of ride.bookings) {
      if (b.status === SeatBookingStatus.CONFIRMED) {
        this.notifications
          .notifyUser(b.passengerId, '✏️ Ride Updated', `Your pool ride ${ride.fromCity} → ${ride.toCity} was updated by the driver.`, {
            type: 'pool_ride_updated',
            rideId: ride.rideId,
          })
          .catch(() => {});
      }
    }
    return { message: 'Ride updated', data: ride };
  }

  async stopRide(driverId: string, id: string, dto: CancelDto) {
    const ride = await this.rideModel.findOneAndUpdate(
      { _id: this.oid(id), driverId: this.oid(driverId), status: { $in: [PoolRideStatus.ACTIVE, PoolRideStatus.STARTED] } },
      { $set: { status: PoolRideStatus.CANCELLED } },
      { new: true },
    );
    if (!ride) throw new BadRequestException('Ride not found or cannot be stopped');
    for (const b of ride.bookings) {
      if (b.status === SeatBookingStatus.CONFIRMED || b.status === SeatBookingStatus.PICKED) {
        b.status = SeatBookingStatus.CANCELLED;
        this.notifications
          .notifyUser(b.passengerId, '❌ Ride Cancelled', `The driver cancelled the pool ride ${ride.fromCity} → ${ride.toCity}. ${dto.reason ?? ''}`.trim(), {
            type: 'pool_ride_cancelled',
            rideId: ride.rideId,
          })
          .catch(() => {});
      }
    }
    await ride.save();
    return { message: 'Ride stopped', data: ride };
  }

  // ─── Driver: trip lifecycle ─────────────────────────────────────────────────

  async startRide(driverId: string, id: string) {
    const ride = await this.rideModel.findOneAndUpdate(
      { _id: this.oid(id), driverId: this.oid(driverId), status: PoolRideStatus.ACTIVE },
      { $set: { status: PoolRideStatus.STARTED, startedAt: new Date() } },
      { new: true },
    );
    if (!ride) throw new BadRequestException('Ride not found or already started');
    for (const b of ride.bookings) {
      if (b.status === SeatBookingStatus.CONFIRMED) {
        this.notifications
          .notifyUser(b.passengerId, '🚗 Ride Started', `Your pool ride ${ride.fromCity} → ${ride.toCity} has started. The driver is on the way.`, {
            type: 'pool_ride_started',
            rideId: ride.rideId,
          })
          .catch(() => {});
      }
    }
    return { message: 'Ride started', data: ride };
  }

  async markPickup(driverId: string, id: string, dto: PickupDto) {
    const ride = await this.rideModel.findById(this.oid(id));
    if (!ride) throw new NotFoundException('Ride not found');
    if (ride.driverId.toString() !== driverId) throw new ForbiddenException('Not your ride');
    if (ride.status !== PoolRideStatus.STARTED) throw new BadRequestException('Start the ride first');

    const ids = new Set(dto.bookingIds);
    let changed = 0;
    for (const b of ride.bookings) {
      if (ids.has((b as any)._id.toString()) && b.status === SeatBookingStatus.CONFIRMED) {
        b.status = SeatBookingStatus.PICKED;
        changed++;
        this.notifications
          .notifyUser(b.passengerId, '✅ Picked Up', `You've been marked as picked up for ${ride.fromCity} → ${ride.toCity}.`, {
            type: 'pool_passenger_picked',
            rideId: ride.rideId,
          })
          .catch(() => {});
      }
    }
    if (!changed) throw new BadRequestException('No matching passengers to pick up');
    await ride.save();
    return { message: 'Passengers marked as picked up', data: ride };
  }

  async completeRide(driverId: string, id: string, dto: CompleteRideDto) {
    const ride = await this.rideModel.findOneAndUpdate(
      { _id: this.oid(id), driverId: this.oid(driverId), status: PoolRideStatus.STARTED },
      { $set: { status: PoolRideStatus.COMPLETED, completedAt: new Date() } },
      { new: true },
    );
    if (!ride) throw new BadRequestException('Ride not found or not in progress');

    let earning = 0;
    for (const b of ride.bookings) {
      if (b.status === SeatBookingStatus.CONFIRMED || b.status === SeatBookingStatus.PICKED) {
        b.status = SeatBookingStatus.COMPLETED;
        earning += b.amount || 0;
        this.notifications
          .notifyUser(b.passengerId, '🎉 Ride Completed', `Your pool ride ${ride.fromCity} → ${ride.toCity} is complete. Please rate your driver.`, {
            type: 'pool_ride_completed',
            rideId: ride.rideId,
          })
          .catch(() => {});
      }
    }
    ride.totalEarning = earning;
    if (dto.distanceTravelled != null) ride.distanceTravelled = dto.distanceTravelled;
    else if (ride.distanceKm) ride.distanceTravelled = ride.distanceKm;
    await ride.save();
    return { message: 'Ride completed', data: ride };
  }

  async earnings(driverId: string) {
    const rides = await this.rideModel
      .find({ driverId: this.oid(driverId), status: PoolRideStatus.COMPLETED })
      .sort({ completedAt: -1 })
      .limit(200)
      .lean();
    const totalEarning = rides.reduce((s, r) => s + (r.totalEarning || 0), 0);
    const totalRides = rides.length;
    const totalSeatsSold = rides.reduce(
      (s, r) => s + (r.bookings || []).filter((b: any) => b.status === SeatBookingStatus.COMPLETED).reduce((x: number, b: any) => x + (b.seats || 0), 0),
      0,
    );
    return { message: 'Earnings', data: { totalEarning, totalRides, totalSeatsSold, rides } };
  }

  // ─── Passenger: search / book ───────────────────────────────────────────────

  async searchAvailable(userId: string, q: { from?: string; to?: string; date?: string }): Promise<{ message: string; data: any }> {
    const filter: any = {
      status: PoolRideStatus.ACTIVE,
      seatsAvailable: { $gt: 0 },
      driverId: { $ne: this.oid(userId) },
    };
    if (q.from) filter.fromCity = new RegExp(`^${escapeRegex(q.from)}`, 'i');
    if (q.to) filter.toCity = new RegExp(`^${escapeRegex(q.to)}`, 'i');
    if (q.date) {
      const start = new Date(q.date);
      start.setHours(0, 0, 0, 0);
      const end = new Date(start.getTime() + 24 * 60 * 60 * 1000);
      filter.travelDate = { $gte: start, $lt: end };
    } else {
      filter.travelDate = { $gte: new Date(Date.now() - 12 * 60 * 60 * 1000) };
    }
    const rides = await this.rideModel.find(filter).sort({ travelDate: 1 }).limit(200).lean();
    // Strip other passengers' PII from public search results.
    const cleaned = rides.map((r) => ({ ...r, bookings: undefined }));
    return { message: 'Available rides', data: cleaned };
  }

  async bookSeats(passengerId: string, id: string, dto: BookSeatsDto) {
    if (dto.seats < 1) throw new BadRequestException('Seats must be at least 1');
    const ridePeek = await this.rideModel.findById(this.oid(id)).select('driverId pricePerSeat fromCity toCity rideId bookings').lean();
    if (!ridePeek) throw new NotFoundException('Ride not found');
    if (ridePeek.driverId.toString() === passengerId) throw new BadRequestException('You cannot book your own ride');
    const already = (ridePeek.bookings || []).some(
      (b: any) => b.passengerId?.toString() === passengerId && (b.status === SeatBookingStatus.CONFIRMED || b.status === SeatBookingStatus.PICKED),
    );
    if (already) throw new BadRequestException('You already have a booking on this ride');

    const passenger = await this.userModel.findById(passengerId).select('fullName mobile profileImage').lean();
    if (!passenger) throw new NotFoundException('Passenger not found');

    const amount = dto.seats * (ridePeek.pricePerSeat || 0);
    const booking = {
      _id: new Types.ObjectId(),
      passengerId: this.oid(passengerId),
      passengerName: passenger.fullName ?? '',
      passengerMobile: passenger.mobile ?? '',
      passengerImage: passenger.profileImage ?? '',
      seats: dto.seats,
      amount,
      pickupPoint: dto.pickupPoint ?? '',
      status: SeatBookingStatus.CONFIRMED,
    };

    // Atomic: only succeeds if the ride is still active with enough free seats.
    const ride = await this.rideModel.findOneAndUpdate(
      { _id: this.oid(id), status: PoolRideStatus.ACTIVE, seatsAvailable: { $gte: dto.seats } },
      { $inc: { seatsAvailable: -dto.seats }, $push: { bookings: booking } },
      { new: true },
    );
    if (!ride) throw new BadRequestException('Not enough seats available or ride closed');

    this.notifications
      .notifyUser(ride.driverId, '🆕 New Booking!', `${passenger.fullName} booked ${dto.seats} seat(s) for ${ride.fromCity} → ${ride.toCity}.`, {
        type: 'pool_seat_booked',
        rideId: ride.rideId,
      })
      .catch(() => {});

    return { message: 'Seats booked', data: { rideId: ride.rideId, bookingId: booking._id.toString(), seats: dto.seats, amount } };
  }

  async cancelBooking(passengerId: string, id: string) {
    const ride = await this.rideModel.findById(this.oid(id));
    if (!ride) throw new NotFoundException('Ride not found');
    const booking = ride.bookings.find(
      (b: any) => b.passengerId?.toString() === passengerId && (b.status === SeatBookingStatus.CONFIRMED || b.status === SeatBookingStatus.PICKED),
    );
    if (!booking) throw new NotFoundException('Active booking not found');
    if (ride.status === PoolRideStatus.COMPLETED) throw new BadRequestException('Ride already completed');

    booking.status = SeatBookingStatus.CANCELLED;
    ride.seatsAvailable = Math.min(ride.totalSeats, ride.seatsAvailable + (booking.seats || 0));
    await ride.save();

    this.notifications
      .notifyUser(ride.driverId, '🚫 Seat Cancelled', `A passenger cancelled ${booking.seats} seat(s) on ${ride.fromCity} → ${ride.toCity}.`, {
        type: 'pool_seat_cancelled',
        rideId: ride.rideId,
      })
      .catch(() => {});

    return { message: 'Booking cancelled', data: { rideId: ride.rideId } };
  }

  async myBookings(passengerId: string): Promise<{ message: string; data: any }> {
    const rides = await this.rideModel
      .find({ 'bookings.passengerId': this.oid(passengerId) })
      .sort({ createdAt: -1 })
      .limit(200)
      .lean();
    // Return each ride with ONLY this passenger's booking attached.
    const data = rides.map((r) => {
      const mine = (r.bookings || []).filter((b: any) => b.passengerId?.toString() === passengerId);
      return { ...r, bookings: undefined, myBooking: mine[mine.length - 1] ?? null };
    });
    return { message: 'My bookings', data };
  }

  async rateRide(passengerId: string, id: string, dto: RatePoolRideDto) {
    const ride = await this.rideModel.findById(this.oid(id));
    if (!ride) throw new NotFoundException('Ride not found');
    const booking = ride.bookings.find((b: any) => b.passengerId?.toString() === passengerId);
    if (!booking) throw new NotFoundException('Booking not found');
    if (booking.status !== SeatBookingStatus.COMPLETED) throw new BadRequestException('You can rate only after the ride is completed');
    if (booking.rating && booking.rating > 0) throw new BadRequestException('Already rated');

    booking.rating = dto.rating;
    booking.review = dto.review ?? '';
    await ride.save();

    // Update the driver's aggregate rating.
    const driver = await this.userModel.findById(ride.driverId).select('rating totalRatings');
    if (driver) {
      const total = (driver.totalRatings ?? 0) + 1;
      const newRating = ((driver.rating ?? 0) * (driver.totalRatings ?? 0) + dto.rating) / total;
      await this.userModel.updateOne({ _id: ride.driverId }, { $set: { rating: newRating, totalRatings: total } });
    }
    return { message: 'Thanks for rating', data: { rideId: ride.rideId } };
  }

  // ─── Shared: ride details ────────────────────────────────────────────────────

  async getRide(userId: string, id: string): Promise<{ message: string; data: any }> {
    const ride = await this.rideModel.findById(this.oid(id)).lean();
    if (!ride) throw new NotFoundException('Ride not found');
    const isOwner = ride.driverId.toString() === userId;
    if (!isOwner) {
      // Passengers see the ride + only their own booking, not other passengers.
      const mine = (ride.bookings || []).filter((b: any) => b.passengerId?.toString() === userId);
      return { message: 'Ride', data: { ...ride, bookings: undefined, myBooking: mine[mine.length - 1] ?? null } };
    }
    return { message: 'Ride', data: ride };
  }

  // ─── Admin ──────────────────────────────────────────────────────────────────

  async listAllForAdmin(query: { status?: string }) {
    const filter: any = {};
    if (query.status) filter.status = query.status;
    const rides = await this.rideModel
      .find(filter)
      .sort({ createdAt: -1 })
      .limit(500)
      .populate('driverId', 'fullName mobile city rating')
      .lean();
    return { message: 'All pool rides', data: rides };
  }
}

function escapeRegex(s: string): string {
  return s.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}
