// 주일 출석 알림 대상 판정 — 앱의 규칙과 같은 기준을 서버에서 다시 적용한다.

// lib/utils/constants.dart의 CohortPolicy와 같은 값(기준 연도 2026년에 24~30기,
// 매년 1씩 자동으로 밀림). 앱 쪽 값을 바꾸면 여기도 같이 바꿔야 함
const COHORT_BASE_YEAR = 2026;
const COHORT_BASE_MIN = 24;
const COHORT_BASE_MAX = 30;

// firestore.rules의 isTestAccount()와 같은 QA 전용 계정
const TEST_ACCOUNT_EMAIL = "testing@church.com";

export interface UserDoc {
  role?: unknown;
  department?: unknown;
  email?: unknown;
  cohort?: unknown;
  name?: unknown;
}

// AuthProvider.isCohortRestricted와 같은 판정(목사님 예외는 호출부에서 이미 제외).
// 범위보다 높은 기수(숫자가 작음)는 졸업생 — 관리자는 졸업생이 아니므로 제한하지 않음
export function isCohortRestricted(cohort: unknown, kstYear: number, role?: unknown): boolean {
  if (typeof cohort !== "number") return false; // 기수 미등록이면 제한하지 않음(앱과 동일)
  const shift = kstYear - COHORT_BASE_YEAR;
  if (cohort < COHORT_BASE_MIN + shift) return role !== "admin";
  return cohort > COHORT_BASE_MAX + shift;
}

// 알림 대상: 앱에서 실제로 "오늘 출석 체크"를 할 수 있는 청년만.
// - 목사님(role=pastor) 제외 — 출석 대상이 아님
// - 소속팀(department)이 비어 있는 회원 제외 — 온보딩(소속팀 등록)을 마치지 않음
// - QA 테스트 계정(testing@church.com) 제외
// - 기수 이용 제한 대상 제외 — 앱이 출석 체크 버튼을 막아 두어 알림을 받아도 할 수 없음
// (users 문서에 별도의 휴면/비활성 플래그는 없음 — UserModel·firestore.rules 확인)
export function isReminderTarget(user: UserDoc, kstYear: number): boolean {
  if (user.role === "pastor") return false;
  if (typeof user.department !== "string" || user.department.trim() === "") return false;
  if (typeof user.email === "string" && user.email.trim().toLowerCase() === TEST_ACCOUNT_EMAIL) return false;
  if (isCohortRestricted(user.cohort, kstYear, user.role)) return false;
  return true;
}
