import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/position_model.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/firestore_service.dart';
import '../../utils/constants.dart';
import '../../utils/excel_download.dart';
import '../../utils/leader_roster_excel.dart';

// 관리자 전용 리더 명단 정비 화면. 주된 방법은 엑셀 업로드 — 현재 명단을
// 엑셀로 내려받아 "변경 후" 칸만 고쳐서 다시 올리면, 실제로 바뀐 자리만
// 찾아 한 번에 반영한다(applyPositionAssignments 재사용). 현재 명단은
// previewPositionMigration(회원 role/department 스캔)으로 만들어 엑셀
// 다운로드와 업로드 비교 기준으로만 쓰고, 화면에 따로 보여주지는 않는다.
class PositionMigrationScreen extends StatefulWidget {
  const PositionMigrationScreen({super.key});

  @override
  State<PositionMigrationScreen> createState() => _PositionMigrationScreenState();
}

class _PositionMigrationScreenState extends State<PositionMigrationScreen> {
  final _service = FirestoreService();
  Future<List<PositionMigrationEntry>>? _future;
  bool _applying = false;
  bool _downloading = false;
  bool _uploading = false;
  LeaderRosterParseResult? _parseResult;
  List<int>? _uploadedBytes;
  String? _uploadedFileName;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    setState(() {
      _future = _service.previewPositionMigration();
      _parseResult = null;
      _uploadedBytes = null;
      _uploadedFileName = null;
    });
  }

  Future<void> _downloadTemplate(List<PositionMigrationEntry> entries) async {
    setState(() => _downloading = true);
    try {
      final book = buildLeaderRosterExcel(entries);
      final today = DateTime.now().toIso8601String().substring(0, 10);
      await downloadExcelBook(book, '리더명단_$today.xlsx');
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  Future<void> _uploadExcel(List<PositionMigrationEntry> currentEntries) async {
    final file = await FilePicker.pickFile(type: FileType.custom, allowedExtensions: ['xlsx']);
    if (file == null) return;

    setState(() => _uploading = true);
    try {
      final bytes = await file.readAsBytes();
      final usersByEmail = await _service.fetchUsersByEmail();
      final result = parseLeaderRosterExcel(bytes, currentEntries: currentEntries, usersByEmail: usersByEmail);
      if (!mounted) return;
      setState(() {
        _parseResult = result;
        _uploadedBytes = bytes;
        _uploadedFileName = file.name;
      });
      if (result.changes.isEmpty && result.errors.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('엑셀 내용이 현재 상태와 같아 변경할 내용이 없습니다.')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('엑셀을 읽는 중 오류가 발생했습니다: $e'), backgroundColor: AppColors.error),
      );
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  // 미리보기를 닫는다 — 업로드한 파일은 반영하지 않고 버림
  void _cancelPreview() {
    setState(() {
      _parseResult = null;
      _uploadedBytes = null;
      _uploadedFileName = null;
    });
  }

  Future<void> _applyExcelChanges() async {
    final result = _parseResult;
    // 버튼 비활성화와 별개로, 처리하지 못한 행이 있으면 여기서도 막는다
    if (result == null || result.changes.isEmpty || result.errors.isNotEmpty) return;
    // 미리보기를 검수한 뒤에도 한 번 더 확인받는다(실제 역할이 바뀌는 작업)
    final summary = LeaderRosterPreviewSummary.of(result);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('최종 반영'),
        content: Text(
          '${summary.seatCount}개 자리를 변경합니다.\n'
          '· 새로 자리를 맡는 사람: ${summary.assigned.length}명\n'
          '· 다른 자리로 옮기는 사람: ${summary.moved.length}명\n'
          '· 팀원으로 바뀌는 사람: ${summary.demoted.length}명\n\n'
          '반영하면 바로 각 회원의 역할과 소속이 바뀝니다. 진행할까요?',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('취소')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('반영')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _applying = true);
    try {
      final performedBy = context.read<AuthProvider>().currentUser!.uid;
      final assignments = result.changes
          .map((c) => PositionAssignment(
                positionId: c.def.id,
                role: c.def.role,
                department: c.def.department,
                capacity: c.def.capacity,
                executiveTitle: c.def.executiveTitle,
                previousHolderUids: c.before.map((u) => u.uid).toList(),
                holderUids: c.after.map((u) => u.uid).toList(),
              ))
          .toList();
      await _service.applyPositionAssignments(assignments, performedBy: performedBy);
      // 실제로 반영된 엑셀 원본만 30일 보관(저장 실패해도 이미 끝난 반영
      // 자체는 되돌리지 않고, 보관만 못 됐다고 별도로 안내)
      final bytes = _uploadedBytes;
      if (bytes != null) {
        try {
          await _service.saveLeaderRosterUpload(
            fileName: _uploadedFileName ?? '리더명단.xlsx',
            fileBytes: bytes,
            uploadedBy: performedBy,
          );
        } catch (_) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('반영은 완료됐지만 엑셀 원본 보관에는 실패했습니다.'), backgroundColor: AppColors.error),
            );
          }
        }
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('엑셀 내용대로 ${assignments.length}개 자리를 변경했습니다.'), backgroundColor: AppColors.success),
      );
      _reload();
    } catch (e) {
      // 한 배치라 실패하면 아무것도 바뀌지 않음 — 다시 시도할 수 있게 안내만 한다
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('반영하지 못했습니다(변경된 내용 없음): $e'), backgroundColor: AppColors.error),
      );
    } finally {
      if (mounted) setState(() => _applying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('리더 명단 최신화')),
      body: FutureBuilder<List<PositionMigrationEntry>>(
        future: _future,
        builder: (ctx, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final entries = snap.data!;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text(
                '엑셀을 내려받아 "변경 후" 칸만 고친 뒤 다시 올리면, 바뀐 자리만 찾아 한 번에 반영합니다.',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _downloading ? null : () => _downloadTemplate(entries),
                      icon: const Icon(Icons.download_outlined),
                      label: const Text('엑셀 다운로드'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _uploading ? null : () => _uploadExcel(entries),
                      icon: const Icon(Icons.upload_outlined),
                      label: const Text('엑셀 업로드'),
                    ),
                  ),
                ],
              ),
              if (_parseResult != null) ...[
                const SizedBox(height: 20),
                _ExcelPreviewSection(
                  result: _parseResult!,
                  fileName: _uploadedFileName,
                  applying: _applying,
                  onApply: _applyExcelChanges,
                  onCancel: _cancelPreview,
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

// 엑셀 업로드 결과 미리보기. 업로드만으로는 아무것도 바뀌지 않고, 관리자가
// 이 영역에서 자리별 변경 내용과 사람별 영향(새로 지정/이동/팀원으로 변경)을
// 검수한 뒤 "최종 반영"을 눌러야 실제로 적용된다
class _ExcelPreviewSection extends StatelessWidget {
  final LeaderRosterParseResult result;
  final String? fileName;
  final bool applying;
  final VoidCallback onApply;
  final VoidCallback onCancel;

  const _ExcelPreviewSection({
    required this.result,
    required this.fileName,
    required this.applying,
    required this.onApply,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final summary = LeaderRosterPreviewSummary.of(result);
    final hasErrors = result.errors.isNotEmpty;
    final canApply = !applying && !hasErrors && result.changes.isNotEmpty;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.5)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.fact_check_outlined, color: AppColors.primary),
              const SizedBox(width: 8),
              const Expanded(child: Text('업로드 미리보기', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
              IconButton(
                tooltip: '미리보기 닫기',
                icon: const Icon(Icons.close),
                onPressed: applying ? null : onCancel,
              ),
            ],
          ),
          Text(
            '${fileName != null ? '$fileName · ' : ''}아직 반영되지 않았습니다. 아래 내용을 확인한 뒤 "최종 반영"을 눌러 주세요.',
            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _CountChip(label: '변경 자리', count: summary.seatCount, color: AppColors.primary),
              _CountChip(label: '새로 지정', count: summary.assigned.length, color: AppColors.success),
              _CountChip(label: '자리 이동', count: summary.moved.length, color: Colors.orange),
              _CountChip(label: '팀원으로 변경', count: summary.demoted.length, color: AppColors.error),
              if (hasErrors) _CountChip(label: '오류', count: result.errors.length, color: AppColors.error),
            ],
          ),
          if (hasErrors) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('처리하지 못한 행', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.error)),
                  const SizedBox(height: 6),
                  for (final e in result.errors)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text('· $e', style: const TextStyle(fontSize: 12, color: AppColors.error)),
                    ),
                  const SizedBox(height: 6),
                  // 일부만 반영되는 일이 없도록, 엑셀을 고쳐 다시 올릴 때까지 반영을 막는다
                  const Text('엑셀에서 위 행을 고친 뒤 다시 업로드해야 반영할 수 있습니다.',
                      style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          if (result.changes.isNotEmpty) ...[
            const Text('자리별 변경 내용', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 6),
            for (final c in result.changes) _ChangeCard(change: c, summary: summary),
          ] else if (!hasErrors)
            const Text('엑셀 내용이 현재 명단과 같아 변경할 내용이 없습니다.', style: TextStyle(color: AppColors.textSecondary)),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              OutlinedButton(onPressed: applying ? null : onCancel, child: const Text('취소')),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: canApply ? onApply : null,
                icon: applying
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.check),
                label: const Text('최종 반영'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CountChip extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  const _CountChip({required this.label, required this.count, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text('$label $count', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
    );
  }
}

// 자리 하나의 변경 전 → 변경 후. 동명이인·이메일 오타를 알아볼 수 있도록
// 이메일을 함께 보여주고, 사람마다 반영 후 어떻게 되는지 표시한다
class _ChangeCard extends StatelessWidget {
  final LeaderRosterChange change;
  final LeaderRosterPreviewSummary summary;
  const _ChangeCard({required this.change, required this.summary});

  @override
  Widget build(BuildContext context) {
    final beforeIds = change.before.map((u) => u.uid).toSet();
    final afterIds = change.after.map((u) => u.uid).toSet();
    final leaving = change.before.where((u) => !afterIds.contains(u.uid)).toList();
    final staying = change.before.where((u) => afterIds.contains(u.uid)).toList();
    final arriving = change.after.where((u) => !beforeIds.contains(u.uid)).toList();

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(change.def.label, style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            _PersonLine(heading: '변경 전', people: change.before.map(_who).toList()),
            _PersonLine(heading: '변경 후', people: change.after.map(_who).toList()),
            if (leaving.isNotEmpty || arriving.isNotEmpty) const Divider(height: 16),
            for (final u in arriving)
              _ImpactLine(
                text: '${_who(u)} → 이 자리를 맡음${summary.moved.contains(u.uid) ? ' (다른 자리에서 이동)' : ''}',
                color: AppColors.success,
              ),
            for (final u in leaving)
              _ImpactLine(
                text: summary.moved.contains(u.uid) || summary.assigned.contains(u.uid)
                    ? '${_who(u)} → 다른 자리로 이동'
                    : '${_who(u)} → 팀원으로 변경',
                color: summary.demoted.contains(u.uid) ? AppColors.error : Colors.orange,
              ),
            if (staying.isNotEmpty && change.def.isMultiSeat)
              _ImpactLine(text: '유지: ${staying.map(_who).join(', ')}', color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }

  static String _who(UserModel u) => '${u.name}(${u.email})';
}

class _PersonLine extends StatelessWidget {
  final String heading;
  final List<String> people;
  const _PersonLine({required this.heading, required this.people});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 56, child: Text(heading, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary))),
          Expanded(child: Text(people.isEmpty ? '공석' : people.join(', '), style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }
}

class _ImpactLine extends StatelessWidget {
  final String text;
  final Color color;
  const _ImpactLine({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Text('· $text', style: TextStyle(fontSize: 12, color: color)),
    );
  }
}
