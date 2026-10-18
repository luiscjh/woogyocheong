import 'package:excel/excel.dart' hide Border;
import '../models/position_model.dart';
import '../models/user_model.dart';

// 리더 명단을 엑셀로 내보내고(현재 26개 자리 전수), 관리자가 "변경 후" 칸만
// 고쳐서 다시 올리면 실제로 바뀐 자리만 찾아 한 번에 반영할 수 있게 한다.
// "변경 전" 칸은 참고용일 뿐 업로드 시점에 신뢰하지 않는다(다운로드 이후
// 실데이터가 바뀌었을 수 있으므로) — 항상 currentEntries(최신 스캔 결과)와
// 비교해서 실제로 바뀐 자리만 반영 대상으로 삼는다.

const _sheetName = '리더명단';
const _headerRow = ['자리ID(수정 금지)', '자리', '변경 전', '변경 후(이메일, 다인석은 ; 로 구분)'];

String _holdersLabel(List<UserModel> holders) =>
    holders.isEmpty ? '' : holders.map((u) => '${u.name}(${u.email})').join('; ');

String _holdersEmails(List<UserModel> holders) =>
    holders.isEmpty ? '' : holders.map((u) => u.email).join('; ');

// 현재 리더 명단(PositionMigrationEntry 목록)을 엑셀 워크북으로 변환.
// 바이트가 아니라 Excel 객체 자체를 돌려주는 이유: excel 패키지는 웹에서
// save()를 호출하는 순간 그 자체로 브라우저 다운로드를 실행해 버려서(기본
// 파일명 "FlutterExcel.xlsx" 고정), 여기서 미리 저장해 버리면 excel_download가
// 원하는 파일명으로 다시 내려받을 때 다운로드가 중복된다. 그래서 book.save()
// 호출은 플랫폼별 분기가 있는 excel_download 쪽으로 미룬다.
Excel buildLeaderRosterExcel(List<PositionMigrationEntry> entries) {
  final book = Excel.createExcel();
  book.rename(book.getDefaultSheet()!, _sheetName);
  final sheet = book[_sheetName];
  sheet.appendRow(_headerRow.map((h) => TextCellValue(h)).toList());
  for (final e in entries) {
    sheet.appendRow([
      TextCellValue(e.def.id),
      TextCellValue(e.def.label),
      TextCellValue(_holdersLabel(e.matched)),
      TextCellValue(_holdersEmails(e.matched)),
    ]);
  }
  return book;
}

// 엑셀 한 자리의 "변경 전 → 변경 후" 차이
class LeaderRosterChange {
  final PositionDef def;
  final List<UserModel> before;
  final List<UserModel> after;
  const LeaderRosterChange({required this.def, required this.before, required this.after});
}

class LeaderRosterParseResult {
  final List<LeaderRosterChange> changes;
  final List<String> errors;
  const LeaderRosterParseResult({required this.changes, required this.errors});
}

// 업로드된 엑셀 바이트를 파싱해, currentEntries(방금 다시 스캔한 최신 상태)와
// 달라진 자리만 changes로 뽑는다. usersByEmail은 "변경 후" 칸의 이메일을 실제
// 회원으로 찾기 위한 색인(FirestoreService.fetchUsersByEmail 결과).
LeaderRosterParseResult parseLeaderRosterExcel(
  List<int> bytes, {
  required List<PositionMigrationEntry> currentEntries,
  required Map<String, UserModel> usersByEmail,
}) {
  final Excel book;
  try {
    book = Excel.decodeBytes(bytes);
  } catch (_) {
    return const LeaderRosterParseResult(changes: [], errors: ['엑셀 파일을 읽을 수 없습니다. .xlsx 형식인지 확인해 주세요.']);
  }

  final sheet = book.tables[_sheetName] ?? (book.tables.isEmpty ? null : book.tables.values.first);
  if (sheet == null) {
    return const LeaderRosterParseResult(changes: [], errors: ['시트를 찾을 수 없습니다.']);
  }

  final currentById = {for (final e in currentEntries) e.def.id: e};
  final errors = <String>[];
  final changes = <LeaderRosterChange>[];

  for (final row in sheet.rows.skip(1)) {
    if (row.isEmpty) continue;
    final positionId = _cellText(row.isNotEmpty ? row[0]?.value : null).trim();
    if (positionId.isEmpty) continue;

    final entry = currentById[positionId];
    if (entry == null) {
      errors.add('알 수 없는 자리ID: $positionId');
      continue;
    }

    final afterText = _cellText(row.length > 3 ? row[3]?.value : null).trim();
    final afterEmails = afterText.isEmpty
        ? <String>[]
        : afterText.split(RegExp(r'[;,]')).map((e) => e.trim().toLowerCase()).where((e) => e.isNotEmpty).toList();

    final afterUsers = <UserModel>[];
    var rowHasError = false;
    for (final email in afterEmails) {
      final u = usersByEmail[email];
      if (u == null) {
        errors.add('${entry.def.label}: 일치하는 회원 없음 ($email)');
        rowHasError = true;
        continue;
      }
      afterUsers.add(u);
    }
    if (rowHasError) continue;

    if (entry.def.capacity == 1 && afterUsers.length > 1) {
      errors.add('${entry.def.label}: 정원 초과 (1명만 가능한 자리에 ${afterUsers.length}명)');
      continue;
    }

    final beforeIds = entry.matched.map((u) => u.uid).toSet();
    final afterIds = afterUsers.map((u) => u.uid).toSet();
    if (beforeIds.length == afterIds.length && beforeIds.containsAll(afterIds)) {
      continue; // 변경 없음
    }

    changes.add(LeaderRosterChange(def: entry.def, before: entry.matched, after: afterUsers));
  }

  return LeaderRosterParseResult(changes: changes, errors: errors);
}

String _cellText(CellValue? value) {
  return switch (value) {
    null => '',
    TextCellValue() => value.value.text ?? '',
    IntCellValue() => value.value.toString(),
    DoubleCellValue() => value.value.toString(),
    _ => value.toString(),
  };
}
