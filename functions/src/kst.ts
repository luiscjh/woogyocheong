// 한국 표준시(KST, UTC+9, 서머타임 없음) 날짜 계산.
// Cloud Functions 서버 시계는 UTC이므로 new Date()의 getDate() 등을 그대로 쓰면
// 한국 날짜와 하루 어긋날 수 있다 — 항상 이 파일의 함수로 KST 날짜를 구한다.

const KST_OFFSET_MS = 9 * 60 * 60 * 1000;

export interface KstDate {
  year: number;
  month: number; // 1~12
  day: number;
  weekday: number; // 0=일 ~ 6=토
}

export function toKst(instant: Date): KstDate {
  const shifted = new Date(instant.getTime() + KST_OFFSET_MS);
  return {
    year: shifted.getUTCFullYear(),
    month: shifted.getUTCMonth() + 1,
    day: shifted.getUTCDate(),
    weekday: shifted.getUTCDay(),
  };
}

// lib/models/attendance_model.dart의 AttendanceModel.dateKey와 같은 형식:
// '${year}-${month 2자리}-${day 2자리}' (예: 2026-11-15). 앱은 기기(한국) 현지
// 날짜로 키를 만들므로 여기서는 KST 날짜로 만든다
export function attendanceDateKey(instant: Date): string {
  const d = toKst(instant);
  return `${d.year}-${String(d.month).padStart(2, "0")}-${String(d.day).padStart(2, "0")}`;
}

// FirestoreService.setAttendance와 같은 문서 id: '${userId}_${dateKey}'
export function attendanceDocId(userId: string, instant: Date): string {
  return `${userId}_${attendanceDateKey(instant)}`;
}
