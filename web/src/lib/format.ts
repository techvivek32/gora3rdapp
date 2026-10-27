/** Shared formatting, matching how the mobile app renders the same values. */

/** "₹12,345" — Indian digit grouping, no decimals (fares are whole rupees). */
export function rupees(n: number | undefined | null): string {
  const v = Math.round(Number(n ?? 0));
  return `₹${v.toLocaleString('en-IN')}`;
}

const MONTHS = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

/** "19 Oct 2026" from an ISO date or yyyy-MM-dd. */
export function formatDate(value?: string | null): string {
  if (!value) return '';
  const d = new Date(value);
  if (Number.isNaN(d.getTime())) return String(value);
  return `${d.getDate()} ${MONTHS[d.getMonth()]} ${d.getFullYear()}`;
}

/** "19 Oct" — the short form used on cards. */
export function formatDayMonth(value?: string | null): string {
  if (!value) return '';
  const d = new Date(value);
  if (Number.isNaN(d.getTime())) return String(value);
  return `${d.getDate()} ${MONTHS[d.getMonth()]}`;
}

/** "14:30" -> "02:30 pm". Returns '' when the input isn't a time. */
export function formatTime12(value?: string | null): string {
  const parts = String(value ?? '').split(':');
  if (parts.length < 2) return '';
  const h = parseInt(parts[0], 10);
  if (Number.isNaN(h)) return '';
  const mm = parts[1].padStart(2, '0');
  const ampm = h >= 12 ? 'pm' : 'am';
  const h12 = h % 12 === 0 ? 12 : h % 12;
  return `${String(h12).padStart(2, '0')}:${mm} ${ampm}`;
}

/** yyyy-MM-dd for an <input type="date"> value. */
export function toDateInput(d: Date): string {
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;
}

/** The short city label used on route rows ("Rajkot, Gujarat, India" -> "Rajkot"). */
export function shortCity(value?: string | null): string {
  const s = String(value ?? '').trim();
  return s ? s.split(',')[0].trim() : '';
}

/** Title-cases an enum-ish value: "round_trip" -> "Round Trip". */
export function titleCase(value?: string | null): string {
  return String(value ?? '')
    .replace(/_/g, ' ')
    .split(' ')
    .filter(Boolean)
    .map((w) => w[0].toUpperCase() + w.slice(1))
    .join(' ');
}

/** Colour + label for a booking status chip. */
export function statusChip(status?: string): { label: string; className: string } {
  const s = String(status ?? '').toLowerCase();
  if (s === 'open') return { label: 'Open', className: 'bg-emerald-50 text-emerald-700 ring-emerald-200' };
  if (s === 'confirmed') return { label: 'Confirmed', className: 'bg-blue-50 text-blue-700 ring-blue-200' };
  if (s === 'ongoing') return { label: 'Ongoing', className: 'bg-amber-50 text-amber-700 ring-amber-200' };
  if (s === 'completed') return { label: 'Completed', className: 'bg-emerald-50 text-emerald-700 ring-emerald-200' };
  if (s === 'cancelled') return { label: 'Cancelled', className: 'bg-rose-50 text-rose-700 ring-rose-200' };
  return { label: titleCase(status) || 'Booking', className: 'bg-gray-100 text-gray-700 ring-gray-200' };
}

export const SERVICE_LABELS: Record<string, string> = {
  cab: 'Cab Booking',
  hire_driver: 'Hire a Driver',
  luxury: 'Luxury Car',
  car_pool: 'Car Pooling',
};
