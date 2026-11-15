import { test } from "node:test";
import assert from "node:assert/strict";
import { isCohortRestricted, isReminderTarget } from "../src/members";

test("출석 알림 대상 판정", () => {
  const base = { role: "member", department: "A-1", email: "a@b.com", cohort: 27 };
  assert.equal(isReminderTarget(base, 2026), true);
  assert.equal(isReminderTarget({ ...base, role: "small_leader" }, 2026), true, "리더도 출석 대상");
  assert.equal(isReminderTarget({ ...base, role: "admin" }, 2026), true);
  assert.equal(isReminderTarget({ ...base, role: "pastor" }, 2026), false, "목사님 제외");
  assert.equal(isReminderTarget({ ...base, department: "" }, 2026), false, "온보딩 미완료 제외");
  assert.equal(isReminderTarget({ ...base, department: undefined }, 2026), false);
  assert.equal(isReminderTarget({ ...base, email: "Testing@Church.com" }, 2026), false, "테스트 계정 제외");
  assert.equal(isReminderTarget({ ...base, cohort: 15 }, 2026), false, "기수 제한 제외");
  assert.equal(isReminderTarget({ ...base, cohort: null }, 2026), true, "기수 미등록은 제한 안 함(앱과 동일)");
  assert.equal(isReminderTarget({ ...base, department: "새가족팀" }, 2026), true);
});

test("기수 허용 범위는 해마다 1씩 이동(CohortPolicy와 동일)", () => {
  assert.equal(isCohortRestricted(24, 2026), false);
  assert.equal(isCohortRestricted(30, 2026), false);
  assert.equal(isCohortRestricted(23, 2026), true);
  assert.equal(isCohortRestricted(31, 2026), true);
  assert.equal(isCohortRestricted(24, 2027), true);
  assert.equal(isCohortRestricted(31, 2027), false);
});
