'use client';

import { Phone, User2 } from 'lucide-react';

export interface GuestInfo {
  name: string;
  mobile: string;
}

/** True when the guest has given enough to place a booking. */
export function guestReady(g: GuestInfo): boolean {
  return g.name.trim().length >= 2 && /^[6-9]\d{9}$/.test(g.mobile.replace(/\D/g, ''));
}

/**
 * Name + mobile, collected at the point of booking for visitors who are not
 * signed in.
 *
 * There is no OTP — the number is taken on trust — so this is the only thing
 * tying a booking to a person. The copy says plainly that the driver will call
 * on it, because a typo here is how a customer ends up never hearing from us.
 */
export function GuestFields({
  value,
  onChange,
}: {
  value: GuestInfo;
  onChange: (g: GuestInfo) => void;
}) {
  return (
    <div className="rounded-xl border border-hairline bg-white p-4">
      <h3 className="text-sm font-extrabold text-ink">Your details</h3>
      <p className="mt-0.5 text-xs text-muted">No account needed — the driver will call you on this number.</p>
      <div className="mt-4 grid gap-4 sm:grid-cols-2">
        <div>
          <label className="label">Your name *</label>
          <div className="relative">
            <User2 className="pointer-events-none absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-muted" />
            <input
              className="field pl-9"
              placeholder="Full name"
              value={value.name}
              onChange={(e) => onChange({ ...value, name: e.target.value })}
            />
          </div>
        </div>
        <div>
          <label className="label">Mobile number *</label>
          <div className="relative">
            <Phone className="pointer-events-none absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-muted" />
            <input
              className="field pl-9"
              inputMode="numeric"
              maxLength={10}
              placeholder="10-digit mobile number"
              value={value.mobile}
              onChange={(e) => onChange({ ...value, mobile: e.target.value.replace(/\D/g, '') })}
            />
          </div>
        </div>
      </div>
    </div>
  );
}
