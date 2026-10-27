import axios, { AxiosError } from 'axios';

/**
 * API host. Defaults to production so a build with no env still talks to the
 * real backend — the mobile app learned this the hard way (a release pointed at
 * localhost fails silently, nothing breaks at compile time).
 */
export const API_BASE =
  process.env.NEXT_PUBLIC_API_URL?.replace(/\/$/, '') || 'https://backend.goracabs.com/api/v1';

/**
 * The website has NO sign-in: a visitor books with a name and a mobile number
 * and nothing else. So there are no tokens to attach, nothing to refresh, and —
 * importantly — nowhere to redirect a 401 to.
 *
 * An earlier version did redirect on 401, which is how a signed-out visitor
 * landed on a login page just by opening the home page: one guarded endpoint
 * 401s and the whole site bounces. A failed request now simply fails, and the
 * page that asked for it decides what to show.
 */
export const http = axios.create({
  baseURL: API_BASE,
  timeout: 30000,
  headers: { 'Content-Type': 'application/json' },
});

/** The backend wraps everything as `{ message, data }`; callers want `data`. */
export function unwrap<T>(res: { data?: { data?: T } | T }): T {
  const body = res.data as { data?: T } | undefined;
  return (body && typeof body === 'object' && 'data' in body ? (body.data as T) : (body as unknown as T));
}

/** The server's one-sentence reason, never a raw axios dump. */
export function errorMessage(e: unknown, fallback = 'Something went wrong'): string {
  const err = e as AxiosError<{ message?: string | string[] }>;
  const m = err?.response?.data?.message;
  if (Array.isArray(m) && m.length) return String(m[0]);
  if (typeof m === 'string' && m.trim()) return m;
  if (err?.message === 'Network Error') return 'Could not reach the server. Check your connection.';
  return fallback;
}

export async function apiGet<T>(url: string, params?: Record<string, unknown>): Promise<T> {
  return unwrap<T>(await http.get(url, { params }));
}
export async function apiPost<T>(url: string, data?: unknown): Promise<T> {
  return unwrap<T>(await http.post(url, data));
}
