/**
 * One-time migration: turn booking alerts OFF for every existing user, so the
 * whole platform starts from a clean opt-in state (matches the new default).
 *
 * Reads MONGODB_URI / MONGODB_DB_NAME from backend/.env.
 *
 * Run from the backend folder:
 *   node scripts/disable-all-notifications.js            # dry run — only counts
 *   node scripts/disable-all-notifications.js --apply    # actually updates
 *
 * On the live server, upload this file (or `git pull`) and run it the same way
 * from inside the backend directory where .env lives.
 */
require('dotenv').config();
const mongoose = require('mongoose');

const APPLY = process.argv.includes('--apply');

async function main() {
  const uri = process.env.MONGODB_URI;
  const dbName = process.env.MONGODB_DB_NAME || 'goracabs';
  if (!uri) {
    console.error('❌ MONGODB_URI not set. Run this from the backend folder (where .env is).');
    process.exit(1);
  }

  await mongoose.connect(uri, { dbName });
  const users = mongoose.connection.collection('users');

  const total = await users.countDocuments({});
  const currentlyOn = await users.countDocuments({ notificationsEnabled: { $ne: false } });
  console.log(`Users total: ${total}`);
  console.log(`Currently receiving alerts (would be turned OFF): ${currentlyOn}`);

  if (!APPLY) {
    console.log('\nDRY RUN — nothing changed. Re-run with --apply to turn these OFF.');
    await mongoose.disconnect();
    return;
  }

  const res = await users.updateMany({}, { $set: { notificationsEnabled: false } });
  console.log(`\n✅ Applied. Matched ${res.matchedCount}, modified ${res.modifiedCount}.`);
  console.log('All users are now OFF — each can re-enable alerts from the app.');
  await mongoose.disconnect();
}

main().catch((e) => {
  console.error('Migration failed:', e.message);
  process.exit(1);
});
