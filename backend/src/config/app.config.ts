import { registerAs } from '@nestjs/config';

export default registerAs('app', () => ({
  name: process.env.APP_NAME || 'Gora Cabs API',
  port: parseInt(process.env.PORT || '7001', 10),
  nodeEnv: process.env.NODE_ENV || 'development',
  apiPrefix: process.env.API_PREFIX || 'api/v1',
  frontendUrl: process.env.FRONTEND_URL || 'http://localhost:7001',
  adminUrl: process.env.ADMIN_URL || 'http://localhost:7000',
  corsOrigins: process.env.CORS_ORIGINS || 'http://localhost:7000,http://localhost:7001',
  encryptionKey: process.env.ENCRYPTION_KEY || 'fallback-key-32-chars-minimum!!',
  throttle: {
    // THROTTLE_TTL stays in SECONDS because that is how every .env already reads,
    // but @nestjs/throttler v5 takes milliseconds. Without this conversion the
    // window was 60ms, i.e. a cap of ~1,666 req/sec — the limiter was inert, and
    // a scraper pulled 569,000 requests through it in a fortnight without a
    // single 429. Keep the *1000.
    ttl: parseInt(process.env.THROTTLE_TTL || '60', 10) * 1000,
    // Raised from 100 at the same time as the ttl fix, and the two go together:
    // while the window was 60ms the cap was unreachable, so nobody ever found
    // out that 100/min is too low. A real admin session was measured at 293
    // requests in a single minute. This is the backstop that keeps a runaway
    // client honest — the limits that actually defend a resource are the narrow
    // per-route ones below.
    limit: parseInt(process.env.THROTTLE_LIMIT || '600', 10),
    // A second, hour-long window. The burst cap above never troubled the
    // scraper — it ran at ~30 req/min, deliberately underneath it, for weeks.
    // What separates a bot from a person is not the burst, it is that the bot
    // never stops.
    //
    // Every number below was measured against a day of production traffic
    // rather than picked by taste. Busiest real hour, all endpoints: an admin
    // session at 1,412 — so 5,000 leaves about 3.5x headroom.
    sustainedTtl: parseInt(process.env.SUSTAINED_THROTTLE_TTL || '3600', 10) * 1000,
    sustainedLimit: parseInt(process.env.SUSTAINED_THROTTLE_LIMIT || '5000', 10),
    // The feed is what a lead scraper is actually after, so it gets a ceiling of
    // its own. Busiest real account: 29 feed pulls in an hour. The bot: 1,650.
    // 300 gives genuine use ~10x room and still cuts a harvester to a fifth of
    // the rate it had been running at for weeks.
    feedLimit: parseInt(process.env.FEED_THROTTLE_LIMIT || '300', 10),
    // Profile cards are the other half of a lead: the number behind the booking.
    // Gating the field (users.service) stops a free account reading it at all;
    // this stops a PAID one from walking the whole user base. Busiest real
    // account: 16 cards in an hour.
    cardLimit: parseInt(process.env.CARD_THROTTLE_LIMIT || '200', 10),
  },
  upload: {
    maxFileSize: parseInt(process.env.MAX_FILE_SIZE || '10485760', 10),
    allowedMimeTypes: (process.env.ALLOWED_MIME_TYPES || 'image/jpeg,image/png,image/webp').split(','),
  },
}));
