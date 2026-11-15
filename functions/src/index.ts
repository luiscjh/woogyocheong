// 우교청 Cloud Functions (2nd gen) — 푸시 알림과 예약 작업.
// 배포 전제: Blaze 요금제. 리전 asia-northeast3(서울), 예약 작업 시간대 Asia/Seoul.
import { initializeApp } from "firebase-admin/app";
import { getFirestore, Timestamp } from "firebase-admin/firestore";
import { getMessaging, type BatchResponse, type Message } from "firebase-admin/messaging";
import { setGlobalOptions } from "firebase-functions/v2";
import { onDocumentCreated, onDocumentDeleted } from "firebase-functions/v2/firestore";
import { onSchedule } from "firebase-functions/v2/scheduler";
import {
  deleteUserTokens,
  handleNotificationCreated,
  handleVisitCreated,
  logResult,
  runAttendanceReminder,
  runDailyCleanup,
} from "./handlers";
import type { Messenger } from "./push";

const REGION = "asia-northeast3";
const TIME_ZONE = "Asia/Seoul";

setGlobalOptions({ region: REGION, maxInstances: 5 });
initializeApp();
const db = getFirestore();

// 로컬 에뮬레이터 테스트 전용 가짜 발송기: FUNCTIONS_EMULATOR=true 이고 FAKE_FCM=1일
// 때만 쓰이며, 실제 FCM 대신 _emulatorFcmLog 컬렉션에 기록한다. 'invalid-'로 시작하는
// 토큰은 "등록 해제된 토큰" 오류를 돌려줘 무효 토큰 정리를 시험할 수 있게 함.
// 배포 환경에는 FUNCTIONS_EMULATOR가 없으므로 항상 실제 getMessaging()을 쓴다
function emulatorFakeMessenger(): Messenger {
  return {
    async sendEach(messages: Message[]): Promise<BatchResponse> {
      const responses = await Promise.all(messages.map(async (m) => {
        const token = "token" in m ? m.token : "";
        await db.collection("_emulatorFcmLog").add({
          token,
          title: m.notification?.title ?? "",
          body: m.notification?.body ?? "",
          data: m.data ?? {},
          at: Timestamp.now(),
        });
        if (token.startsWith("invalid-")) {
          return {
            success: false,
            error: { code: "messaging/registration-token-not-registered", message: "fake" },
          } as BatchResponse["responses"][number];
        }
        return { success: true, messageId: `fake-${token}` } as BatchResponse["responses"][number];
      }));
      const successCount = responses.filter((r) => r.success).length;
      return { responses, successCount, failureCount: responses.length - successCount };
    },
  };
}

function messenger(): Messenger {
  if (process.env.FUNCTIONS_EMULATOR === "true" && process.env.FAKE_FCM === "1") {
    return emulatorFakeMessenger();
  }
  return getMessaging();
}

// #1 알림 문서가 생기면 그 사용자 기기로 푸시
export const pushOnNotificationCreated = onDocumentCreated("notifications/{notificationId}", async (event) => {
  const result = await handleNotificationCreated(db, messenger(), event.params.notificationId);
  if (result) logResult("pushOnNotificationCreated", { notificationId: event.params.notificationId, ...result });
});

// #2 심방 신청 → 목사님 알림 문서 생성(푸시는 #1이 보냄)
export const notifyPastorsOnVisitCreated = onDocumentCreated("visits/{visitId}", async (event) => {
  const created = await handleVisitCreated(db, event.params.visitId, event.data?.data());
  logResult("notifyPastorsOnVisitCreated", { visitId: event.params.visitId, created });
});

// 회원 문서 삭제 → 그 회원의 기기 토큰 전부 삭제
export const deleteTokensOnUserDeleted = onDocumentDeleted("users/{uid}", async (event) => {
  const removed = await deleteUserTokens(db, event.params.uid);
  if (removed > 0) logResult("deleteTokensOnUserDeleted", { removed });
});

// #3 매주 일요일 11:00 KST 출석 체크 알림
export const weeklyAttendanceReminder = onSchedule(
  { schedule: "0 11 * * 0", timeZone: TIME_ZONE, retryCount: 0 },
  async () => {
    logResult("weeklyAttendanceReminder", await runAttendanceReminder(db, messenger(), new Date()));
  },
);

// #4 매일 03:00 KST 정리
export const dailyCleanup = onSchedule(
  { schedule: "0 3 * * *", timeZone: TIME_ZONE, timeoutSeconds: 540 },
  async () => {
    logResult("dailyCleanup", await runDailyCleanup(db, new Date()));
  },
);
