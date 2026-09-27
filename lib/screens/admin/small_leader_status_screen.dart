import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/firestore_service.dart';
import '../../models/user_model.dart';
import '../../models/attendance_model.dart';
import '../../providers/auth_provider.dart';
import '../../utils/constants.dart';

class SmallLeaderStatusScreen extends StatelessWidget {
  const SmallLeaderStatusScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final currentUser = authProvider.currentUser!;
    final service = FirestoreService();

    return Scaffold(
      appBar: AppBar(title: const Text('소팀장 현황')),
      body: StreamBuilder<List<UserModel>>(
        stream: service.streamAllMembers(),
        builder: (ctx, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final all = snap.data ?? [];
          var leaders = all.where((m) => m.role == UserRole.smallLeader).toList();
          if (!authProvider.isExecutive) {
            leaders = leaders.where((m) => m.midTeam == currentUser.midTeam).toList();
          }

          if (leaders.isEmpty) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.badge_outlined, size: 64, color: Colors.grey),
                  SizedBox(height: 12),
                  Text('현재 소팀장 역할을 맡고 있는 회원이 없습니다.'),
                ],
              ),
            );
          }

          final memberCounts = <String, int>{};
          for (final m in all) {
            if (m.role == UserRole.member) {
              memberCounts[m.department] = (memberCounts[m.department] ?? 0) + 1;
            }
          }

          leaders.sort((a, b) => a.department.compareTo(b.department));
          final grouped = <String, List<UserModel>>{};
          for (final l in leaders) {
            grouped.putIfAbsent(l.midTeam, () => []).add(l);
          }
          final midKeys = grouped.keys.toList()..sort();

          return StreamBuilder<List<AttendanceModel>>(
            stream: service.streamAllAttendance(),
            builder: (ctx, attSnap) {
              final attendance = attSnap.data ?? [];
              // 회원 uid → 소속 소팀(department) 매핑 후, 소팀별로 출석 기록을 미리 묶어둠
              final deptByUserId = {for (final m in all) m.uid: m.department};
              final attendanceByDept = <String, List<AttendanceModel>>{};
              for (final a in attendance) {
                final dept = deptByUserId[a.userId];
                if (dept != null) attendanceByDept.putIfAbsent(dept, () => []).add(a);
              }

              return ListView(
                padding: const EdgeInsets.all(12),
                children: [
                  for (final mid in midKeys) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                      child: Text(
                        AppTeams.midTeams.contains(mid) ? '$mid중팀' : mid,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.primary),
                      ),
                    ),
                    ...grouped[mid]!.map((leader) {
                      // 소팀 전체 기간 출석률: 해당 소팀에 기록된 서비스 일자 대비
                      // 개인별 출석 일수 비율 — 출석 기록이 쌓일수록 자동으로 반영됨
                      final deptMembers = all.where((m) => m.department == leader.department && !m.isPastor).toList()
                        ..sort((a, b) => a.name.compareTo(b.name));
                      final deptAttendance = attendanceByDept[leader.department] ?? const <AttendanceModel>[];
                      final dayKeys = <String>{for (final a in deptAttendance) AttendanceModel.dateKey(a.date)};
                      final presentByUser = <String, int>{};
                      for (final a in deptAttendance) {
                        if (a.isPresent) presentByUser[a.userId] = (presentByUser[a.userId] ?? 0) + 1;
                      }

                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ExpansionTile(
                          leading: const CircleAvatar(
                            backgroundColor: AppColors.primary,
                            child: Icon(Icons.badge, color: Colors.white, size: 20),
                          ),
                          title: Text(leader.name),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                  '${AppTeams.deptLabel(leader.department)} · 팀원 ${memberCounts[leader.department] ?? 0}명'),
                              Text(leader.phone, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                            ],
                          ),
                          children: [
                            if (deptMembers.isEmpty)
                              const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                child: Text('팀원이 없습니다.', style: TextStyle(color: AppColors.textSecondary)),
                              )
                            else
                              for (final m in deptMembers)
                                ListTile(
                                  dense: true,
                                  title: Text(m.name),
                                  trailing: Text(
                                    dayKeys.isEmpty
                                        ? '기록 없음'
                                        : '${(((presentByUser[m.uid] ?? 0) / dayKeys.length) * 100).round()}%',
                                    style: const TextStyle(fontWeight: FontWeight.w600),
                                  ),
                                ),
                          ],
                        ),
                      );
                    }),
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
