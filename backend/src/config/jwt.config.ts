import { registerAs } from '@nestjs/config';

// Known weak/placeholder values that must never be used to sign tokens in prod.
const PLACEHOLDERS = new Set([
  'fallback-jwt-secret-change-in-production',
  'fallback-refresh-secret-change-in-production',
  'your-super-secure-jwt-secret-key-min-32-chars',
  'your-super-secret-jwt-key',
  'secret',
  'changeme',
]);

// In production, refuse to start with a missing/short/placeholder secret —
// otherwise JWTs would be forgeable (auth bypass). In dev, allow the fallback.
function requireSecret(value: string | undefined, fallback: string, name: string): string {
  const isProd = process.env.NODE_ENV === 'production';
  if (isProd && (!value || value.length < 32 || PLACEHOLDERS.has(value))) {
    throw new Error(`${name} is missing, too short, or a known placeholder. Set a strong random ${name} (32+ chars) before running in production.`);
  }
  return value || fallback;
}

export default registerAs('jwt', () => ({
  secret: requireSecret(process.env.JWT_SECRET, 'fallback-jwt-secret-change-in-production', 'JWT_SECRET'),
  expiresIn: process.env.JWT_EXPIRES_IN || '1h',
  refreshSecret: requireSecret(process.env.JWT_REFRESH_SECRET, 'fallback-refresh-secret-change-in-production', 'JWT_REFRESH_SECRET'),
  refreshExpiresIn: process.env.JWT_REFRESH_EXPIRES_IN || '30d',
}));
