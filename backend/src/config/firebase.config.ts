import { registerAs } from '@nestjs/config';
import { normalizeFirebasePrivateKey } from './firebase-key.util';

export default registerAs('firebase', () => ({
  projectId: process.env.FIREBASE_PROJECT_ID,
  privateKeyId: process.env.FIREBASE_PRIVATE_KEY_ID,
  // Accepts the key however `.env` mangled it (escaped / flattened / spaced) —
  // see normalizeFirebasePrivateKey. The bare `.replace(/\\n/g, '\n')` this
  // used to do fixed only one of those shapes; the other two left Firebase
  // unable to parse the PEM, which silently disabled ALL push notifications.
  privateKey: normalizeFirebasePrivateKey(process.env.FIREBASE_PRIVATE_KEY),
  clientEmail: process.env.FIREBASE_CLIENT_EMAIL,
  clientId: process.env.FIREBASE_CLIENT_ID,
  authUri: process.env.FIREBASE_AUTH_URI,
  tokenUri: process.env.FIREBASE_TOKEN_URI,
  storageBucket: process.env.FIREBASE_STORAGE_BUCKET,
}));
