// Firestore 보안 규칙 테스트(에뮬레이터) — fcmTokens 하위 컬렉션 + 기존 규칙 일부 회귀 확인
import { after, before, beforeEach, describe, test } from "node:test";
import { readFileSync } from "node:fs";
import { join } from "node:path";
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
  type RulesTestEnvironment,
} from "@firebase/rules-unit-testing";
import {
  collection, deleteDoc, doc, getDoc, getDocs, serverTimestamp, setDoc, Timestamp, updateDoc, addDoc,
} from "firebase/firestore";
import { emulatorHost, PROJECT_ID } from "./helpers";

let env: RulesTestEnvironment;
const T = "fcm-token-abc:APA91b";

before(async () => {
  const [host, port] = emulatorHost().split(":");
  env = await initializeTestEnvironment({
    projectId: PROJECT_ID,
    firestore: {
      host, port: Number(port),
      rules: readFileSync(join(__dirname, "..", "..", "..", "firestore.rules"), "utf8"),
    },
  });
});
after(async () => { await env.cleanup(); });
beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await setDoc(doc(db, "users/alice"), { name: "A", role: "member", department: "A-1" });
    await setDoc(doc(db, "users/bob"), { name: "B", role: "member", department: "A-1" });
    await setDoc(doc(db, "users/pastor"), { name: "P", role: "pastor", department: "A-1" });
    await setDoc(doc(db, `users/alice/fcmTokens/existing`), { token: "existing", platform: "ios", updatedAt: Timestamp.now() });
  });
});

const alice = () => env.authenticatedContext("alice").firestore();
const valid = (token = T) => ({ token, platform: "android", updatedAt: serverTimestamp() });

describe("users/{uid}/fcmTokens", () => {
  test("본인: 생성·갱신·조회·목록·삭제 허용", async () => {
    const db = alice();
    await assertSucceeds(setDoc(doc(db, `users/alice/fcmTokens/${T}`), valid()));
    await assertSucceeds(setDoc(doc(db, `users/alice/fcmTokens/${T}`), valid())); // 재로그인 시 갱신(update)
    await assertSucceeds(updateDoc(doc(db, `users/alice/fcmTokens/${T}`), { updatedAt: serverTimestamp() }));
    await assertSucceeds(getDoc(doc(db, `users/alice/fcmTokens/${T}`)));
    await assertSucceeds(getDocs(collection(db, "users/alice/fcmTokens")));
    await assertSucceeds(deleteDoc(doc(db, `users/alice/fcmTokens/${T}`)));
    await assertSucceeds(setDoc(doc(db, "users/alice/fcmTokens/t2"), { token: "t2", platform: "ios", updatedAt: serverTimestamp() }));
  });

  test("본인이라도 형식이 틀리면 거부", async () => {
    const db = alice();
    const ref = doc(db, `users/alice/fcmTokens/${T}`);
    await assertFails(setDoc(ref, { ...valid(), extra: 1 }));
    await assertFails(setDoc(ref, { token: T, platform: "android" }));
    await assertFails(setDoc(ref, { ...valid(), platform: "web" }));
    await assertFails(setDoc(ref, valid("different-token")));
    await assertFails(setDoc(ref, { ...valid(), token: 123 }));
    await assertFails(setDoc(ref, { ...valid(), updatedAt: Timestamp.fromDate(new Date("2030-01-01")) }));
    await assertFails(setDoc(doc(db, `users/alice/fcmTokens/${"x".repeat(1025)}`), valid("x".repeat(1025))));
    await assertFails(updateDoc(doc(db, "users/alice/fcmTokens/existing"), { platform: "android", updatedAt: Timestamp.now() }));
  });

  test("다른 회원·목사님·비로그인: 읽기/목록/쓰기/삭제 모두 거부", async () => {
    for (const db of [
      env.authenticatedContext("bob").firestore(),
      env.authenticatedContext("pastor").firestore(),
      env.unauthenticatedContext().firestore(),
    ]) {
      await assertFails(getDoc(doc(db, "users/alice/fcmTokens/existing")));
      await assertFails(getDocs(collection(db, "users/alice/fcmTokens")));
      await assertFails(setDoc(doc(db, `users/alice/fcmTokens/${T}`), valid()));
      await assertFails(updateDoc(doc(db, "users/alice/fcmTokens/existing"), { updatedAt: serverTimestamp() }));
      await assertFails(deleteDoc(doc(db, "users/alice/fcmTokens/existing")));
    }
  });

  test("회원 문서가 없으면(탈퇴 후 등) 토큰 생성 거부, 삭제는 허용", async () => {
    const db = env.authenticatedContext("ghost").firestore();
    await assertFails(setDoc(doc(db, `users/ghost/fcmTokens/${T}`), valid()));
    await assertSucceeds(deleteDoc(doc(db, `users/ghost/fcmTokens/${T}`)));
  });
});

describe("기존 규칙 회귀 확인(변경 없음)", () => {
  test("회원은 남에게 알림을 만들 수 없고, 서버 전용 컬렉션은 막혀 있음", async () => {
    const db = alice();
    await assertFails(addDoc(collection(db, "notifications"), {
      userId: "pastor", title: "x", body: "y", type: "visitRequest", createdAt: Timestamp.now(), isRead: false,
    }));
    await assertSucceeds(setDoc(doc(db, "visits/v1"), { userId: "alice", status: "pending" }));
    await assertFails(getDoc(doc(db, "jobRuns/attendanceReminder_2026-11-15")));
    await assertFails(setDoc(doc(db, "jobRuns/x"), { a: 1 }));
    await assertFails(getDoc(doc(db, "_emulatorFcmLog/x")));
  });
});

describe("users 읽기: 본인과 명단을 다루는 역할만", () => {
  beforeEach(async () => {
    await env.withSecurityRulesDisabled(async (ctx) => {
      const db = ctx.firestore();
      await setDoc(doc(db, "users/small"), { name: "S", role: "small_leader", department: "A-1" });
      await setDoc(doc(db, "users/mlead"), { name: "M", role: "member", department: "A-1", ministryTeam: "콘텐츠팀", isMinistryLead: true });
    });
  });

  test("본인 문서는 읽기 허용(가입 직후 문서가 없어도)", async () => {
    await assertSucceeds(getDoc(doc(alice(), "users/alice")));
    await assertSucceeds(getDoc(doc(env.authenticatedContext("newbie").firestore(), "users/newbie")));
  });

  test("일반 회원·갓 가입한 계정·비로그인: 남의 문서와 전체 명단 조회 거부", async () => {
    for (const db of [
      env.authenticatedContext("bob").firestore(),
      env.authenticatedContext("newbie").firestore(),
      env.unauthenticatedContext().firestore(),
    ]) {
      await assertFails(getDoc(doc(db, "users/alice")));
      await assertFails(getDocs(collection(db, "users")));
    }
  });

  test("소팀장 이상·목사님·사역팀장: 전체 명단 조회 허용", async () => {
    for (const uid of ["small", "pastor", "mlead"]) {
      const db = env.authenticatedContext(uid).firestore();
      await assertSucceeds(getDoc(doc(db, "users/alice")));
      await assertSucceeds(getDocs(collection(db, "users")));
    }
  });
});

describe("notifications 삭제(보관 기간 정리)", () => {
  const DAY = 24 * 60 * 60 * 1000;
  beforeEach(async () => {
    await env.withSecurityRulesDisabled(async (ctx) => {
      const db = ctx.firestore();
      const at = (days: number) => Timestamp.fromMillis(Date.now() - days * DAY);
      await setDoc(doc(db, "notifications/old"), { userId: "alice", title: "t", body: "b", type: "x", createdAt: at(91), isRead: true });
      await setDoc(doc(db, "notifications/recent"), { userId: "alice", title: "t", body: "b", type: "x", createdAt: at(89), isRead: true });
      await setDoc(doc(db, "notifications/bobOld"), { userId: "bob", title: "t", body: "b", type: "x", createdAt: at(91), isRead: true });
    });
  });

  test("본인: 90일 지난 알림만 삭제 허용", async () => {
    const db = alice();
    await assertSucceeds(deleteDoc(doc(db, "notifications/old")));
    await assertFails(deleteDoc(doc(db, "notifications/recent")));
  });

  test("다른 회원·목사님: 90일 지났어도 삭제 거부", async () => {
    await assertFails(deleteDoc(doc(env.authenticatedContext("alice").firestore(), "notifications/bobOld")));
    await assertFails(deleteDoc(doc(env.authenticatedContext("pastor").firestore(), "notifications/bobOld")));
    await assertFails(deleteDoc(doc(env.unauthenticatedContext().firestore(), "notifications/bobOld")));
  });
});
