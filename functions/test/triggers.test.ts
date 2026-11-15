// 함수 에뮬레이터 통합 테스트: 실제 배포될 트리거(lib/src/index.js)가 Firestore 이벤트로
// 실행되는지 확인. FAKE_FCM=1로 띄워 실제 FCM 대신 _emulatorFcmLog에 기록됨
import { after, beforeEach, test } from "node:test";
import assert from "node:assert/strict";
import { initializeApp, deleteApp } from "firebase-admin/app";
import { getFirestore, Timestamp } from "firebase-admin/firestore";
import { clearFirestore, PROJECT_ID } from "./helpers";

const app = initializeApp({ projectId: PROJECT_ID }, "triggers-test");
const db = getFirestore(app);

async function waitFor<T>(what: string, fn: () => Promise<T | null>, ms = 20000): Promise<T> {
  const until = Date.now() + ms;
  while (Date.now() < until) {
    const v = await fn();
    if (v !== null) return v;
    await new Promise((r) => setTimeout(r, 250));
  }
  throw new Error(`시간 초과: ${what}`);
}
async function fcmLog() {
  return (await db.collection("_emulatorFcmLog").get()).docs.map((d) => d.data());
}

after(async () => { await deleteApp(app); });
beforeEach(async () => { await clearFirestore(); });

test("심방 신청 → 목사님 알림 문서 → 목사님 기기 푸시 1회, 무효 토큰 삭제", async () => {
  const tok = (uid: string, t: string) =>
    db.collection("users").doc(uid).collection("fcmTokens").doc(t).set({ token: t, platform: "android", updatedAt: Timestamp.now() });
  await db.collection("users").doc("p1").set({ name: "최목사", role: "pastor", department: "A-1" });
  await db.collection("users").doc("m1").set({ name: "이청년", role: "member", department: "A-1" });
  await tok("p1", "pastor-good");
  await tok("p1", "invalid-pastor-old");
  await tok("m1", "member-token");

  await db.collection("visits").doc("v1").set({
    userId: "m1", userName: "이청년", phone: "010-0000-0000", reason: "상담", status: "pending", requestDate: Timestamp.now(),
  });

  const n = await waitFor("목사님 알림 문서", async () => {
    const s = await db.collection("notifications").doc("visitRequest_v1_p1").get();
    return s.exists && s.data()?.pushedAt ? s.data()! : null;
  });
  assert.equal(n.userId, "p1");
  assert.equal(n.body, "이청년님이 심방을 신청했습니다.");

  const log = await waitFor("발송 기록 2건", async () => { const l = await fcmLog(); return l.length >= 2 ? l : null; });
  await waitFor("무효 토큰 삭제", async () =>
    (await db.collection("users").doc("p1").collection("fcmTokens").doc("invalid-pastor-old").get()).exists ? null : true);
  await new Promise((r) => setTimeout(r, 2000)); // 추가(중복) 발송이 없는지 잠시 더 관찰
  const finalLog = await fcmLog();
  assert.equal(finalLog.length, 2, "목사님 토큰 2개에 각 1회만");
  assert.deepEqual(finalLog.map((l) => l.token).sort(), ["invalid-pastor-old", "pastor-good"]);
  assert.ok(log.every((l) => !JSON.stringify(l).includes("010-0000-0000")), "연락처 미포함");
  assert.equal((await db.collection("users").doc("p1").collection("fcmTokens").doc("pastor-good").get()).exists, true);
  assert.equal((await db.collection("notifications").where("userId", "==", "m1").get()).size, 0, "신청자에게는 알림 없음");
});

test("앱이 만드는 알림 문서(add) → 해당 사용자 푸시", async () => {
  await db.collection("users").doc("u1").set({ name: "A", role: "member", department: "A-1" });
  await db.collection("users").doc("u1").collection("fcmTokens").doc("u1-token").set({ token: "u1-token", platform: "ios", updatedAt: Timestamp.now() });
  await db.collection("notifications").add({
    userId: "u1", title: "심방 신청 상태 변경", body: "심방 신청이 '확정' 상태로 변경되었습니다.", type: "visit", createdAt: Timestamp.now(), isRead: false,
  });
  const log = await waitFor("발송 기록", async () => { const l = await fcmLog(); return l.length >= 1 ? l : null; });
  assert.equal(log[0].token, "u1-token");
  assert.equal(log[0].title, "심방 신청 상태 변경");
  assert.equal(log[0].data.type, "visit");
});

test("회원 문서 삭제 → 기기 토큰 삭제", async () => {
  await db.collection("users").doc("gone").set({ name: "G", role: "member", department: "A-1" });
  await db.collection("users").doc("gone").collection("fcmTokens").doc("g1").set({ token: "g1", platform: "android", updatedAt: Timestamp.now() });
  await db.collection("users").doc("gone").delete();
  await waitFor("토큰 삭제", async () =>
    (await db.collection("users").doc("gone").collection("fcmTokens").get()).empty ? true : null);
});
