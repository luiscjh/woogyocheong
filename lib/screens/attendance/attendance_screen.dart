import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/auth_provider.dart';
import '../../services/firestore_service.dart';
import '../../models/attendance_model.dart';
import '../../utils/constants.dart';

// 홈 하단 탭의 '출석' 화면: 역할과 무관하게 본인의 출석 여부만 확인/체크할 수 있음.
// 팀 전체 출석 관리는 관리 탭의 '출석 관리'(AttendanceManagementScreen)에서 별도로 제공됨.
class AttendanceScreen extends StatelessWidget {
  const AttendanceScreen({super.key});

  // 출석체크(마킹)는 무조건 일요일 당일에만 가능 (조회는 언제든 가능)
  static bool get _isTodaySunday => DateTime.now().weekday == DateTime.sunday;

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final user = authProvider.currentUser!;
    final restricted = authProvider.isCohortRestricted;
    final service = FirestoreService();
    final today = DateTime.now();
    final memberDate = DateTime(today.year, today.month, today.day);

    return Scaffold(
      body: Column(
        children: [
          AttendanceDateHeader(date: memberDate, onTap: null),
          Expanded(
            child: _MemberAttendanceView(
              userId: user.uid,
              userName: user.name,
              date: memberDate,
              service: service,
              canEdit: _isTodaySunday && !restricted,
              isCohortRestricted: restricted,
            ),
          ),
        ],
      ),
    );
  }
}

class AttendanceDateHeader extends StatelessWidget {
  final DateTime date;
  final VoidCallback? onTap;

  const AttendanceDateHeader({super.key, required this.date, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.primary,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              DateFormat('yyyy년 MM월 dd일 (E)', 'ko').format(date),
              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
          if (onTap != null)
            TextButton.icon(
              onPressed: onTap,
              icon: const Icon(Icons.calendar_today, color: Colors.white70, size: 16),
              label: const Text('날짜 변경', style: TextStyle(color: Colors.white70)),
            ),
        ],
      ),
    );
  }
}

class _MemberAttendanceView extends StatelessWidget {
  final String userId;
  final String userName;
  final DateTime date;
  final FirestoreService service;
  final bool canEdit;
  final bool isCohortRestricted;

  const _MemberAttendanceView({
    required this.userId,
    required this.userName,
    required this.date,
    required this.service,
    required this.canEdit,
    required this.isCohortRestricted,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AttendanceModel?>(
      future: service.getAttendance(userId, date),
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final isPresent = snap.data?.isPresent ?? false;
        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const SizedBox(height: 32),
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isPresent ? AppColors.success : Colors.grey[200],
                ),
                child: Icon(
                  isPresent ? Icons.check : Icons.close,
                  size: 70,
                  color: isPresent ? Colors.white : Colors.grey,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                isPresent ? '출석 완료' : '미출석',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: isPresent ? AppColors.success : AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                DateFormat('yyyy년 MM월 dd일', 'ko').format(date),
                style: const TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 40),
              if (canEdit)
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _setAttendance(context, true),
                        icon: const Icon(Icons.check),
                        label: const Text('출석'),
                        style: ElevatedButton.styleFrom(backgroundColor: AppColors.success),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _setAttendance(context, false),
                        icon: const Icon(Icons.close),
                        label: const Text('결석'),
                        style: OutlinedButton.styleFrom(foregroundColor: AppColors.error),
                      ),
                    ),
                  ],
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    isCohortRestricted
                        ? '허용된 기수 범위가 아니라 조회만 가능합니다.'
                        : '출석체크는 주일(일요일)에만 가능합니다.',
                    style: const TextStyle(color: AppColors.warning, fontWeight: FontWeight.w600),
                  ),
                ),
              const SizedBox(height: 40),
              _AttendanceHistory(userId: userId, service: service),
            ],
          ),
        );
      },
    );
  }

  Future<void> _setAttendance(BuildContext context, bool isPresent) async {
    await service.setAttendance(
      userId: userId,
      userName: userName,
      date: date,
      isPresent: isPresent,
    );
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isPresent ? '출석 처리되었습니다.' : '결석 처리되었습니다.'),
          backgroundColor: isPresent ? AppColors.success : AppColors.warning,
        ),
      );
    }
  }
}

class _AttendanceHistory extends StatelessWidget {
  final String userId;
  final FirestoreService service;

  const _AttendanceHistory({required this.userId, required this.service});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<AttendanceModel>>(
      stream: service.streamUserAttendance(userId),
      builder: (ctx, snap) {
        final records = snap.data ?? [];
        if (records.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('출석 기록', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ...records.take(10).map((r) => ListTile(
              leading: Icon(
                r.isPresent ? Icons.check_circle : Icons.cancel,
                color: r.isPresent ? AppColors.success : AppColors.error,
              ),
              title: Text(DateFormat('yyyy년 MM월 dd일', 'ko').format(r.date)),
              trailing: Text(r.isPresent ? '출석' : '결석'),
              dense: true,
            )),
          ],
        );
      },
    );
  }
}
