import { Injectable, OnModuleInit, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import * as admin from 'firebase-admin';

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
          channelId: 'gora_cabs_notifications',
          priority: 'high',
          sound: 'default',
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
      return await admin.messaging().sendEachForMulticast(message);
    } catch (error) {
      this.logger.error('FCM send failed:', error.message);
      throw error;
    }
  }

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
