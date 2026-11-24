import 'package:church_youth_app/models/user_model.dart';
import 'package:church_youth_app/utils/constants.dart';
import 'package:flutter_test/flutter_test.dart';

// 테스트 계정(testing@church.com) 역할 전환과 같은 방식(role·department·cohort만 바뀜)으로
// 졸업생 판정을 확인한다
UserModel _user(String role, int? cohort) => UserModel(
      uid: 'test',
      name: '테스트',
      email: 'testing@church.com',
      phone: '',
      role: role,
      department: 'A-1',
      joinDate: DateTime(2026, 1, 1),
      cohort: cohort,
    );

void main() {
  final min = CohortPolicy.minAllowedCohort;
  final max = CohortPolicy.maxAllowedCohort;

  test('범위보다 높은 기수(숫자가 작음)만 졸업생 — 범위 안·낮은 기수·미등록은 아님', () {
    expect(CohortPolicy.isGraduateCohort(min - 1), isTrue);
    expect(CohortPolicy.isGraduateCohort(min - 10), isTrue);
    expect(CohortPolicy.isGraduateCohort(min), isFalse);
    expect(CohortPolicy.isGraduateCohort(max), isFalse);
    expect(CohortPolicy.isGraduateCohort(max + 1), isFalse);
    expect(CohortPolicy.isGraduateCohort(null), isFalse);
  });

  test('팀원·리더 역할도 높은 기수면 졸업생으로 표시', () {
    for (final role in [UserRole.member, UserRole.smallLeader, UserRole.midLeader, UserRole.executive]) {
      final u = _user(role, min - 1);
      expect(u.isGraduate, isTrue, reason: role);
      expect(u.roleLabel, '졸업생', reason: role);
    }
  });

  test('목사님·관리자는 기수가 높아도 졸업생이 아님', () {
    expect(_user(UserRole.pastor, min - 1).isGraduate, isFalse);
    expect(_user(UserRole.admin, min - 1).isGraduate, isFalse);
    expect(_user(UserRole.admin, min - 1).roleLabel, '관리자');
  });

  test('범위 안 기수는 원래 역할 이름 그대로', () {
    expect(_user(UserRole.smallLeader, min).roleLabel, '소팀장');
    expect(_user(UserRole.member, max).isGraduate, isFalse);
  });
}
