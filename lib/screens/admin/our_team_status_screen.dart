import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/firestore_service.dart';
import '../../models/user_model.dart';
import '../../models/attendance_model.dart';
import '../../utils/constants.dart';

// 중팀장/소팀장이 "청년부 현황"의 축소판으로, 본인 팀(중팀 또는 소팀) 범위의
// 출석률만 주별/월별/전체 기간별로 확인하는 화면. 전체 회원·회비·심방 등은
// 다루지 않고 출석률에 집중한다.
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
                totalMembers: teamMembers.length,
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
  final int totalMembers;
  final List<AttendanceModel> attendance;

  const _OurTeamStatusBody({
    required this.teamLabel,
    required this.totalMembers,
    required this.attendance,
  });

  @override
  Widget build(BuildContext context) {
    // 날짜(서비스 일자)별 출석 인원을 한 번의 순회로 집계 — 전원 결석한 날도
    // dayKeys에는 남아 0%로 표시되도록, isPresent와 무관하게 날짜 키를 모음
    final presentCountByDay = <String, int>{};
    final dayKeysSet = <String>{};
    for (final a in attendance) {
      final key = AttendanceModel.dateKey(a.date);
      dayKeysSet.add(key);
      if (a.isPresent) presentCountByDay[key] = (presentCountByDay[key] ?? 0) + 1;
    }
    final dayKeys = dayKeysSet.toList()..sort();

    if (totalMembers == 0 || dayKeys.isEmpty) {
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

    // 월별 집계: YYYY-MM 단위로 그룹
    final monthKeysOrdered = <String>[];
    final presentByMonth = <String, int>{};
    final dayCountByMonth = <String, int>{};
    for (final key in dayKeys) {
      final month = key.substring(0, 7);
      if (!monthKeysOrdered.contains(month)) monthKeysOrdered.add(month);
      presentByMonth[month] = (presentByMonth[month] ?? 0) + (presentCountByDay[key] ?? 0);
      dayCountByMonth[month] = (dayCountByMonth[month] ?? 0) + 1;
    }

    // 전체 기간 집계
    final totalPresent = presentCountByDay.values.fold(0, (sum, v) => sum + v);
    final overallRate = totalPresent / (totalMembers * dayKeys.length);

    final recentWeeks = dayKeys.length > 8 ? dayKeys.sublist(dayKeys.length - 8) : dayKeys;
    final recentMonths =
        monthKeysOrdered.length > 6 ? monthKeysOrdered.sublist(monthKeysOrdered.length - 6) : monthKeysOrdered;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _SectionTitle(teamLabel),
        const SizedBox(height: 4),
        Text('전체 팀원 $totalMembers명', style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
        const SizedBox(height: 20),
        const _SectionTitle('주별 출석률'),
        _RateTrendCard(
          bars: [
            for (final key in recentWeeks)
              _RateBar(label: key.substring(5), rate: (presentCountByDay[key] ?? 0) / totalMembers),
          ],
        ),
        const SizedBox(height: 20),
        const _SectionTitle('월별 출석률'),
        _RateTrendCard(
          bars: [
            for (final month in recentMonths)
              _RateBar(
                label: month.substring(5),
                rate: (presentByMonth[month] ?? 0) / (totalMembers * (dayCountByMonth[month] ?? 1)),
              ),
          ],
        ),
        const SizedBox(height: 20),
        const _SectionTitle('전체 기간 출석률'),
        _OverallRateCard(
          rate: overallRate,
          serviceDayCount: dayKeys.length,
          firstDate: dayKeys.first,
          lastDate: dayKeys.last,
        ),
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

class _RateBar {
  final String label;
  final double rate;
  const _RateBar({required this.label, required this.rate});
}

class _RateTrendCard extends StatelessWidget {
  final List<_RateBar> bars;
  const _RateTrendCard({required this.bars});

  static const _barHeight = 100.0;

  @override
  Widget build(BuildContext context) {
    if (bars.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Text('표시할 기록이 없습니다.', style: TextStyle(color: AppColors.textSecondary)),
        ),
      );
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (final bar in bars)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('${(bar.rate * 100).round()}%',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      SizedBox(
                        height: _barHeight,
                        width: 28,
                        child: Align(
                          alignment: Alignment.bottomCenter,
                          child: Container(
                            height: _barHeight * bar.rate.clamp(0, 1),
                            decoration: const BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.vertical(top: Radius.circular(4)),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(bar.label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OverallRateCard extends StatelessWidget {
  final double rate;
  final int serviceDayCount;
  final String firstDate;
  final String lastDate;

  const _OverallRateCard({
    required this.rate,
    required this.serviceDayCount,
    required this.firstDate,
    required this.lastDate,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${(rate * 100).round()}%',
                style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: AppColors.primary)),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: rate.clamp(0, 1),
                minHeight: 10,
                backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                valueColor: const AlwaysStoppedAnimation(AppColors.primary),
              ),
            ),
            const SizedBox(height: 12),
            Text('총 $serviceDayCount회 출석 체크 · $firstDate ~ $lastDate',
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }
}
