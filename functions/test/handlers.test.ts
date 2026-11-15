// Firestore 에뮬레이터에서 실행(firebase emulators:exec). FCM은 FakeMessenger로 대체
import { after, beforeEach, describe, test } from "node:test";
import assert from "node:assert/strict";
import { initializeApp, deleteApp } from "firebase-admin/app";
import { getFirestore, Timestamp } from "firebase-admin/firestore";
import {
  deleteUserTokens,
  handleNotificationCreated,
  handleVisitCreated,
  runAttendanceReminder,
  runDailyCleanup,
  ATTENDANCE_REMINDER,
} from "../src/handlers";
import { clearFirestore, FakeMessenger, PROJECT_ID } from "./helpers";

const app = initializeApp({ projectId: PROJECT_ID }, "handlers-test");
const db = getFirestore(app);
const DAY = 24 * 60 * 60 * 1000;

async function addUser(uid: string, data: Record<string, unknown>, tokens: string[] = [], tokenAgeDays = 0, now = new Date()) {
  await db.collection("users").doc(uid).set({ name: uid, email: `${uid}@x.com`, role: "member", department: "A-1", cohort: 27, ...data });
  for (const t of tokens) {
    await db.collection("users").doc(uid).collection("fcmTokens").doc(t).set({
      token: t, platform: "android", updatedAt: Timestamp.fromMillis(now.getTime() - tokenAgeDays * DAY),
    });
  }
}
async function tokenIds(uid: string): Promise<string[]> {
  return (await db.collection("users").doc(uid).collection("fcmTokens").get()).docs.map((d) => d.id).sort();
}

after(async () => { await deleteApp(app); });
beforeEach(async () => { await clearFirestore(); });

describe("#1 알림 문서 → 푸시", () => {
  test("사용자 모든 토큰으로 발송, 무효 토큰만 삭제, 중복 전달 시 재발송 안 함", async () => {
    await addUser("u1", {}, ["good-a", "invalid-b", "transient-c"]);
    await addUser("u2", {}, ["other-user-token"]);
    await db.collection("notifications").doc("n1").set({
      userId: "u1", title: "소속팀 변경", body: "소속팀이 A-2(으)로 변경되었습니다.", type: "teamAssignment",
      createdAt: Timestamp.now(), isRead: false,
    });
    const fcm = new FakeMessenger();
    const r = await handleNotificationCreated(db, fcm, "n1");
    assert.deepEqual(r, { sent: 1, failed: 2, removedTokens: 1 });
    assert.deepEqual(fcm.tokens(), ["good-a", "invalid-b", "transient-c"], "다른 사용자 토큰으로는 안 보냄");
    const m = fcm.sent[0];
    assert.equal(m.notification?.title, "소속팀 변경");
    assert.equal(m.notification?.body, "소속팀이 A-2(으)로 변경되었습니다.");
    assert.deepEqual(m.data, { type: "teamAssignment", notificationId: "n1" });
    assert.deepEqual(await tokenIds("u1"), ["good-a", "transient-c"], "등록 해제 토큰만 삭제, 일시 오류 토큰은 유지");
    assert.ok((await db.collection("notifications").doc("n1").get()).data()?.pushedAt, "pushedAt 기록");

    const again = await handleNotificationCreated(db, fcm, "n1");
    assert.equal(again, null);
    assert.equal(fcm.sent.length, 3, "같은 이벤트 재전달 시 추가 발송 없음");
  });

  test("토큰 없는 사용자는 발송 0건, 없는 문서는 무시", async () => {
    await addUser("u1", {});
    await db.collection("notifications").doc("n1").set({ userId: "u1", title: "t", body: "b", type: "visit", createdAt: Timestamp.now(), isRead: false });
    const fcm = new FakeMessenger();
    assert.deepEqual(await handleNotificationCreated(db, fcm, "n1"), { sent: 0, failed: 0, removedTokens: 0 });
    assert.equal(await handleNotificationCreated(db, fcm, "missing"), null);
    assert.equal(fcm.sent.length, 0);
  });
});

describe("#2 심방 신청 → 목사님 알림", () => {
  test("목사님마다 알림 문서 1개(이름만, 연락처·사유 없음), 재전달 시 중복 없음, 푸시는 목사님당 1회", async () => {
    await addUser("p1", { role: "pastor", name: "최목사" }, ["p1-token"]);
    await addUser("p2", { role: "pastor", name: "김목사" }, ["p2-token"]);
    await addUser("m1", { name: "이청년" }, ["m1-token"]);
    await addUser("admin1", { role: "admin" }, ["admin-token"]);
    const visit = {
      userId: "m1", userName: "가짜이름<script>", phone: "010-1234-5678", reason: "개인 사정 상담",
      deptName: "A", team: "A-1", requestDate: Timestamp.now(), preferredDate: null, status: "pending", adminNote: null,
    };
    assert.equal(await handleVisitCreated(db, "v1", visit), 2);
    assert.equal(await handleVisitCreated(db, "v1", visit), 0, "트리거 재전달 시 새 문서 없음");

    const notifs = await db.collection("notifications").get();
    assert.equal(notifs.size, 2);
    for (const d of notifs.docs) {
      const n = d.data();
      assert.match(d.id, /^visitRequest_v1_p[12]$/);
      assert.ok(["p1", "p2"].includes(n.userId));
      assert.equal(n.type, "visitRequest");
      assert.equal(n.isRead, false);
      assert.equal(n.body, "이청년님이 심방을 신청했습니다.", "이름은 users 문서에서(신청 문서의 userName 아님)");
      assert.ok(!JSON.stringify(n).includes("010-1234-5678") && !JSON.stringify(n).includes("상담"), "연락처·사유 미포함");
    }

    // 생성된 알림 문서가 #1을 트리거했을 때의 발송 확인
    const fcm = new FakeMessenger();
    for (const d of notifs.docs) await handleNotificationCreated(db, fcm, d.id);
    for (const d of notifs.docs) await handleNotificationCreated(db, fcm, d.id); // 재전달
    assert.deepEqual(fcm.tokens(), ["p1-token", "p2-token"], "목사님 기기에만 각 1회");
  });

  test("이름이 없거나 긴 경우", async () => {
    await addUser("p1", { role: "pastor" });
    await addUser("m1", { name: "가".repeat(30) });
    await handleVisitCreated(db, "v1", { userId: "m1" });
    await handleVisitCreated(db, "v2", { userId: "ghost" });
    assert.equal((await db.collection("notifications").doc("visitRequest_v1_p1").get()).data()?.body,
      `${"가".repeat(20)}…님이 심방을 신청했습니다.`);
    assert.equal((await db.collection("notifications").doc("visitRequest_v2_p1").get()).data()?.body,
      "새 심방 신청이 있습니다.");
  });
});

describe("#3 주일 출석 알림", () => {
  const sunday11 = new Date("2026-11-15T02:00:00Z"); // 2026-11-15(일) 11:00 KST

  test("오늘 출석 기록이 없는 대상자에게만 발송", async () => {
    await addUser("checked", {}, ["t-checked"]);
    await addUser("markedAbsent", {}, ["t-absent"]);
    await addUser("notChecked", { role: "small_leader" }, ["t-not1", "invalid-old"]);
    await addUser("notChecked2", { department: "새가족팀", cohort: null }, ["t-not2"]);
    await addUser("noToken", {});
    await addUser("yesterdayOnly", {}, ["t-yesterday"]);
    await addUser("pastor", { role: "pastor" }, ["t-pastor"]);
    await addUser("onboarding", { department: "" }, ["t-onboarding"]);
    await addUser("tester", { email: "testing@church.com" }, ["t-tester"]);
    await addUser("restricted", { cohort: 15 }, ["t-restricted"]);
    const att = (uid: string, key: string, isPresent: boolean) =>
      db.collection("attendance").doc(`${uid}_${key}`).set({ userId: uid, userName: uid, date: Timestamp.fromDate(sunday11), isPresent, note: null });
    await att("checked", "2026-11-15", true);
    await att("markedAbsent", "2026-11-15", false);
    await att("yesterdayOnly", "2026-11-14", true);

    const fcm = new FakeMessenger();
    const r = await runAttendanceReminder(db, fcm, sunday11);
    assert.equal(r.dateKey, "2026-11-15");
    assert.equal(r.skipped, undefined);
    assert.equal(r.eligible, 6);
    assert.equal(r.alreadyChecked, 2);
    assert.equal(r.withoutToken, 1);
    assert.equal(r.usersNotified, 3);
    assert.deepEqual(fcm.tokens(), ["invalid-old", "t-not1", "t-not2", "t-yesterday"]);
    assert.deepEqual(r.send, { sent: 3, failed: 1, removedTokens: 1 });
    assert.deepEqual(await tokenIds("notChecked"), ["t-not1"]);
    assert.equal(fcm.sent[0].notification?.title, ATTENDANCE_REMINDER.title);
    assert.deepEqual(fcm.sent[0].data, { type: "attendanceReminder" });
    assert.equal(await db.collection("notifications").count().get().then((s) => s.data().count), 0, "알림함 문서는 만들지 않음");

    const again = await runAttendanceReminder(db, fcm, new Date("2026-11-15T02:05:00Z"));
    assert.equal(again.skipped, "already-ran");
    assert.equal(fcm.sent.length, 4, "같은 날 재실행 시 추가 발송 없음");
  });

  test("KST 기준 날짜: UTC 토요일 15:30 = KST 일요일 00:30", async () => {
    await addUser("a", {}, ["t-a"]);
    await db.collection("attendance").doc("a_2026-11-15").set({ userId: "a", isPresent: true });
    const fcm = new FakeMessenger();
    const r = await runAttendanceReminder(db, fcm, new Date("2026-11-14T15:30:00Z"));
    assert.equal(r.dateKey, "2026-11-15");
    assert.equal(r.alreadyChecked, 1);
    assert.equal(fcm.sent.length, 0);
  });

  test("KST로 일요일이 아니면 아무것도 안 함(UTC 일요일 16:00 = KST 월요일 01:00)", async () => {
    await addUser("a", {}, ["t-a"]);
    const fcm = new FakeMessenger();
    const r = await runAttendanceReminder(db, fcm, new Date("2026-11-15T16:00:00Z"));
    assert.equal(r.skipped, "not-sunday-kst");
    assert.equal(fcm.sent.length, 0);
  });
});

describe("#4 매일 정리", () => {
  test("만료 명단 원본, 90일 지난 알림, 60일 지난 토큰 삭제(여러 페이지)", async () => {
    const now = new Date("2026-11-15T18:00:00Z");
    const ago = (days: number) => Timestamp.fromMillis(now.getTime() - days * DAY);
    await db.collection("leaderRosterUploads").doc("expired").set({ expiresAt: ago(1) });
    await db.collection("leaderRosterUploads").doc("valid").set({ expiresAt: ago(-5) });
    const w = db.bulkWriter();
    for (let i = 0; i < 650; i++) {
      void w.set(db.collection("notifications").doc(`old${i}`), { userId: "u", createdAt: ago(91), isRead: true });
    }
    await w.close();
    await db.collection("notifications").doc("recent").set({ userId: "u", createdAt: ago(89) });
    await addUser("u1", {}, ["stale-1"], 61, now);
    await addUser("u2", {}, ["stale-2"], 70, now);
    await addUser("u3", {}, ["fresh-3"], 59, now);
    await db.collection("jobRuns").doc("old").set({ createdAt: ago(100) });
    await db.collection("jobRuns").doc("new").set({ createdAt: ago(1) });

    const r = await runDailyCleanup(db, now);
    assert.deepEqual(r, { leaderRosterUploads: 1, notifications: 650, fcmTokens: 2, jobRuns: 1 });
    assert.deepEqual((await db.collection("leaderRosterUploads").get()).docs.map((d) => d.id), ["valid"]);
    assert.deepEqual((await db.collection("notifications").get()).docs.map((d) => d.id), ["recent"]);
    assert.deepEqual(await tokenIds("u1"), []);
    assert.deepEqual(await tokenIds("u3"), ["fresh-3"]);
    assert.equal((await db.collection("users").doc("u1").get()).exists, true, "회원 문서는 유지");
  });
});

describe("회원 삭제 → 토큰 삭제", () => {
  test("해당 회원 토큰만 삭제", async () => {
    await addUser("gone", {}, ["g1", "g2"]);
    await addUser("stay", {}, ["s1"]);
    assert.equal(await deleteUserTokens(db, "gone"), 2);
    assert.deepEqual(await tokenIds("gone"), []);
    assert.deepEqual(await tokenIds("stay"), ["s1"]);
  });
});
