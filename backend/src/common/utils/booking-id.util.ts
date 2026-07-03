export function generateBookingId(): string {
  const timestamp = Date.now().toString().slice(-6);
  const random = Math.floor(Math.random() * 100000).toString().padStart(5, '0');
  return `GC${timestamp}${random}`;
}

export function generateRequirementId(): string {
  const timestamp = Date.now().toString().slice(-5);
  const random = Math.floor(Math.random() * 1000).toString().padStart(3, '0');
  return `REQ${timestamp}${random}`;
}

export function generateVehicleListingId(): string {
  const timestamp = Date.now().toString().slice(-5);
  const random = Math.floor(Math.random() * 1000).toString().padStart(3, '0');
  return `VEH${timestamp}${random}`;
}

export function generatePaymentOrderId(): string {
  const timestamp = Date.now().toString().slice(-8);
  return `PAY${timestamp}`;
}

/** Short, human-friendly referral code, e.g. "GORA7K3QF". */
export function generateReferralCode(): string {
  const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // no ambiguous 0/O/1/I
  let code = '';
  for (let i = 0; i < 6; i++) {
    code += chars[Math.floor(Math.random() * chars.length)];
  }
  return `GORA${code}`;
}
