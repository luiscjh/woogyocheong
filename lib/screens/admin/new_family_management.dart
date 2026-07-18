import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/firestore_service.dart';
import '../../models/user_model.dart';
import '../../models/attendance_model.dart';
import '../../utils/constants.dart';

// 새가족 정의: 임원팀이 관리하는 정식 소팀 명부에 없었던 사람(소팀 미배정)
// 또는 마지막 출석일로부터 1년 이상 지난 사람
const _absenceThresholdDays = 365;

class NewFamilyManagementScreen extends StatelessWidget {
  const NewFamilyManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final service = FirestoreService();
    return Scaffold(
      appBar: AppBar(title: const Text('새가족 관리')),
      body: StreamBuilder<List<UserModel>>(
        stream: service.streamAllMembers(),
        builder: (ctx, memberSnap) {
          return StreamBuilder<List<AttendanceModel>>(
            stream: service.streamAllAttendance(),
            builder: (ctx, attSnap) {
              if (memberSnap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final members = memberSnap.data ?? [];
              final attendance = attSnap.data ?? [];

              // 회원별 마지막 출석일 + 실제 출석 횟수
              final lastAttended = <String, DateTime>{};
              final weekCounts = <String, int>{};
              for (final a in attendance) {
                if (!a.isPresent) continue;
                weekCounts[a.userId] = (weekCounts[a.userId] ?? 0) + 1;
                final cur = lastAttended[a.userId];
                if (cur == null || a.date.isAfter(cur)) lastAttended[a.userId] = a.date;
              }

              final now = DateTime.now();
              final candidates = members.where((m) {
                if (m.role != UserRole.member) return false;
                final unassigned = !AppTeams.smallTeams.contains(m.department);
                final last = lastAttended[m.uid];
                final longAbsent = last == null || now.difference(last).inDays >= _absenceThresholdDays;
                return unassigned || longAbsent;
              }).toList();

              final currentNewFamily = members
                  .where((m) => m.role == UserRole.member && m.department == AppTeams.newFamilyTeam)
                  .toList()
                ..sort((a, b) => (weekCounts[b.uid] ?? 0).compareTo(weekCounts[a.uid] ?? 0));

              if (candidates.isEmpty && currentNewFamily.isEmpty) {
                return const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.diversity_3_outlined, size: 64, color: Colors.grey),
                      SizedBox(height: 12),
                      Text('현재 새가족 대상자가 없습니다.'),
                    ],
                  ),
                );
              }

              return ListView(
                padding: const EdgeInsets.all(12),
                children: [
                  if (currentNewFamily.isNotEmpty) ...[
                    const Text('새가족팀 소속 (졸업 대상 확인)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    const SizedBox(height: 4),
                    const Text(
                      '${AppTeams.newFamilyMaxWeeks}주차 이상 출석하면 실제 소팀으로 배정해 주세요.',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                    ),
                    const SizedBox(height: 8),
                    ...currentNewFamily.map((m) => _CurrentMemberCard(
                          member: m,
                          weekCount: weekCounts[m.uid] ?? 0,
                          service: service,
                        )),
                    const SizedBox(height: 20),
                  ],
                  if (candidates.isNotEmpty) ...[
                    const Text('새가족팀 배정이 필요한 대상', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    const SizedBox(height: 8),
                    ...candidates.map((m) => _CandidateCard(member: m, lastAttended: lastAttended[m.uid], service: service)),
                  ],
                ],
              );
            },
          );
        },
      ),
    );
  }
}

// 새가족팀 소속 회원 - 출석 횟수 확인 및 정해진 주차 도달 시 실제 소팀 배정
class _CurrentMemberCard extends StatelessWidget {
  final UserModel member;
  final int weekCount;
  final FirestoreService service;

  const _CurrentMemberCard({required this.member, required this.weekCount, required this.service});

  bool get _readyToGraduate => weekCount >= AppTeams.newFamilyMaxWeeks;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(member.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(width: 8),
                Text(member.email, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
              ],
            ),
            const SizedBox(height: 8),
            _ReasonChip(
              label: '$weekCount/${AppTeams.newFamilyMaxWeeks}주차',
              color: _readyToGraduate ? AppColors.warning : AppColors.primary,
            ),
            if (_readyToGraduate) ...[
              const Divider(height: 20),
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton.icon(
                  onPressed: () => _showAssignDialog(context),
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.warning),
                  icon: const Icon(Icons.groups_outlined, size: 18),
                  label: const Text('소팀 배정'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showAssignDialog(BuildContext context) {
    final realTeams = AppTeams.smallTeams.where((t) => t != AppTeams.newFamilyTeam).toList();
    String selected = realTeams.first;
    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: Text('${member.name}님 소팀 배정'),
          content: DropdownButtonFormField<String>(
            initialValue: selected,
            decoration: const InputDecoration(labelText: '배정할 소팀'),
            items: realTeams.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
            onChanged: (v) => setState(() => selected = v!),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('취소')),
            ElevatedButton(
              onPressed: () async {
                await service.updateUser(member.copyWith(department: selected));
                if (!ctx.mounted) return;
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('${member.name}님을 $selected 팀으로 배정했습니다.'), backgroundColor: AppColors.success),
                );
              },
              child: const Text('배정'),
            ),
          ],
        ),
      ),
    );
  }
}

class _CandidateCard extends StatelessWidget {
  final UserModel member;
  final DateTime? lastAttended;
  final FirestoreService service;

  const _CandidateCard({required this.member, required this.lastAttended, required this.service});

  bool get _isUnassigned => !AppTeams.smallTeams.contains(member.department);
  bool get _isAlreadyNewFamily => member.department == AppTeams.newFamilyTeam;

  int? get _daysSinceLastAttended =>
      lastAttended == null ? null : DateTime.now().difference(lastAttended!).inDays;

  @override
  Widget build(BuildContext context) {
    final longAbsent = (_daysSinceLastAttended ?? _absenceThresholdDays) >= _absenceThresholdDays;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(member.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(width: 8),
                Text(member.email, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                if (_isUnassigned && !_isAlreadyNewFamily) const _ReasonChip(label: '소팀 미배정', color: AppColors.warning),
                if (_isAlreadyNewFamily) const _ReasonChip(label: '새가족팀 소속', color: AppColors.primary),
                if (longAbsent)
                  _ReasonChip(
                    label: lastAttended == null ? '출석 기록 없음' : '결석 $_daysSinceLastAttended일째',
                    color: AppColors.error,
                  ),
              ],
            ),
            if (lastAttended != null) ...[
              const SizedBox(height: 6),
              Text(
                '마지막 출석일: ${DateFormat('yyyy년 MM월 dd일', 'ko').format(lastAttended!)}',
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
              ),
            ],
            if (!_isAlreadyNewFamily) ...[
              const Divider(height: 20),
              Align(
                alignment: Alignment.centerRight,
                child: OutlinedButton.icon(
                  onPressed: () => _assignToNewFamilyTeam(context),
                  icon: const Icon(Icons.groups_outlined, size: 18),
                  label: const Text('새가족팀 배정'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _assignToNewFamilyTeam(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('새가족팀 배정'),
        content: Text('${member.name}님을 새가족팀으로 배정하시겠습니까?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('취소')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('배정')),
        ],
      ),
    );
    if (confirm != true) return;
    await service.updateUser(member.copyWith(department: AppTeams.newFamilyTeam));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${member.name}님을 새가족팀으로 배정했습니다.'), backgroundColor: AppColors.success),
    );
  }
}

class _ReasonChip extends StatelessWidget {
  final String label;
  final Color color;

  const _ReasonChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }
}
