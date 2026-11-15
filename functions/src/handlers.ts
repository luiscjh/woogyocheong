import { FieldPath, Timestamp, type Firestore, type Query } from "firebase-admin/firestore";
import * as logger from "firebase-functions/logger";
import { attendanceDocId, attendanceDateKey, toKst } from "./kst";
import { isReminderTarget, type UserDoc } from "./members";
import { getUserTokens, sendToTokens, type Messenger, type SendResult, type TokenTarget } from "./push";

const DAY_MS = 24 * 60 * 60 * 1000;
export const NOTIFICATION_RETENTION_DAYS = 90;
export const TOKEN_STALE_DAYS = 60;
// 같은 예약 작업이 두 번 실행되지 않게 남기는 기록(jobRuns)의 보관 기간
export const JOB_RUN_RETENTION_DAYS = 90;

// gRPC ALREADY_EXISTS — create()가 이미 있는 문서에 대해 던지는 오류
function isAlreadyExists(e: unknown): boolean {
  return typeof e === "object" && e !== null && (e as { code?: unknown }).code === 6;
}

// ── #1 알림 문서 → 푸시 ─────────────────────────────────────────────
// notifications/{id}가 생기면 그 사용자의 모든 기기로 같은 제목/본문을 보낸다.
// Firestore 트리거는 드물게 같은 이벤트를 두 번 전달할 수 있어, 보내기 전에
// 알림 문서에 pushedAt을 트랜잭션으로 먼저 찍고(이미 있으면 건너뜀) 보낸다 —
// 실패 시 재발송보다 중복 발송 방지를 우선
export async function handleNotificationCreated(
  db: Firestore,
  messenger: Messenger,
  notificationId: string,
): Promise<SendResult | null> {
  const ref = db.collection("notifications").doc(notificationId);
  const claimed = await db.runTransaction(async (txn) => {
    const snap = await txn.get(ref);
    if (!snap.exists) return null;
    const data = snap.data() ?? {};
    if (data.pushedAt) return null;
    txn.update(ref, { pushedAt: Timestamp.now() });
    return data;
  });
  if (!claimed) return null;

  const userId = typeof claimed.userId === "string" ? claimed.userId : "";
  const title = typeof claimed.title === "string" ? claimed.title : "";
  const body = typeof claimed.body === "string" ? claimed.body : "";
  if (!userId || (!title && !body)) return null;

  const tokens = await getUserTokens(db, userId);
  if (tokens.length === 0) return { sent: 0, failed: 0, removedTokens: 0 };
  return sendToTokens(db, messenger, tokens, {
    title: title || "우교청",
    body,
    data: {
      type: typeof claimed.type === "string" ? claimed.type : "",
      notificationId,
    },
  });
}

// ── #2 심방 신청 → 목사님 알림 문서 ───────────────────────────────────
// 회원은 규칙상 남에게 알림 문서를 만들 수 없으므로 서버가 대신 만든다. 여기서는
// 푸시를 직접 보내지 않고 알림 문서만 만든다 — 그 문서가 #1을 트리거해 푸시가
// 정확히 한 번 나간다. 문서 id를 visitRequest_{visitId}_{pastorUid}로 고정해
// 트리거가 두 번 전달돼도 알림이 두 개 생기지 않게 함.
// 개인정보: 푸시/알림 본문에는 신청자 이름만 넣고 연락처·사유는 넣지 않는다. 이름도
// 신청 문서(클라이언트가 쓴 값)가 아니라 users 문서에서 읽는다
export async function handleVisitCreated(
  db: Firestore,
  visitId: string,
  visit: Record<string, unknown> | undefined,
): Promise<number> {
  if (!visit) return 0;
  const requesterUid = typeof visit.userId === "string" ? visit.userId : "";
  let name = "";
  if (requesterUid) {
    const u = await db.collection("users").doc(requesterUid).get();
    const n = u.data()?.name;
    if (typeof n === "string") name = n.trim();
  }
  if (name.length > 20) name = `${name.slice(0, 20)}…`;
  const body = name ? `${name}님이 심방을 신청했습니다.` : "새 심방 신청이 있습니다.";

  const pastors = await db.collection("users").where("role", "==", "pastor").get();
  let created = 0;
  for (const p of pastors.docs) {
    if (p.id === requesterUid) continue; // 본인이 신청한 경우(테스트 등)는 알리지 않음
    try {
      await db.collection("notifications").doc(`visitRequest_${visitId}_${p.id}`).create({
        userId: p.id,
        title: "새 심방 신청",
        body,
        type: "visitRequest",
        createdAt: Timestamp.now(),
        isRead: false,
      });
      created++;
    } catch (e) {
      if (!isAlreadyExists(e)) throw e;
    }
  }
  return created;
}

// ── #3 주일 출석 알림 ────────────────────────────────────────────────
// 매주 일요일 11:00(KST). 오늘 출석 문서(출석/결석 어느 쪽이든 체크한 기록)가
// 없는 대상자에게만 FCM으로 직접 보낸다(알림함 문서는 만들지 않음).
// 대상 기준은 members.ts isReminderTarget 참고
export interface ReminderResult {
  dateKey: string;
  skipped?: string;
  eligible: number;
  alreadyChecked: number;
  withoutToken: number;
  usersNotified: number;
  send: SendResult;
}

export const ATTENDANCE_REMINDER = {
  title: "오늘 출석 체크하셨나요?",
  body: "우교청 앱에서 오늘 예배 출석을 체크해 주세요.",
};

export async function runAttendanceReminder(
  db: Firestore,
  messenger: Messenger,
  now: Date,
): Promise<ReminderResult> {
  const dateKey = attendanceDateKey(now);
  const empty: SendResult = { sent: 0, failed: 0, removedTokens: 0 };
  const base = { dateKey, eligible: 0, alreadyChecked: 0, withoutToken: 0, usersNotified: 0, send: empty };
  const kst = toKst(now);
  if (kst.weekday !== 0) return { ...base, skipped: "not-sunday-kst" };

  // 같은 날 두 번 실행(재시도·수동 실행)돼도 한 번만 보냄
  try {
    await db.collection("jobRuns").doc(`attendanceReminder_${dateKey}`).create({
      job: "attendanceReminder",
      dateKey,
      createdAt: Timestamp.fromDate(now),
    });
  } catch (e) {
    if (isAlreadyExists(e)) return { ...base, skipped: "already-ran" };
    throw e;
  }

  const users = await db.collection("users").get();
  const eligible = users.docs.filter((d) => isReminderTarget(d.data() as UserDoc, kst.year));

  const notChecked: string[] = [];
  for (let i = 0; i < eligible.length; i += 100) {
    const chunk = eligible.slice(i, i + 100);
    const refs = chunk.map((u) => db.collection("attendance").doc(attendanceDocId(u.id, now)));
    const snaps = await db.getAll(...refs);
    snaps.forEach((s, idx) => {
      if (!s.exists) notChecked.push(chunk[idx].id);
    });
  }

  const targets: TokenTarget[] = [];
  let withoutToken = 0;
  let usersNotified = 0;
  for (const uid of notChecked) {
    const tokens = await getUserTokens(db, uid);
    if (tokens.length === 0) withoutToken++;
    else usersNotified++;
    targets.push(...tokens);
  }

  const send = targets.length > 0
    ? await sendToTokens(db, messenger, targets, { ...ATTENDANCE_REMINDER, data: { type: "attendanceReminder" } })
    : empty;
  return {
    dateKey,
    eligible: eligible.length,
    alreadyChecked: eligible.length - notChecked.length,
    withoutToken,
    usersNotified,
    send,
  };
}

// ── #4 매일 정리 ─────────────────────────────────────────────────────
// 쿼리 결과를 pageSize개씩 잘라 지우고, 더 없을 때까지 반복(maxPages로 상한)
export async function deleteByQuery(db: Firestore, query: Query, pageSize = 300, maxPages = 200): Promise<number> {
  let total = 0;
  for (let page = 0; page < maxPages; page++) {
    const snap = await query.limit(pageSize).get();
    if (snap.empty) break;
    const batch = db.batch();
    snap.docs.forEach((d) => batch.delete(d.ref));
    await batch.commit();
    total += snap.size;
    if (snap.size < pageSize) break;
  }
  return total;
}

export interface CleanupResult {
  leaderRosterUploads: number;
  notifications: number;
  fcmTokens: number;
  jobRuns: number;
}

export async function runDailyCleanup(db: Firestore, now: Date): Promise<CleanupResult> {
  const nowTs = Timestamp.fromDate(now);
  const notifCutoff = Timestamp.fromMillis(now.getTime() - NOTIFICATION_RETENTION_DAYS * DAY_MS);
  const tokenCutoff = Timestamp.fromMillis(now.getTime() - TOKEN_STALE_DAYS * DAY_MS);
  const jobCutoff = Timestamp.fromMillis(now.getTime() - JOB_RUN_RETENTION_DAYS * DAY_MS);
  return {
    // 리더 명단 원본(30일 보관) — Firestore TTL 정책이 없어도 지워지도록 함께 정리
    leaderRosterUploads: await deleteByQuery(db,
      db.collection("leaderRosterUploads").where("expiresAt", "<", nowTs)),
    notifications: await deleteByQuery(db,
      db.collection("notifications").where("createdAt", "<", notifCutoff)),
    // 60일 넘게 갱신되지 않은 기기 토큰(앱 삭제·장기 미사용 기기). 앱은 로그인 때마다
    // updatedAt을 서버 시각으로 갱신함
    fcmTokens: await deleteByQuery(db,
      db.collectionGroup("fcmTokens").where("updatedAt", "<", tokenCutoff)),
    jobRuns: await deleteByQuery(db,
      db.collection("jobRuns").where("createdAt", "<", jobCutoff)),
  };
}

// ── 회원 문서 삭제(탈퇴·관리자 삭제) → 그 회원의 모든 기기 토큰 삭제 ─────
// Firestore는 상위 문서를 지워도 하위 컬렉션을 지우지 않으므로 직접 정리
export async function deleteUserTokens(db: Firestore, uid: string): Promise<number> {
  return deleteByQuery(db,
    db.collection("users").doc(uid).collection("fcmTokens").orderBy(FieldPath.documentId()));
}

export function logResult(name: string, result: unknown): void {
  logger.info(name, result as Record<string, unknown>);
}
