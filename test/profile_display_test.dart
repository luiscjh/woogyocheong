import 'package:church_youth_app/models/user_model.dart';
import 'package:church_youth_app/screens/profile/profile_screen.dart';
import 'package:church_youth_app/utils/constants.dart';
import 'package:flutter_test/flutter_test.dart';

// 테스트 계정(testing@church.com)은 역할 전환 시 role·department만 바뀌므로,
// 전환한 역할마다 실제 계정과 같은 표시가 나오는지 확인한다
UserModel _testAccount(String role, String department) => UserModel(
      uid: 'test',
      name: '테스트',
      email: 'testing@church.com',
      phone: '',
      role: role,
      department: department,
      joinDate: DateTime(2026, 1, 1),
      cohort: 27,
    );

void main() {
  test('목사님: 부서/그룹은 목사님, 생년월일·기수 숨김', () {
    final u = _testAccount(UserRole.pastor, 'A-1');
    expect(profileGroupLabel(u), '목사님');
    expect(profileShowsMemberDetails(u), isFalse);
  });

  test('관리자: 부서/그룹은 관리자, 생년월일·기수 숨김', () {
    final u = _testAccount(UserRole.admin, 'A-1');
    expect(profileGroupLabel(u), '관리자');
    expect(profileShowsMemberDetails(u), isFalse);
  });

  test('그 밖의 역할: 소속 팀, 생년월일·기수 표시', () {
    for (final (role, dept) in [
      (UserRole.member, 'A-1'),
      (UserRole.smallLeader, 'A-1'),
      (UserRole.midLeader, 'A-0'),
      (UserRole.executive, AppTeams.executiveTeam),
      (UserRole.member, AppTeams.newFamilyTeam),
    ]) {
      final u = _testAccount(role, dept);
      expect(profileGroupLabel(u), dept);
      expect(profileShowsMemberDetails(u), isTrue);
    }
  });
}
