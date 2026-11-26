'use client';

import { useState } from 'react';
import { Phone, User2, ShieldCheck, Loader2 } from 'lucide-react';
import toast from 'react-hot-toast';
import { apiPost, errorMessage } from '@/lib/api';

export interface GuestInfo {
  name: string;
  mobile: string;
  /** Proof the number answered an OTP. Issued by `/auth/guest/verify-otp`,
   *  sent with the booking, and cleared the moment the number is edited. */
  verificationToken?: string;
}

/** True when the guest has given enough to place a booking. */
export function guestReady(g: GuestInfo): boolean {
  return (
    g.name.trim().length >= 2 &&
    /^[6-9]\d{9}$/.test(g.mobile.replace(/\D/g, '')) &&
    !!g.verificationToken
  );
}

const validMobile = (m: string) => /^[6-9]\d{9}$/.test(m.replace(/\D/g, ''));

/**
 * Name + mobile, collected at the point of booking for visitors who are not
 * signed in — and the number is verified by OTP before the booking is placed.
 *
 * The number is the only thing tying a booking to a person: the driver calls
 * it, the trip code goes to it, and the booking is filed against the account it
 * creates. Taken on trust, a typo meant a real customer never heard from us,
 * and a made-up number meant a driver was sent to somebody who never asked for
 * a cab. The same OTP the apps log in with answers both.
 */
export function GuestFields({
  value,
  onChange,
}: {
  value: GuestInfo;
  onChange: (g: GuestInfo) => void;
}) {
  const [sending, setSending] = useState(false);
  const [verifying, setVerifying] = useState(false);
  const [otpSent, setOtpSent] = useState(false);
  const [otp, setOtp] = useState('');

  const verified = !!value.verificationToken;

  /** Editing the number invalidates any proof we hold for the old one. */
  const setMobile = (raw: string) => {
    const mobile = raw.replace(/\D/g, '');
    if (mobile === value.mobile) return;
    setOtpSent(false);
    setOtp('');
    onChange({ ...value, mobile, verificationToken: undefined });
  };

  const sendOtp = async () => {
    if (!validMobile(value.mobile)) {
      toast.error('Enter a valid 10-digit mobile number');
      return;
    }
    setSending(true);
    try {
      await apiPost('/auth/guest/send-otp', { mobile: value.mobile });
      setOtpSent(true);
      toast.success(`OTP sent to ${value.mobile}`);
    } catch (e) {
      toast.error(errorMessage(e, 'Could not send the OTP. Please try again.'));
    } finally {
      setSending(false);
    }
  };

  const verify = async () => {
    if (otp.trim().length < 4) {
      toast.error('Enter the code from the SMS');
      return;
    }
    setVerifying(true);
    try {
      const res = await apiPost<{ verificationToken: string }>('/auth/guest/verify-otp', {
        mobile: value.mobile,
        otp: otp.trim(),
      });
      onChange({ ...value, verificationToken: res.verificationToken });
      setOtpSent(false);
      setOtp('');
      toast.success('Mobile number verified');
    } catch (e) {
      toast.error(errorMessage(e, 'That code did not match. Please try again.'));
    } finally {
      setVerifying(false);
    }
  };

  return (
    <div className="rounded-xl border border-hairline bg-surface p-4">
      <h3 className="text-sm font-extrabold text-ink">Your details</h3>
      <p className="mt-0.5 text-xs text-muted">
        No account needed — we text a code to confirm the number, then the driver calls you on it.
      </p>

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
          <div className="flex gap-2">
            <div className="relative flex-1">
              <Phone className="pointer-events-none absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-muted" />
              <input
                className="field pl-9"
                inputMode="numeric"
                maxLength={10}
                placeholder="10-digit mobile number"
                value={value.mobile}
                onChange={(e) => setMobile(e.target.value)}
                readOnly={verified}
              />
            </div>
            {verified ? (
              <span className="inline-flex shrink-0 items-center gap-1 rounded-lg bg-emerald-50 px-3 text-xs font-bold text-emerald-700">
                <ShieldCheck className="h-4 w-4" />
                Verified
              </span>
            ) : (
              <button
                type="button"
                onClick={sendOtp}
                disabled={sending || !validMobile(value.mobile)}
                className="btn-secondary shrink-0 px-4 text-xs disabled:opacity-50"
              >
                {sending ? <Loader2 className="h-4 w-4 animate-spin" /> : otpSent ? 'Resend' : 'Send OTP'}
              </button>
            )}
          </div>

          {verified && (
            <button
              type="button"
              onClick={() => onChange({ ...value, verificationToken: undefined })}
              className="mt-1 text-[11px] font-semibold text-muted underline"
            >
              Use a different number
            </button>
          )}
        </div>
      </div>

      {otpSent && !verified && (
        <div className="mt-4 rounded-lg border border-hairline bg-bg p-3">
          <label className="label">Enter the code sent to {value.mobile}</label>
          <div className="flex gap-2">
            <input
              className="field flex-1 tracking-[0.3em]"
              inputMode="numeric"
              maxLength={6}
              placeholder="● ● ● ● ● ●"
              value={otp}
              onChange={(e) => setOtp(e.target.value.replace(/\D/g, ''))}
              onKeyDown={(e) => {
                if (e.key === 'Enter') verify();
              }}
              autoFocus
            />
            <button
              type="button"
              onClick={verify}
              disabled={verifying || otp.length < 4}
              className="btn-primary shrink-0 px-5 text-sm disabled:opacity-50"
            >
              {verifying ? <Loader2 className="h-4 w-4 animate-spin" /> : 'Verify'}
            </button>
          </div>
          <p className="mt-2 text-[11px] text-muted">
            The code is valid for 5 minutes. Didn&apos;t get it? Tap Resend.
          </p>
        </div>
      )}
    </div>
  );
}
