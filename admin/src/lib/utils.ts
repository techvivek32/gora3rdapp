import { clsx, type ClassValue } from 'clsx';
import { twMerge } from 'tailwind-merge';
import { formatDistanceToNow, format } from 'date-fns';

export function cn(...inputs: ClassValue[]) {
  return twMerge(clsx(inputs));
}

export function formatDate(date: string | Date, fmt = 'dd MMM yyyy') {
  if (!date) return '-';
  return format(new Date(date), fmt);
}

export function getRelativeTime(date: string | Date) {
  if (!date) return '-';
  return formatDistanceToNow(new Date(date), { addSuffix: true });
}

export function formatCurrency(amount: number, currency = 'INR') {
  return new Intl.NumberFormat('en-IN', { style: 'currency', currency }).format(amount);
}

export function truncate(str: string, length = 50) {
  if (!str) return '';
  return str.length > length ? `${str.slice(0, length)}...` : str;
}

export const MEMBERSHIP_CONFIG = {
  new: { label: 'New', color: 'badge-new', icon: '👤' },
  active: { label: 'Active', color: 'badge-active', icon: '✓' },
  verified: { label: 'Verified', color: 'badge-verified', icon: '✓' },
  premium: { label: 'Premium', color: 'badge-premium', icon: '⭐' },
  golden: { label: 'Golden', color: 'badge-golden', icon: '👑' },
} as const;
