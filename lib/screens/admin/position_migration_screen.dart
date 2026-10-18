import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/position_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/firestore_service.dart';
import '../../utils/constants.dart';

// 관리자 전용 1회성 정비 화면: 기존 users 데이터를 positions(자리) 모델로
// 옮긴다. 서비스 계정/Cloud Functions 없이(Spark 요금제) 클라이언트에서 직접
// 실행하도록 만들어졌고, 여러 번 눌러도 안전(멱등)하다 — 항상 현재 users
// 상태를 다시 스캔해서 보여준다. 단일석(capacity=1) 자리에 2명 이상이 매칭되면
// 자동으로 고르지 않고 목록을 보여준 뒤 관리자가 직접 선택하게 한다.
class PositionMigrationScreen extends StatefulWidget {
  const PositionMigrationScreen({super.key});

  @override
  State<PositionMigrationScreen> createState() => _PositionMigrationScreenState();
}

class _PositionMigrationScreenState extends State<PositionMigrationScreen> {
  final _service = FirestoreService();
  Future<List<PositionMigrationEntry>>? _future;
  bool _applying = false;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    setState(() => _future = _service.previewPositionMigration());
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
      appBar: AppBar(title: const Text('자리 마이그레이션')),
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
                '기존 회원 데이터(role/department)를 스캔해 각 자리(소팀장·중팀장·임원팀)의 '
                '현재 holder를 찾습니다. 여러 번 실행해도 안전합니다.',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 16),
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
        title: Text(_positionLabel(entry.def)),
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
            Text(_positionLabel(entry.def), style: const TextStyle(fontWeight: FontWeight.bold)),
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

String _positionLabel(PositionDef def) {
  if (def.role == UserRole.executive) return '${def.department} ${def.executiveTitle}';
  final roleLabel = UserRole.label(def.role);
  return '${AppTeams.deptLabel(def.department)} $roleLabel';
}
