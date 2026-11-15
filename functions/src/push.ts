import type { Firestore } from "firebase-admin/firestore";
import type { BatchResponse, Message } from "firebase-admin/messaging";
import * as logger from "firebase-functions/logger";

// FCM 발송 인터페이스 — 실제로는 getMessaging(), 테스트에서는 가짜 구현을 넣는다
export interface Messenger {
  sendEach(messages: Message[]): Promise<BatchResponse>;
}

export interface PushContent {
  title: string;
  body: string;
  // 앱이 알림을 눌렀을 때 구분용(민감정보 넣지 말 것)
  data?: Record<string, string>;
}

export interface TokenTarget {
  uid: string;
  token: string;
}

export interface SendResult {
  sent: number;
  failed: number;
  removedTokens: number;
}

// FCM이 "이 토큰은 더 이상 쓸 수 없다"고 알려 주는 오류 — 이 경우에만 토큰 문서를
// 지운다(일시적 오류·할당량 초과 등은 지우지 않음)
const INVALID_TOKEN_CODES = new Set([
  "messaging/registration-token-not-registered",
  "messaging/invalid-registration-token",
]);

export function isInvalidTokenError(code: string | undefined): boolean {
  return code !== undefined && INVALID_TOKEN_CODES.has(code);
}

// sendEach 한 번에 보낼 수 있는 최대 메시지 수
const FCM_BATCH = 500;

export function buildMessage(token: string, content: PushContent): Message {
  return {
    token,
    notification: { title: content.title, body: content.body },
    data: content.data ?? {},
    android: { priority: "high", notification: { sound: "default" } },
    apns: { payload: { aps: { sound: "default" } } },
  };
}

export async function getUserTokens(db: Firestore, uid: string): Promise<TokenTarget[]> {
  const snap = await db.collection("users").doc(uid).collection("fcmTokens").get();
  return snap.docs.map((d) => ({ uid, token: d.id }));
}

// 여러 토큰에 같은 내용을 보내고, FCM이 무효라고 한 토큰 문서는 삭제
export async function sendToTokens(
  db: Firestore,
  messenger: Messenger,
  targets: TokenTarget[],
  content: PushContent,
): Promise<SendResult> {
  const result: SendResult = { sent: 0, failed: 0, removedTokens: 0 };
  for (let i = 0; i < targets.length; i += FCM_BATCH) {
    const chunk = targets.slice(i, i + FCM_BATCH);
    const res = await messenger.sendEach(chunk.map((t) => buildMessage(t.token, content)));
    const invalid: TokenTarget[] = [];
    res.responses.forEach((r, idx) => {
      if (r.success) {
        result.sent++;
        return;
      }
      result.failed++;
      const code = r.error?.code;
      if (isInvalidTokenError(code)) invalid.push(chunk[idx]);
      else logger.warn("FCM 발송 실패", { code, uid: chunk[idx].uid });
    });
    if (invalid.length > 0) {
      const batch = db.batch();
      for (const t of invalid) {
        batch.delete(db.collection("users").doc(t.uid).collection("fcmTokens").doc(t.token));
      }
      await batch.commit();
      result.removedTokens += invalid.length;
    }
  }
  return result;
}
