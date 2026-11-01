import 'package:excel/excel.dart' hide Border;
import '../models/position_model.dart';
import '../models/user_model.dart';
import 'constants.dart';

// 리더 명단을 엑셀로 내보내고(현재 26개 자리 전수), 관리자가 "변경 후" 칸만
// 고쳐서 다시 올리면 실제로 바뀐 자리만 찾아 한 번에 반영할 수 있게 한다.
// "변경 전" 칸은 참고용일 뿐 업로드 시점에 신뢰하지 않는다(다운로드 이후
// 실데이터가 바뀌었을 수 있으므로) — 항상 currentEntries(최신 스캔 결과)와
// 비교해서 실제로 바뀐 자리만 반영 대상으로 삼는다.

const _sheetName = '리더명단';
const _maxBytes = 1024 * 1024;
const _maxRows = 200;
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

// 미리보기용 사람별 영향 요약. 실제 반영(applyPositionAssignments)과 같은
// 기준으로 계산한다 — 어떤 자리에서 빠져도 다른 자리에 새로 들어가면 강등이
// 아니라 이동이다(승급이 강등보다 우선)
class LeaderRosterPreviewSummary {
  final int seatCount;
  final Set<String> assigned; // 자리가 없다가 새로 맡는 사람
  final Set<String> moved; // 한 자리에서 빠지고 다른 자리에 들어가는 사람
  final Set<String> demoted; // 자리에서 빠지고 어디에도 들어가지 않아 팀원이 되는 사람
  const LeaderRosterPreviewSummary({required this.seatCount, required this.assigned, required this.moved, required this.demoted});

  factory LeaderRosterPreviewSummary.of(LeaderRosterParseResult result) {
    final removed = <String>{};
    final added = <String>{};
    for (final c in result.changes) {
      final beforeIds = c.before.map((u) => u.uid).toSet();
      final afterIds = c.after.map((u) => u.uid).toSet();
      removed.addAll(beforeIds.difference(afterIds));
      added.addAll(afterIds.difference(beforeIds));
    }
    return LeaderRosterPreviewSummary(
      seatCount: result.changes.length,
      assigned: added.difference(removed),
      moved: added.intersection(removed),
      demoted: removed.difference(added),
    );
  }
}

// 업로드된 엑셀 바이트를 파싱해, currentEntries(방금 다시 스캔한 최신 상태)와
// 달라진 자리만 changes로 뽑는다. usersByEmail은 "변경 후" 칸의 이메일을 실제
// 회원으로 찾기 위한 색인(FirestoreService.fetchUsersByEmail 결과).
LeaderRosterParseResult parseLeaderRosterExcel(
  List<int> bytes, {
  required List<PositionMigrationEntry> currentEntries,
  required Map<String, UserModel> usersByEmail,
}) {
  // 리더 명단은 수십 행짜리 작은 파일이라, 이보다 크면 잘못된 파일(또는 압축
  // 폭탄)로 보고 메모리에 풀기 전에 거부한다
  if (bytes.length > _maxBytes) {
    return const LeaderRosterParseResult(changes: [], errors: ['파일이 너무 큽니다(1MB 초과). 내려받은 리더 명단 엑셀을 사용해 주세요.']);
  }
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

  if (sheet.maxRows > _maxRows) {
    return const LeaderRosterParseResult(changes: [], errors: ['행이 너무 많습니다($_maxRows행 초과). 내려받은 리더 명단 엑셀을 사용해 주세요.']);
  }

  // 행마다 (자리ID, "변경 후" 이메일 목록)을 먼저 뽑아 둔다
  final rows = <({String positionId, List<String> emails})>[];
  for (final row in sheet.rows.skip(1)) {
    if (row.isEmpty) continue;
    final positionId = _cellText(row[0]?.value).trim();
    if (positionId.isEmpty) continue;
    final afterText = _cellText(row.length > 3 ? row[3]?.value : null).trim();
    final emails = afterText.isEmpty
        ? <String>[]
        : afterText.split(RegExp(r'[;,]')).map((e) => e.trim().toLowerCase()).where((e) => e.isNotEmpty).toSet().toList();
    rows.add((positionId: positionId, emails: emails));
  }

  // 같은 자리ID가 여러 행에 있으면 어느 행을 따를지 모호하다(같은 positions
  // 문서를 두 번 쓰면 마지막 행만 남고, 사람 승급은 두 행 모두 적용돼 어긋남).
  // 그 자리의 행은 모두 오류로 빼고 아래 중복 사람 집계에서도 제외한다
  final idCounts = <String, int>{};
  for (final r in rows) {
    idCounts[r.positionId] = (idCounts[r.positionId] ?? 0) + 1;
  }
  final duplicatedIds = {for (final e in idCounts.entries) if (e.value > 1) e.key};
  for (final id in duplicatedIds) {
    final label = currentById[id]?.def.label ?? id;
    errors.add('$label: 같은 자리ID가 ${idCounts[id]}개 행에 있습니다. 한 자리는 한 행에만 적어 주세요.');
  }

  // 내려받은 양식의 행을 지우면 그 자리의 현재 담당자가 positions에 그대로
  // 남은 채 다른 자리로 옮겨질 수 있으므로, 빠진 자리가 있으면 오류로 처리
  final presentIds = idCounts.keys.toSet();
  for (final e in currentEntries) {
    if (!presentIds.contains(e.def.id)) {
      errors.add('${e.def.label}: 행이 없습니다. 내려받은 양식의 행은 지우지 말고 "변경 후" 칸만 고쳐 주세요.');
    }
  }

  // 한 사람이 여러 자리의 "변경 후"에 동시에 들어가면(변경 없는 행 포함) 어느
  // 자리로 갈지 모호하다. 먼저 전체 행을 훑어 uid별 등장 자리를 모은 뒤, 그
  // 사람이 들어 있는 행을 "모두" 오류로 뺀다 — 첫 행만 반영되고 나머지만
  // 빠지면 결과가 행 순서에 따라 달라지기 때문
  final placesByUid = <String, List<String>>{};
  for (final r in rows) {
    if (duplicatedIds.contains(r.positionId)) continue;
    final label = currentById[r.positionId]?.def.label;
    if (label == null) continue;
    for (final email in r.emails) {
      final u = usersByEmail[email];
      if (u != null) (placesByUid[u.uid] ??= []).add(label);
    }
  }

  for (final r in rows) {
    final positionId = r.positionId;
    if (duplicatedIds.contains(positionId)) continue; // 위에서 오류로 처리함
    final entry = currentById[positionId];
    if (entry == null) {
      errors.add('알 수 없는 자리ID: $positionId');
      continue;
    }
    final afterEmails = r.emails;

    final afterUsers = <UserModel>[];
    var rowHasError = false;
    for (final email in afterEmails) {
      final u = usersByEmail[email];
      if (u == null) {
        errors.add('${entry.def.label}: 일치하는 회원 없음 ($email)');
        rowHasError = true;
        continue;
      }
      // 관리자·목사님은 리더 자리로 옮기면 사실상 강등되므로 엑셀로는 지정하지
      // 않는다(이메일 오타나 동명이인으로 인한 사고 방지) — 필요하면 청년부
      // 명단 화면에서 직접 수정
      if (u.role == UserRole.admin || u.role == UserRole.pastor) {
        errors.add('${entry.def.label}: ${UserRole.labels[u.role]} 계정은 엑셀로 자리에 지정할 수 없습니다 ($email)');
        rowHasError = true;
        continue;
      }
      final places = placesByUid[u.uid]!;
      if (places.length > 1) {
        errors.add('${entry.def.label}: ${u.name}($email)님이 ${places.join(', ')} 자리에 함께 들어 있습니다. 한 사람은 한 자리에만 적어 주세요.');
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
