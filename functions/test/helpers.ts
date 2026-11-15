import type { BatchResponse, Message } from "firebase-admin/messaging";
import type { Messenger } from "../src/push";

export const PROJECT_ID = process.env.GCLOUD_PROJECT ?? "demo-woogyocheong";

export function emulatorHost(): string {
  const host = process.env.FIRESTORE_EMULATOR_HOST;
  if (!host) throw new Error("FIRESTORE_EMULATOR_HOST가 없음 — firebase emulators:exec로 실행하세요");
  return host;
}

export async function clearFirestore(): Promise<void> {
  const res = await fetch(
    `http://${emulatorHost()}/emulator/v1/projects/${PROJECT_ID}/databases/(default)/documents`,
    { method: "DELETE" },
  );
  if (!res.ok) throw new Error(`에뮬레이터 초기화 실패: ${res.status}`);
}

// 실제 FCM을 부르지 않는 가짜 발송기. 'invalid-' 토큰 → 등록 해제 오류,
// 'transient-' 토큰 → 일시 오류(토큰을 지우면 안 됨)
export class FakeMessenger implements Messenger {
  sent: Message[] = [];
  async sendEach(messages: Message[]): Promise<BatchResponse> {
    this.sent.push(...messages);
    const responses = messages.map((m) => {
      const token = "token" in m ? m.token : "";
      if (token.startsWith("invalid-")) {
        return { success: false, error: { code: "messaging/registration-token-not-registered" } };
      }
      if (token.startsWith("transient-")) {
        return { success: false, error: { code: "messaging/internal-error" } };
      }
      return { success: true, messageId: `m-${token}` };
    }) as BatchResponse["responses"];
    const successCount = responses.filter((r) => r.success).length;
    return { responses, successCount, failureCount: responses.length - successCount };
  }
  tokens(): string[] {
    return this.sent.map((m) => ("token" in m ? m.token : "")).sort();
  }
}
