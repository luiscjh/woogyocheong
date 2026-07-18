import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/auth_provider.dart';
import '../../services/firestore_service.dart';
import '../../models/attendance_model.dart';
import '../../utils/constants.dart';
import 'attendance_admin_screen.dart';

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  final _service = FirestoreService();
  DateTime _selectedDate = _nearestSunday();

  static DateTime _nearestSunday() {
    final now = DateTime.now();
    final daysUntilSunday = (7 - now.weekday) % 7;
    return now.weekday == 7
        ? DateTime(now.year, now.month, now.day)
        : DateTime(now.year, now.month, now.day - (7 - daysUntilSunday));
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      selectableDayPredicate: (d) => d.weekday == DateTime.sunday,
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  // 출석체크(마킹)는 무조건 일요일 당일에만 가능 (조회는 언제든 가능)
  bool get _isTodaySunday => DateTime.now().weekday == DateTime.sunday;

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final user = authProvider.currentUser!;
    final canEditToday = _isTodaySunday;
    // 일반 회원(팀원)은 날짜를 바꿀 수 없고, 항상 오늘 하루만 체크 가능
    final isPlainMember = !authProvider.isSmallLeader;
    final today = DateTime.now();
    final memberDate = DateTime(today.year, today.month, today.day);

    // 중팀장 이상: 팀 전체 조회, 소팀장: 본인 소팀 수정, 팀원: 본인만(오늘만)
    Widget body;
    if (authProvider.isExecutive) {
      body = AttendanceAdminList(date: _selectedDate, service: _service, canEdit: canEditToday, canDownload: true);
    } else if (authProvider.isMidLeader) {
      body = AttendanceAdminList(date: _selectedDate, service: _service, canEdit: false, midTeamFilter: user.midTeam);
    } else if (authProvider.isSmallLeader) {
      body = AttendanceAdminList(date: _selectedDate, service: _service, canEdit: canEditToday, smallTeamFilter: user.department);
    } else {
      body = _MemberAttendanceView(userId: user.uid, userName: user.name, date: memberDate, service: _service, canEdit: canEditToday);
    }

    return Scaffold(
      body: Column(
        children: [
          _DateHeader(
            date: isPlainMember ? memberDate : _selectedDate,
            onTap: isPlainMember ? null : _pickDate,
          ),
          Expanded(child: body),
        ],
      ),
    );
  }
}

class _DateHeader extends StatelessWidget {
  final DateTime date;
  final VoidCallback? onTap;

  const _DateHeader({required this.date, required this.onTap});

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

  const _MemberAttendanceView({
    required this.userId,
    required this.userName,
    required this.date,
    required this.service,
    required this.canEdit,
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
                  child: const Text(
                    '출석체크는 주일(일요일)에만 가능합니다.',
                    style: TextStyle(color: AppColors.warning, fontWeight: FontWeight.w600),
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
