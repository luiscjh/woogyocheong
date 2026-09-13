import 'package:flutter/material.dart';
import '../../services/firestore_service.dart';
import '../../models/user_model.dart';
import '../../models/attendance_model.dart';
import '../../models/fee_model.dart';
import '../../models/visit_model.dart';
import '../../models/pastor_request_model.dart';
import '../../utils/constants.dart';

// 관리자용 전체 실적 요약 대시보드: 회원/출석/회비/심방 현황을 한눈에 확인
class StatsDashboardScreen extends StatelessWidget {
  const StatsDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final service = FirestoreService();
    final now = DateTime.now();

    return Scaffold(
      appBar: AppBar(title: const Text('실적 대시보드')),
      body: StreamBuilder<List<UserModel>>(
        stream: service.streamAllMembers(),
        builder: (ctx, memberSnap) {
          if (memberSnap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          // 목사님은 관리/실적 집계 대상에서 제외 (다른 관리 화면들과 동일한 기준)
          final members = (memberSnap.data ?? []).where((m) => !m.isPastor).toList();

          return StreamBuilder<List<AttendanceModel>>(
            stream: service.streamAllAttendance(),
            builder: (ctx, attSnap) {
              final attendance = attSnap.data ?? [];

              return StreamBuilder<List<FeeModel>>(
                stream: service.streamFeesByPeriod(now.year, now.month),
                builder: (ctx, feeSnap) {
                  final fees = feeSnap.data ?? [];

                  return StreamBuilder<List<VisitModel>>(
                    stream: service.streamAllVisits(),
                    builder: (ctx, visitSnap) {
                      final visits = visitSnap.data ?? [];

                      return StreamBuilder<List<PastorRequestModel>>(
                        stream: service.streamPastorRequests(),
                        builder: (ctx, reqSnap) {
                          final pastorRequests = reqSnap.data ?? [];
                          return _DashboardBody(
                            members: members,
                            attendance: attendance,
                            fees: fees,
                            visits: visits,
                            pastorRequests: pastorRequests,
                            now: now,
                          );
                        },
                      );
                    },
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

class _DashboardBody extends StatelessWidget {
  final List<UserModel> members;
  final List<AttendanceModel> attendance;
  final List<FeeModel> fees;
  final List<VisitModel> visits;
  final List<PastorRequestModel> pastorRequests;
  final DateTime now;

  const _DashboardBody({
    required this.members,
    required this.attendance,
    required this.fees,
    required this.visits,
    required this.pastorRequests,
    required this.now,
  });

  @override
  Widget build(BuildContext context) {
    final leaderCount = members.where((m) => m.isSmallLeader).length;
    final newThisMonth =
        members.where((m) => m.joinDate.year == now.year && m.joinDate.month == now.month).length;
    final newFamilyCount = members
        .where((m) => m.department == AppTeams.newFamilyTeam && m.role == UserRole.member)
        .length;

    // 회원마다 전체 회비 목록을 다시 훑지 않도록, 납부 완료한 회원 id를 한 번만 모아 둠
    final paidUserIds = {for (final f in fees) if (f.isPaid) f.userId};
    final paidCount = members.where((m) => paidUserIds.contains(m.uid)).length;
    final feeRate = members.isEmpty ? 0.0 : paidCount / members.length;

    final visitCounts = <String, int>{};
    for (final v in visits) {
      visitCounts[v.status] = (visitCounts[v.status] ?? 0) + 1;
    }
    final pendingRequestCount = pastorRequests.where((r) => r.status == 'pending').length;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Expanded(child: _StatCard(label: '전체 회원', value: '${members.length}명', color: AppColors.primary)),
            const SizedBox(width: 12),
            Expanded(child: _StatCard(label: '리더 이상', value: '$leaderCount명', color: Colors.deepPurple)),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _StatCard(label: '이번 달 신규가입', value: '$newThisMonth명', color: AppColors.success)),
            const SizedBox(width: 12),
            Expanded(child: _StatCard(label: '새가족', value: '$newFamilyCount명', color: Colors.orange)),
          ],
        ),
        const SizedBox(height: 20),
        const _SectionTitle('출석 추이 (최근 4주)'),
        _AttendanceTrendCard(attendance: attendance, totalMembers: members.length),
        const SizedBox(height: 20),
        _SectionTitle('이번 달 회비 납부 (${now.month}월)'),
        _ProgressCard(
          paid: paidCount,
          total: members.length,
          rate: feeRate,
        ),
        const SizedBox(height: 20),
        const _SectionTitle('심방 신청 현황'),
        _VisitStatusCard(counts: visitCounts, total: visits.length),
        if (pendingRequestCount > 0) ...[
          const SizedBox(height: 20),
          _PendingActionCard(
            icon: Icons.church_outlined,
            label: '처리 대기 중인 목사 권한 신청',
            count: pendingRequestCount,
          ),
        ],
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatCard({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
            const SizedBox(height: 6),
            Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color)),
          ],
        ),
      ),
    );
  }
}

// 출석 기록에 존재하는 날짜(대개 주일) 중 최근 4개를 뽑아 회원 대비 출석률을 막대로 표시
class _AttendanceTrendCard extends StatelessWidget {
  final List<AttendanceModel> attendance;
  final int totalMembers;

  const _AttendanceTrendCard({required this.attendance, required this.totalMembers});

  @override
  Widget build(BuildContext context) {
    // 날짜별 출석 인원을 한 번의 순회로 집계해 두고, 날짜(주)마다 전체 출석
    // 목록을 다시 훑지 않도록 함 (출석 기록이 많아질수록 느려지는 것을 방지)
    final presentCountByKey = <String, int>{};
    for (final a in attendance) {
      if (!a.isPresent) continue;
      final key = AttendanceModel.dateKey(a.date);
      presentCountByKey[key] = (presentCountByKey[key] ?? 0) + 1;
    }
    final dateKeys = attendance.map((a) => AttendanceModel.dateKey(a.date)).toSet().toList()..sort();
    final recentKeys = dateKeys.length > 4 ? dateKeys.sublist(dateKeys.length - 4) : dateKeys;

    if (recentKeys.isEmpty || totalMembers == 0) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Text('출석 기록이 아직 없습니다.', style: TextStyle(color: AppColors.textSecondary)),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            for (final key in recentKeys)
              _WeekBar(
                dateLabel: key.substring(5), // MM-dd
                rate: (presentCountByKey[key] ?? 0) / totalMembers,
              ),
          ],
        ),
      ),
    );
  }
}

class _WeekBar extends StatelessWidget {
  final String dateLabel;
  final double rate;

  const _WeekBar({required this.dateLabel, required this.rate});

  static const _barHeight = 100.0;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('${(rate * 100).round()}%', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        SizedBox(
          height: _barHeight,
          width: 28,
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              height: _barHeight * rate.clamp(0, 1),
              decoration: const BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.vertical(top: Radius.circular(4)),
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(dateLabel, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
      ],
    );
  }
}

class _ProgressCard extends StatelessWidget {
  final int paid;
  final int total;
  final double rate;

  const _ProgressCard({required this.paid, required this.total, required this.rate});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('$paid / $total명 납부', style: const TextStyle(fontWeight: FontWeight.w600)),
                Text('${(rate * 100).round()}%',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.success)),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: rate,
                minHeight: 10,
                backgroundColor: AppColors.success.withValues(alpha: 0.1),
                valueColor: const AlwaysStoppedAnimation(AppColors.success),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VisitStatusCard extends StatelessWidget {
  final Map<String, int> counts;
  final int total;

  const _VisitStatusCard({required this.counts, required this.total});

  @override
  Widget build(BuildContext context) {
    const statuses = [VisitStatus.pending, VisitStatus.confirmed, VisitStatus.completed, VisitStatus.cancelled];
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            for (final status in statuses)
              Column(
                children: [
                  Text('${counts[status] ?? 0}',
                      style: TextStyle(
                          fontSize: 20, fontWeight: FontWeight.bold, color: VisitStatus.color(status))),
                  const SizedBox(height: 4),
                  Text(VisitStatus.label(status), style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _PendingActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final int count;

  const _PendingActionCard({required this.icon, required this.label, required this.count});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppColors.warning.withValues(alpha: 0.08),
      child: ListTile(
        leading: Icon(icon, color: AppColors.warning),
        title: Text(label),
        trailing: Text('$count건', style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.warning)),
      ),
    );
  }
}
