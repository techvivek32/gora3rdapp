import { BadRequestException, ForbiddenException } from '@nestjs/common';
import { Model } from 'mongoose';
import { UserRole } from '../enums/user-role.enum';

/**
 * Resolve the account a GUEST booking belongs to, from an unverified name +
 * mobile number.
 *
 * Shared by the customer-booking and car-pool guest endpoints so the rules that
 * make this safe live in exactly one place:
 *
 *  - The caller must NEVER issue tokens or return account data off the back of
 *    this. The number carries no proof of ownership (there is no OTP by
 *    product choice), so treating it as identity would be an authentication
 *    bypass — anyone could "become" any user by typing their number. Returning
 *    only the created booking is what keeps that door shut.
 *  - An existing account with this number is reused, so the booking shows up in
 *    that customer's app. The flip side is that a mistyped number files the
 *    booking under a stranger's account; that is the accepted cost of skipping
 *    verification, and a booking is not sensitive data.
 *  - A new account is created with NO password, so it cannot be signed into
 *    until the person registers properly.
 */
export async function resolveGuestUser(
  userModel: Model<any>,
  guest: { name?: string; mobile?: string; email?: string },
): Promise<{ userId: string; created: boolean }> {
  const mobile = (guest.mobile || '').replace(/\D/g, '').slice(-10);
  if (!/^[6-9]\d{9}$/.test(mobile)) {
    throw new BadRequestException('Enter a valid 10-digit mobile number');
  }
  const name = (guest.name || '').trim();
  if (!name) throw new BadRequestException('Enter your name');

  // Match on the last 10 digits, like every other lookup here: accounts exist
  // both as "9876543210" and "+919876543210".
  const existing: any = await userModel
    .findOne({ mobile: new RegExp(`${mobile}$`) })
    .select('_id isBlocked')
    .lean();

  if (existing) {
    if (existing.isBlocked) {
      throw new ForbiddenException('This number cannot place bookings. Please contact support.');
    }
    return { userId: existing._id.toString(), created: false };
  }

  const created = await userModel.create({
    fullName: name,
    mobile,
    ...(guest.email?.trim() ? { email: guest.email.trim().toLowerCase() } : {}),
    role: UserRole.CUSTOMER,
    // Onboarded, so when they do sign in with this number they land straight in
    // customer mode with their booking already waiting.
    customerOnboarded: true,
    isActive: true,
  });
  return { userId: created._id.toString(), created: true };
}
