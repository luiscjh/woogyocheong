import { test } from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { join } from "node:path";
import { attendanceDateKey, attendanceDocId, toKst } from "../src/kst";

// 컴파일 결과(lib/test)에서 실행되므로 원본 fixture 위치를 기준으로 읽음
const fixture = JSON.parse(
  readFileSync(join(__dirname, "..", "..", "test", "fixtures", "attendance_date_keys.json"), "utf8"),
) as { cases: { utc: string; key: string; weekday: number; note: string }[] };

test("KST 날짜 키가 AttendanceModel.dateKey 형식·한국 날짜와 일치", () => {
  for (const c of fixture.cases) {
    const at = new Date(c.utc);
    assert.equal(attendanceDateKey(at), c.key, c.note);
    assert.equal(toKst(at).weekday, c.weekday, c.note);
  }
});

test("출석 문서 id = userId_dateKey", () => {
  assert.equal(attendanceDocId("uid123", new Date("2026-11-15T02:00:00Z")), "uid123_2026-11-15");
});

test("서버 현지 시간대(TZ)와 무관", () => {
  // Date 객체는 UTC 기준이라 TZ 환경변수와 상관없지만, getDate() 같은 현지 함수를 쓰지 않는지 확인
  const at = new Date("2026-11-14T15:00:00Z");
  assert.equal(attendanceDateKey(at), "2026-11-15");
});
