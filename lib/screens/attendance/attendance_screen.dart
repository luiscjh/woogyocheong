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

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final user = authProvider.currentUser!;

    return Scaffold(
      body: Column(
        children: [
          _DateHeader(date: _selectedDate, onTap: _pickDate),
          Expanded(
            child: authProvider.isAdmin
                ? AttendanceAdminList(date: _selectedDate, service: _service)
                : _MemberAttendanceView(
                    userId: user.uid,
                    userName: user.name,
                    date: _selectedDate,
                    service: _service,
                  ),
          ),
        ],
      ),
    );
  }
}

class _DateHeader extends StatelessWidget {
  final DateTime date;
  final VoidCallback onTap;

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

  const _MemberAttendanceView({
    required this.userId,
    required this.userName,
    required this.date,
    required this.service,
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
