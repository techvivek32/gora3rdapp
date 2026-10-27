'use client';

import { apiPost, errorMessage } from './api';

/**
 * Razorpay web checkout for a booking advance.
 *
 * Mirrors the mobile `cab_confirm_page` flow, including what proves a payment:
 * the server creates the order, and `/customer-bookings/guest/advance/verify`
 * checks Razorpay's HMAC. The browser never decides that a payment succeeded —
 * a `handler` callback can be forged, the signature cannot.
 *
 * The website has no sign-in, so the order is authorised by the pair the guest
 * already holds: their booking reference and the mobile they booked with.
 */

interface RazorpayOrder {
  orderId?: string;
  amount?: number;
  currency?: string;
  keyId?: string;
}

declare global {
  interface Window {
    Razorpay?: new (options: Record<string, unknown>) => { open: () => void; on: (e: string, cb: (r: unknown) => void) => void };
  }
}

const SCRIPT_SRC = 'https://checkout.razorpay.com/v1/checkout.js';

/** Loads checkout.js once; resolves false when it can't be fetched. */
export function loadRazorpay(): Promise<boolean> {
  if (typeof window === 'undefined') return Promise.resolve(false);
  if (window.Razorpay) return Promise.resolve(true);
  return new Promise((resolve) => {
    const existing = document.querySelector<HTMLScriptElement>(`script[src="${SCRIPT_SRC}"]`);
    if (existing) {
      existing.addEventListener('load', () => resolve(!!window.Razorpay));
      existing.addEventListener('error', () => resolve(false));
      return;
    }
    const s = document.createElement('script');
    s.src = SCRIPT_SRC;
    s.async = true;
    s.onload = () => resolve(!!window.Razorpay);
    s.onerror = () => resolve(false);
    document.body.appendChild(s);
  });
}

export interface AdvanceResult {
  ok: boolean;
  /** Why it failed, for a toast. Empty when the customer simply closed the sheet. */
  error?: string;
  dismissed?: boolean;
}

/**
 * Takes the advance for `bookingRef` at `percent` (10 or 100).
 *
 * Resolves `{ ok: true }` only after the server has verified the signature.
 */
export async function payBookingAdvance(
  bookingRef: string,
  mobile: string,
  percent: number,
  guestName: string,
): Promise<AdvanceResult> {
  const loaded = await loadRazorpay();
  if (!loaded) return { ok: false, error: 'Could not load the payment window. Check your connection.' };

  let order: RazorpayOrder;
  try {
    order = await apiPost<RazorpayOrder>('/customer-bookings/guest/advance/order', {
      bookingId: bookingRef,
      mobile,
      percent,
    });
  } catch (e) {
    return { ok: false, error: errorMessage(e, 'Could not start the payment') };
  }
  if (!order?.orderId || !order?.keyId) {
    return { ok: false, error: 'Payment could not start. Please try again.' };
  }

  return new Promise<AdvanceResult>((resolve) => {
    let settled = false;
    const finish = (r: AdvanceResult) => {
      if (!settled) {
        settled = true;
        resolve(r);
      }
    };

    const rzp = new window.Razorpay!({
      key: order.keyId,
      amount: order.amount,
      currency: order.currency ?? 'INR',
      order_id: order.orderId,
      name: 'Gora Cabs',
      description: `Booking advance (${percent}%)`,
      prefill: { name: guestName, contact: mobile },
      theme: { color: '#F97316' },
      modal: {
        // Closing the sheet is a cancel, not a failure — the caller cleans up
        // the pending booking the same way the app does.
        ondismiss: () => finish({ ok: false, dismissed: true }),
      },
      handler: async (response: Record<string, string>) => {
        try {
          await apiPost('/customer-bookings/guest/advance/verify', {
            razorpayOrderId: response.razorpay_order_id,
            razorpayPaymentId: response.razorpay_payment_id,
            razorpaySignature: response.razorpay_signature,
          });
          finish({ ok: true });
        } catch (e) {
          // The money may still have been captured — the Razorpay webhook
          // reconciles it server-side, so say so instead of claiming failure.
          finish({
            ok: false,
            error: errorMessage(e, 'Payment taken but confirmation is pending. Our team will call you.'),
          });
        }
      },
    });

    rzp.on('payment.failed', (resp: unknown) => {
      const desc = (resp as { error?: { description?: string } })?.error?.description;
      finish({ ok: false, error: desc || 'Payment failed. Please try again.' });
    });

    rzp.open();
  });
}
