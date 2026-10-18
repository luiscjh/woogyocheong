import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/position_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/firestore_service.dart';
import '../../utils/constants.dart';
import '../../utils/excel_download.dart';
import '../../utils/leader_roster_excel.dart';

// 관리자 전용 리더 명단 정비 화면. 주된 방법은 엑셀 업로드 — 현재 명단을
// 엑셀로 내려받아 "변경 후" 칸만 고쳐서 다시 올리면, 실제로 바뀐 자리만
// 찾아 한 번에 반영한다(applyPositionAssignments 재사용). 그 아래에는
// 기존 회원 데이터(role/department)를 스캔해 자리와 자동으로 맞춰보는
// 보조 도구를 그대로 둔다(최초 1회 정비 때 쓰였고, 평소에는 비어 있거나
// 충돌만 보여주는 참고용).
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

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    setState(() {
      _future = _service.previewPositionMigration();
      _parseResult = null;
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
      setState(() => _parseResult = result);
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

  Future<void> _applyExcelChanges() async {
    final result = _parseResult;
    if (result == null || result.changes.isEmpty) return;
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
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('엑셀 내용대로 ${assignments.length}개 자리를 변경했습니다.'), backgroundColor: AppColors.success),
      );
      _reload();
    } finally {
      if (mounted) setState(() => _applying = false);
    }
  }

  Future<void> _applyClean(List<PositionMigrationEntry> clean) async {
    setState(() => _applying = true);
    try {
      final performedBy = context.read<AuthProvider>().currentUser!.uid;
      // 공석(matched가 빈 자리)도 그대로 반영해 positions 문서를 만들어 둔다
      final assignments = clean
          .map((e) => PositionAssignment(
                positionId: e.def.id,
                role: e.def.role,
                department: e.def.department,
                capacity: e.def.capacity,
                executiveTitle: e.def.executiveTitle,
                previousHolderUids: e.matched.map((u) => u.uid).toList(),
                holderUids: e.matched.map((u) => u.uid).toList(),
              ))
          .toList();
      await _service.applyPositionAssignments(assignments, performedBy: performedBy);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('충돌 없는 자리 ${assignments.length}개를 반영했습니다.'), backgroundColor: AppColors.success),
      );
      _reload();
    } finally {
      if (mounted) setState(() => _applying = false);
    }
  }

  Future<void> _resolveConflict(PositionMigrationEntry entry, String winnerUid) async {
    setState(() => _applying = true);
    try {
      final performedBy = context.read<AuthProvider>().currentUser!.uid;
      await _service.applyPositionAssignments([
        PositionAssignment(
          positionId: entry.def.id,
          role: entry.def.role,
          department: entry.def.department,
          capacity: entry.def.capacity,
          executiveTitle: entry.def.executiveTitle,
          previousHolderUids: entry.matched.map((u) => u.uid).toList(),
          holderUids: [winnerUid],
        ),
      ], performedBy: performedBy);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('선택한 사람으로 자리를 확정했습니다.'), backgroundColor: AppColors.success),
      );
      _reload();
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
          final conflicts = entries.where((e) => e.isConflict).toList();
          final clean = entries.where((e) => !e.isConflict).toList();
          final filledClean = clean.where((e) => !e.isVacant).toList();

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
                _ExcelPreviewSection(result: _parseResult!, applying: _applying, onApply: _applyExcelChanges),
              ],
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 12),
              const Text('현재 상태 (자동 스캔)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _SummaryCard(label: '충돌 없음', value: '${filledClean.length}개', color: AppColors.success),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _SummaryCard(label: '충돌', value: '${conflicts.length}개', color: AppColors.error),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (conflicts.isNotEmpty) ...[
                const Text('충돌 — 직접 선택 필요', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(height: 8),
                for (final e in conflicts) _ConflictCard(entry: e, applying: _applying, onResolve: (uid) => _resolveConflict(e, uid)),
                const SizedBox(height: 20),
              ],
              if (filledClean.isNotEmpty) ...[
                Row(
                  children: [
                    const Expanded(child: Text('충돌 없는 자리', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15))),
                    ElevatedButton(
                      onPressed: _applying ? null : () => _applyClean(clean),
                      child: const Text('전체 반영'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                for (final e in filledClean) _CleanCard(entry: e),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _ExcelPreviewSection extends StatelessWidget {
  final LeaderRosterParseResult result;
  final bool applying;
  final VoidCallback onApply;

  const _ExcelPreviewSection({required this.result, required this.applying, required this.onApply});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (result.errors.isNotEmpty) ...[
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
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
        if (result.changes.isNotEmpty) ...[
          Row(
            children: [
              Expanded(child: Text('변경 예정 ${result.changes.length}건', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15))),
              ElevatedButton(
                onPressed: applying ? null : onApply,
                child: const Text('반영'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (final c in result.changes) _ChangeCard(change: c),
        ] else if (result.errors.isEmpty)
          const Text('변경할 내용이 없습니다.', style: TextStyle(color: AppColors.textSecondary)),
      ],
    );
  }
}

class _ChangeCard extends StatelessWidget {
  final LeaderRosterChange change;
  const _ChangeCard({required this.change});

  @override
  Widget build(BuildContext context) {
    final before = change.before.isEmpty ? '공석' : change.before.map((u) => u.name).join(', ');
    final after = change.after.isEmpty ? '공석' : change.after.map((u) => u.name).join(', ');
    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      child: ListTile(
        dense: true,
        title: Text(change.def.label),
        subtitle: Text('$before → $after'),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _SummaryCard({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color)),
            Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }
}

class _CleanCard extends StatelessWidget {
  final PositionMigrationEntry entry;
  const _CleanCard({required this.entry});

  @override
  Widget build(BuildContext context) {
    final names = entry.matched.map((u) => u.name).join(', ');
    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      child: ListTile(
        dense: true,
        title: Text(entry.def.label),
        subtitle: Text(names.isEmpty ? '공석' : names),
      ),
    );
  }
}

class _ConflictCard extends StatelessWidget {
  final PositionMigrationEntry entry;
  final bool applying;
  final ValueChanged<String> onResolve;
  const _ConflictCard({required this.entry, required this.applying, required this.onResolve});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: AppColors.error.withValues(alpha: 0.05),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(entry.def.label, style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            const Text('아래 중 한 명을 선택해 자리를 확정해 주세요. 선택되지 않은 사람은 팀원으로 전환됩니다.',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            const SizedBox(height: 8),
            for (final u in entry.matched)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(u.name),
                subtitle: Text(u.email),
                trailing: ElevatedButton(
                  onPressed: applying ? null : () => onResolve(u.uid),
                  child: const Text('이 사람으로 확정'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
