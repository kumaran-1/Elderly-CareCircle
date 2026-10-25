import { cert, getApps, initializeApp } from "firebase-admin/app";
import { getMessaging } from "firebase-admin/messaging";

export interface PushMessage {
  token: string;
  title: string;
  body: string;
  data?: Record<string, string>;
}

export class FcmGateway {
  private enabled: boolean;

  constructor(serviceAccountJson?: string) {
    this.enabled = Boolean(serviceAccountJson);
    if (!this.enabled || getApps().length > 0) {
      return;
    }

    try {
      const serviceAccount = JSON.parse(serviceAccountJson!);
      initializeApp({ credential: cert(serviceAccount) });
    } catch {
      this.enabled = false;
    }
  }

  async send(message: PushMessage): Promise<boolean> {
    if (!this.enabled) {
      return false;
    }

    await getMessaging().send({
      token: message.token,
      notification: {
        title: message.title,
        body: message.body
      },
      data: message.data
    });
    return true;
  }
}
