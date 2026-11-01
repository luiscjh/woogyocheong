import 'package:church_youth_app/models/position_model.dart';
import 'package:church_youth_app/models/user_model.dart';
import 'package:church_youth_app/utils/constants.dart';
import 'package:church_youth_app/utils/leader_roster_excel.dart';
import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';

// 리더 명단 엑셀 업로드 파서: 내려받은 양식의 "변경 후" 칸만 고쳐서 올렸을 때
// 반영 대상/오류가 행 순서와 무관하게 결정되는지 검증
UserModel _user(String uid, String role, String department) => UserModel(
      uid: uid,
      name: uid,
      email: '$uid@example.com',
      phone: '',
      role: role,
      department: department,
      joinDate: DateTime(2026),
    );

void main() {
  final seats = PositionRegistry.all.where((d) => d.role == UserRole.smallLeader && d.capacity == 1).take(2).toList();
  final seatA = seats[0];
  final seatB = seats[1];
  final x = _user('x', UserRole.smallLeader, seatA.department);
  final y = _user('y', UserRole.smallLeader, seatB.department);
  final m = _user('m', UserRole.member, seatA.department);
  final pastor = _user('p', UserRole.pastor, '');
  final usersByEmail = {for (final u in [x, y, m, pastor]) u.email: u};

  List<PositionMigrationEntry> current() => [
        PositionMigrationEntry(def: seatA, matched: [x]),
        PositionMigrationEntry(def: seatB, matched: [y]),
      ];

  // 양식을 만든 뒤 자리ID → "변경 후" 칸을 덮어써서 바이트로 저장
  // extraRows: (자리ID, 변경 후)로 덧붙일 행, dropIds: 양식에서 지울 자리ID
  List<int> upload(Map<String, String> afterById,
      {bool reversed = false, List<(String, String)> extraRows = const [], Set<String> dropIds = const {}}) {
    var entries = current().where((e) => !dropIds.contains(e.def.id)).toList();
    if (reversed) entries = entries.reversed.toList();
    final book = buildLeaderRosterExcel(entries);
    final sheet = book['리더명단'];
    for (final (id, after) in extraRows) {
      sheet.appendRow([TextCellValue(id), TextCellValue(''), TextCellValue(''), TextCellValue(after)]);
    }
    for (var i = 1; i < sheet.maxRows; i++) {
      final id = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: i)).value.toString();
      final after = afterById[id];
      if (after != null) {
        sheet.updateCell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: i), TextCellValue(after));
      }
    }
    return book.save()!;
  }

  LeaderRosterParseResult parse(List<int> bytes) =>
      parseLeaderRosterExcel(bytes, currentEntries: current(), usersByEmail: usersByEmail);

  test('변경 없는 양식은 변경도 오류도 없다', () {
    final r = parse(upload({}));
    expect(r.changes, isEmpty);
    expect(r.errors, isEmpty);
  });

  test('맞교환은 두 자리 모두 변경으로 잡힌다', () {
    final r = parse(upload({seatA.id: y.email, seatB.id: x.email}));
    expect(r.errors, isEmpty);
    expect(r.changes.map((c) => c.def.id), unorderedEquals([seatA.id, seatB.id]));
  });

  test('한 사람이 두 자리에 있으면 행 순서와 상관없이 두 행 모두 오류', () {
    for (final reversed in [false, true]) {
      // B 행에 x를 넣고 A 행은 그대로 둠 → x가 A, B 두 곳에 등장
      final r = parse(upload({seatB.id: x.email}, reversed: reversed));
      expect(r.changes, isEmpty, reason: 'reversed=$reversed');
      expect(r.errors.length, 2, reason: 'reversed=$reversed');
    }
  });

  test('같은 자리ID가 두 행에 있으면 그 자리는 반영하지 않고 오류', () {
    for (final reversed in [false, true]) {
      // A 행(원래 x)을 m으로 바꾸고, 같은 A 자리ID 행을 하나 더(빈칸) 덧붙임
      final r = parse(upload({seatA.id: m.email}, reversed: reversed, extraRows: [(seatA.id, '')]));
      expect(r.changes, isEmpty, reason: 'reversed=$reversed');
      expect(r.errors.single, contains('같은 자리ID'), reason: 'reversed=$reversed');
    }
  });

  test('양식에서 지운 자리가 있으면 오류', () {
    // A 행을 지우고 x를 B로 옮김 → A 자리 기록에 x가 남지 않도록 막아야 함
    final r = parse(upload({seatB.id: x.email}, dropIds: {seatA.id}));
    expect(r.errors, contains(contains('행이 없습니다')));
  });

  test('미리보기 요약: 맞교환은 둘 다 이동, 강등 없음', () {
    final s = LeaderRosterPreviewSummary.of(parse(upload({seatA.id: y.email, seatB.id: x.email})));
    expect(s.seatCount, 2);
    expect(s.moved, {'x', 'y'});
    expect(s.assigned, isEmpty);
    expect(s.demoted, isEmpty);
  });

  test('미리보기 요약: 새 사람 지정과 기존 담당자 강등', () {
    final s = LeaderRosterPreviewSummary.of(parse(upload({seatA.id: m.email})));
    expect(s.assigned, {'m'});
    expect(s.demoted, {'x'});
    expect(s.moved, isEmpty);
  });

  test('목사님 계정은 엑셀로 자리에 지정할 수 없다', () {
    final r = parse(upload({seatA.id: pastor.email}));
    expect(r.changes, isEmpty);
    expect(r.errors.single, contains('엑셀로 자리에 지정할 수 없습니다'));
  });

  test('같은 칸의 중복 이메일은 하나로 합쳐 정원 초과로 보지 않는다', () {
    final r = parse(upload({seatA.id: '${m.email}; ${m.email}'}));
    expect(r.errors, isEmpty);
    expect(r.changes.single.after.map((u) => u.uid), ['m']);
  });

  test('1MB를 넘는 파일은 풀기 전에 거부한다', () {
    final r = parse(List<int>.filled(1024 * 1024 + 1, 0));
    expect(r.errors.single, contains('1MB'));
  });
}
