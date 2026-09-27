import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/firestore_service.dart';
import '../../models/user_model.dart';
import '../../models/attendance_model.dart';
import '../../utils/constants.dart';

// 중팀장/소팀장이 "청년부 현황"의 축소판으로, 본인 팀(중팀 또는 소팀) 범위의
// 팀원 개개인의 전체 기간 출석률을 확인하는 화면. 전체 회원·회비·심방 등은
// 다루지 않고 개인별 출석률에 집중한다.
class OurTeamStatusScreen extends StatelessWidget {
  const OurTeamStatusScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final currentUser = context.watch<AuthProvider>().currentUser!;
    final isMidLeaderView = currentUser.role == UserRole.midLeader;
    final teamLabel = currentUser.department == AppTeams.newFamilyTeam
        ? '새가족팀'
        : isMidLeaderView
            ? '${currentUser.midTeam}중팀'
            : '${currentUser.department}팀';
    final service = FirestoreService();

    return Scaffold(
      appBar: AppBar(title: const Text('우리팀 현황')),
      body: StreamBuilder<List<UserModel>>(
        stream: service.streamAllMembers(),
        builder: (ctx, memberSnap) {
          if (memberSnap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final teamMembers = (memberSnap.data ?? []).where((m) {
            if (m.isPastor) return false;
            return isMidLeaderView ? m.midTeam == currentUser.midTeam : m.department == currentUser.department;
          }).toList();
          final teamUserIds = teamMembers.map((m) => m.uid).toSet();

          return StreamBuilder<List<AttendanceModel>>(
            stream: service.streamAllAttendance(),
            builder: (ctx, attSnap) {
              final teamAttendance =
                  (attSnap.data ?? []).where((a) => teamUserIds.contains(a.userId)).toList();
              return _OurTeamStatusBody(
                teamLabel: teamLabel,
                members: teamMembers,
                attendance: teamAttendance,
              );
            },
          );
        },
      ),
    );
  }
}

class _OurTeamStatusBody extends StatelessWidget {
  final String teamLabel;
  final List<UserModel> members;
  final List<AttendanceModel> attendance;

  const _OurTeamStatusBody({
    required this.teamLabel,
    required this.members,
    required this.attendance,
  });

  @override
  Widget build(BuildContext context) {
    final totalMembers = members.length;
    // 팀 전체 서비스 일자(dayKeys)와 회원별 출석 일수를 한 번의 순회로 집계 —
    // 출석 기록이 새로 쌓일 때마다 실시간 스트림으로 자동 반영됨
    final dayKeysSet = <String>{};
    final presentCountByUser = <String, int>{};
    for (final a in attendance) {
      dayKeysSet.add(AttendanceModel.dateKey(a.date));
      if (a.isPresent) presentCountByUser[a.userId] = (presentCountByUser[a.userId] ?? 0) + 1;
    }
    final serviceDayCount = dayKeysSet.length;

    if (totalMembers == 0 || serviceDayCount == 0) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _SectionTitle(teamLabel),
          const SizedBox(height: 40),
          const Center(
            child: Text('아직 출석 기록이 없습니다.', style: TextStyle(color: AppColors.textSecondary)),
          ),
        ],
      );
    }

    // 팀 전체 서비스 일수 대비 본인 출석 일수 비율 — 출석률이 낮은 순으로 정렬해
    // 관리가 필요한 팀원을 먼저 확인할 수 있게 함
    final memberRows = members.map((m) {
      final rate = (presentCountByUser[m.uid] ?? 0) / serviceDayCount;
      return _MemberRateRow(name: m.name, rate: rate);
    }).toList()
      ..sort((a, b) {
        final cmp = a.rate.compareTo(b.rate);
        return cmp != 0 ? cmp : a.name.compareTo(b.name);
      });

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _SectionTitle(teamLabel),
        const SizedBox(height: 4),
        Text('전체 팀원 $totalMembers명 · 총 $serviceDayCount회 출석 체크',
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
        const SizedBox(height: 20),
        for (final row in memberRows) _MemberRateTile(name: row.name, rate: row.rate),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle(this.title);

  @override
  Widget build(BuildContext context) {
    return Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold));
  }
}

class _MemberRateRow {
  final String name;
  final double rate;
  const _MemberRateRow({required this.name, required this.rate});
}

class _MemberRateTile extends StatelessWidget {
  final String name;
  final double rate;
  const _MemberRateTile({required this.name, required this.rate});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                Text(
                  '${(rate * 100).round()}%',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.primary),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: rate.clamp(0, 1),
                minHeight: 8,
                backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                valueColor: const AlwaysStoppedAnimation(AppColors.primary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
