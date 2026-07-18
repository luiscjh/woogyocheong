import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../services/firestore_service.dart';
import '../../models/user_model.dart';
import '../../models/attendance_model.dart';
import '../../models/new_family_rotation_model.dart';
import '../../utils/constants.dart';

// 새가족팀장 전용: 새가족 온보딩 1주차~3주차 각각에 고정 담당 리더를 배정하고,
// 현재 각 주차(출석 횟수 기준)에 해당하는 새가족 명단을 확인
class NewFamilyRotationManagementScreen extends StatelessWidget {
  const NewFamilyRotationManagementScreen({super.key});

  static NewFamilyRotationModel? _rotationForWeek(List<NewFamilyRotationModel> rotations, int week) {
    for (final r in rotations) {
      if (r.weekNumber == week) return r;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final service = FirestoreService();
    return Scaffold(
      appBar: AppBar(title: const Text('새가족 로테이션 관리')),
      body: StreamBuilder<List<UserModel>>(
        stream: service.streamAllMembers(),
        builder: (ctx, memberSnap) {
          return StreamBuilder<List<AttendanceModel>>(
            stream: service.streamAllAttendance(),
            builder: (ctx, attSnap) {
              return StreamBuilder<List<NewFamilyRotationModel>>(
                stream: service.streamNewFamilyRotations(),
                builder: (ctx, rotSnap) {
                  if (memberSnap.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final members = memberSnap.data ?? [];
                  final attendance = attSnap.data ?? [];
                  final rotations = rotSnap.data ?? [];

                  final leaders = members
                      .where((m) => m.role == UserRole.smallLeader && m.department == AppTeams.newFamilyTeam)
                      .toList();

                  // 새가족(일반 회원)의 현재 주차를 출석 횟수 기준으로 계산
                  final newFamilyMembers = members
                      .where((m) => m.department == AppTeams.newFamilyTeam && m.role == UserRole.member)
                      .toList();
                  final weekOf = <String, int>{};
                  for (final m in newFamilyMembers) {
                    final count = attendance.where((a) => a.userId == m.uid && a.isPresent).length;
                    if (count >= 1 && count <= AppTeams.newFamilyMaxWeeks) {
                      weekOf[m.uid] = count;
                    }
                  }

                  return ListView(
                    padding: const EdgeInsets.all(12),
                    children: [
                      const Text('주차별 담당 리더', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      const SizedBox(height: 4),
                      const Text(
                        '새가족 개개인의 출석 횟수를 기준으로 한 진행 단계(1~3주차)마다\n담당 리더를 고정 배정합니다.',
                        style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: 12),
                      for (var week = 1; week <= AppTeams.newFamilyMaxWeeks; week++)
                        _WeekRotationCard(
                          week: week,
                          leaders: leaders,
                          rotation: _rotationForWeek(rotations, week),
                          matchedNames: [for (final m in newFamilyMembers) if (weekOf[m.uid] == week) m.name],
                          service: service,
                        ),
                    ],
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

class _WeekRotationCard extends StatelessWidget {
  final int week;
  final List<UserModel> leaders;
  final NewFamilyRotationModel? rotation;
  final List<String> matchedNames;
  final FirestoreService service;

  const _WeekRotationCard({
    required this.week,
    required this.leaders,
    required this.rotation,
    required this.matchedNames,
    required this.service,
  });

  Future<void> _showAssignDialog(BuildContext context) async {
    if (leaders.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('등록된 새가족팀 리더가 없습니다. 먼저 회원 관리에서 리더를 지정해 주세요.'), backgroundColor: AppColors.warning),
      );
      return;
    }
    UserModel? selected;
    for (final l in leaders) {
      if (l.uid == rotation?.leaderId) {
        selected = l;
        break;
      }
    }
    await showDialog<void>(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (dialogCtx, setState) => AlertDialog(
          title: Text('$week주차 담당 리더'),
          content: DropdownButtonFormField<UserModel>(
            initialValue: selected,
            decoration: const InputDecoration(labelText: '담당 리더'),
            items: leaders.map((l) => DropdownMenuItem(value: l, child: Text(l.name))).toList(),
            onChanged: (v) => setState(() => selected = v),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogCtx), child: const Text('취소')),
            ElevatedButton(
              onPressed: selected == null
                  ? null
                  : () async {
                      await service.setNewFamilyRotation(NewFamilyRotationModel(
                        id: rotation?.id ?? const Uuid().v4(),
                        weekNumber: week,
                        leaderId: selected!.uid,
                        leaderName: selected!.name,
                      ));
                      if (dialogCtx.mounted) Navigator.pop(dialogCtx);
                    },
              child: const Text('저장'),
            ),
          ],
        ),
      ),
    );
  }

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
                Expanded(
                  child: Text('$week주차', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                ),
                TextButton.icon(
                  onPressed: () => _showAssignDialog(context),
                  icon: const Icon(Icons.edit_outlined, size: 16),
                  label: Text(rotation == null ? '리더 배정' : '변경'),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.person_outline, size: 16, color: AppColors.textSecondary),
                const SizedBox(width: 4),
                Text(
                  rotation == null ? '담당 리더 미배정' : '담당 리더: ${rotation!.leaderName}',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: rotation == null ? AppColors.textSecondary : AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text('현재 이 주차에 해당하는 새가족', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            const SizedBox(height: 4),
            if (matchedNames.isEmpty)
              const Text('현재 이 주차에 해당하는 새가족이 없습니다.', style: TextStyle(fontSize: 12, color: AppColors.textSecondary))
            else
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: matchedNames
                    .map((name) => Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(name, style: const TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w600)),
                        ))
                    .toList(),
              ),
          ],
        ),
      ),
    );
  }
}
