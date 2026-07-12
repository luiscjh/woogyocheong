import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/firestore_service.dart';
import '../../models/attendance_model.dart';
import '../../models/user_model.dart';
import '../../utils/constants.dart';
import '../../utils/csv_download.dart';

class AttendanceAdminList extends StatelessWidget {
  final DateTime date;
  final FirestoreService service;
  final bool canEdit;
  final String? smallTeamFilter; // 소팀장: 본인 소팀만
  final String? midTeamFilter;   // 중팀장: 본인 중팀만
  final bool canDownload;        // 임원팀/관리자만 명단 다운로드 가능

  const AttendanceAdminList({
    super.key,
    required this.date,
    required this.service,
    this.canEdit = true,
    this.smallTeamFilter,
    this.midTeamFilter,
    this.canDownload = false,
  });

  void _downloadCsv(List<UserModel> members, Map<String, AttendanceModel> attendances) {
    final buffer = StringBuffer('이름,부서,상태\n');
    for (final m in members) {
      final isPresent = attendances[m.uid]?.isPresent ?? false;
      buffer.writeln('${m.name},${m.department},${isPresent ? '출석' : '결석'}');
    }
    final filename = '출석부_${DateFormat('yyyyMMdd').format(date)}.csv';
    downloadCsv(filename, buffer.toString());
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<UserModel>>(
      stream: service.streamAllMembers(),
      builder: (ctx, memberSnap) {
        return StreamBuilder<List<AttendanceModel>>(
          stream: service.streamAttendanceByDate(date),
          builder: (ctx, attSnap) {
            if (memberSnap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            var members = memberSnap.data ?? [];
            if (smallTeamFilter != null) {
              members = members.where((m) => m.department == smallTeamFilter).toList();
            } else if (midTeamFilter != null) {
              members = members.where((m) => m.midTeam == midTeamFilter).toList();
            }
            final Map<String, AttendanceModel> attendances = {
              for (final a in attSnap.data ?? []) a.userId: a
            };

            final presentCount = members.where((m) => attendances[m.uid]?.isPresent == true).length;

            return Column(
              children: [
                _SummaryBar(
                  total: members.length,
                  present: presentCount,
                  onDownload: canDownload ? () => _downloadCsv(members, attendances) : null,
                ),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    itemCount: members.length,
                    itemBuilder: (ctx, i) {
                      final member = members[i];
                      final att = attendances[member.uid];
                      final isPresent = att?.isPresent ?? false;
                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: isPresent ? AppColors.success : Colors.grey[300],
                            child: Text(
                              member.name.isNotEmpty ? member.name[0] : '?',
                              style: TextStyle(
                                color: isPresent ? Colors.white : AppColors.textSecondary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          title: Text(member.name),
                          subtitle: Text(member.department),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _AttendanceChip(isPresent: isPresent),
                              if (canEdit) ...[
                                const SizedBox(width: 8),
                                PopupMenuButton<bool>(
                                  onSelected: (v) => service.setAttendance(
                                    userId: member.uid,
                                    userName: member.name,
                                    date: date,
                                    isPresent: v,
                                  ),
                                  itemBuilder: (_) => [
                                    const PopupMenuItem(value: true, child: Text('출석')),
                                    const PopupMenuItem(value: false, child: Text('결석')),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _SummaryBar extends StatelessWidget {
  final int total;
  final int present;
  final VoidCallback? onDownload;

  const _SummaryBar({required this.total, required this.present, this.onDownload});

  @override
  Widget build(BuildContext context) {
    final absent = total - present;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      color: Colors.white,
      child: Row(
        children: [
          _Stat(label: '전체', value: total, color: AppColors.primary),
          const SizedBox(width: 24),
          _Stat(label: '출석', value: present, color: AppColors.success),
          const SizedBox(width: 24),
          _Stat(label: '결석', value: absent, color: AppColors.error),
          const Spacer(),
          if (total > 0)
            Text(
              '${(present / total * 100).toStringAsFixed(0)}%',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.primary),
            ),
          if (onDownload != null)
            IconButton(
              icon: const Icon(Icons.download, color: AppColors.primary),
              tooltip: '출석 명단 다운로드',
              onPressed: onDownload,
            ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final int value;
  final Color color;

  const _Stat({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text('$value', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
        Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
      ],
    );
  }
}

class _AttendanceChip extends StatelessWidget {
  final bool isPresent;

  const _AttendanceChip({required this.isPresent});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isPresent ? AppColors.success.withValues(alpha: 0.1) : AppColors.error.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        isPresent ? '출석' : '결석',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: isPresent ? AppColors.success : AppColors.error,
        ),
      ),
    );
  }
}
