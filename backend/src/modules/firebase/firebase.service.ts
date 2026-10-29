import { Injectable, OnModuleInit, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import * as admin from 'firebase-admin';

/**
 * The errors that mean "this token is gone for good". Everything else — a
 * network blip, a quota error, an unavailable backend — is transient and must
 * NOT cost the user their registration.
 */
const DEAD_TOKEN_CODES = [
  'messaging/registration-token-not-registered',
  'messaging/invalid-registration-token',
  'messaging/invalid-argument',
];

@Injectable()
export class FirebaseService implements OnModuleInit {
  private readonly logger = new Logger(FirebaseService.name);
  private app: admin.app.App;

  constructor(private configService: ConfigService) {}

  onModuleInit() {
    try {
      if (!admin.apps.length) {
        const privateKey = this.configService.get('firebase.privateKey');
        const projectId = this.configService.get('firebase.projectId');
        const clientEmail = this.configService.get('firebase.clientEmail');

        if (!projectId || !privateKey || !clientEmail || privateKey.includes('dummy')) {
          this.logger.warn('Firebase credentials not configured — push notifications disabled');
          return;
        }

        this.app = admin.initializeApp({
          credential: admin.credential.cert({ projectId, privateKey, clientEmail }),
        });
        this.logger.log('Firebase Admin initialized');
      } else {
        this.app = admin.apps[0];
      }
    } catch (error) {
      this.logger.warn(`Firebase Admin init failed: ${error.message} — push notifications disabled`);
    }
  }

  async verifyIdToken(idToken: string): Promise<admin.auth.DecodedIdToken | null> {
    try {
      return await admin.auth().verifyIdToken(idToken);
    } catch (error) {
      this.logger.error('Firebase token verification failed:', error.message);
      return null;
    }
  }

  async sendPushNotification(tokens: string[], notification: {
    title: string;
    body: string;
    data?: Record<string, string>;
    imageUrl?: string;
    channelId?: string;
  }): Promise<admin.messaging.BatchResponse> {
    if (!tokens || tokens.length === 0) {
      return { successCount: 0, failureCount: 0, responses: [] };
    }

    const message: admin.messaging.MulticastMessage = {
      tokens: tokens.filter(Boolean),
      notification: {
        title: notification.title,
        body: notification.body,
        imageUrl: notification.imageUrl,
      },
      data: notification.data || {},
      android: {
        priority: 'high',
        notification: {
          // Default to the normal "updates" channel (plays a sound) — admin
          // broadcasts, wallet, chat, trip updates, etc. Only the new-booking push
          // passes the SILENT v4 channel (the app plays the chosen ring itself).
          channelId: notification.channelId || 'gora_cabs_updates',
          priority: 'high',
        },
      },
      apns: {
        payload: {
          aps: {
            alert: { title: notification.title, body: notification.body },
            sound: 'default',
            badge: 1,
          },
        },
      },
    };

    try {
      const res = await admin.messaging().sendEachForMulticast(message);
      this.reportDeadTokens(message.tokens, res);
      return res;
    } catch (error) {
      this.logger.error('FCM send failed:', error.message);
      throw error;
    }
  }

  /**
   * Hand back the tokens FCM has just rejected as no longer registered.
   *
   * Nothing used to read the send result, so a token stayed on the account
   * forever once the app that owned it was gone. That is how accounts built up
   * a dozen tokens each — and why a phone whose old token was still live got
   * every notification twice. Whoever registered the callback prunes them.
   */
  private reportDeadTokens(tokens: string[], res: admin.messaging.BatchResponse) {
    if (!FirebaseService.onDeadTokens || res.failureCount === 0) return;
    const dead = res.responses
      .map((r, i) => (r.success ? null : { code: r.error?.code, token: tokens[i] }))
      .filter((x): x is { code: string; token: string } =>
        !!x && DEAD_TOKEN_CODES.includes(x.code as string));
    if (dead.length === 0) return;
    this.logger.log(`FCM: dropping ${dead.length} dead token(s)`);
    // Fire-and-forget: a failed cleanup must never fail the notification.
    Promise.resolve(FirebaseService.onDeadTokens(dead.map((d) => d.token))).catch((e) =>
      this.logger.error(`Dead-token cleanup failed: ${e?.message}`),
    );
  }

  /**
   * Set once at boot by the notifications module. Kept as a hook rather than an
   * injected service so firebase stays free of a dependency on users.
   */
  static onDeadTokens: ((tokens: string[]) => unknown) | null = null;

  async sendTopicNotification(topic: string, notification: {
    title: string;
    body: string;
    data?: Record<string, string>;
  }): Promise<string> {
    const message: admin.messaging.Message = {
      topic,
      notification: { title: notification.title, body: notification.body },
      data: notification.data || {},
    };

    return admin.messaging().send(message);
  }

  async subscribeToTopic(tokens: string[], topic: string) {
    return admin.messaging().subscribeToTopic(tokens, topic);
  }

  async unsubscribeFromTopic(tokens: string[], topic: string) {
    return admin.messaging().unsubscribeFromTopic(tokens, topic);
  }
}
