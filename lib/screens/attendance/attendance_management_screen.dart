import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/firestore_service.dart';
import 'attendance_admin_screen.dart';
import 'attendance_screen.dart' show AttendanceDateHeader;

// 관리 탭 전용: 소팀장/중팀장 등에게 부여된 권한 범위 내에서 팀 출석 현황을 관리
// (개인 출석체크는 홈의 '출석' 탭에서 본인만 가능하고, 이 화면은 팀 전체 현황용)
class AttendanceManagementScreen extends StatefulWidget {
  const AttendanceManagementScreen({super.key});

  @override
  State<AttendanceManagementScreen> createState() => _AttendanceManagementScreenState();
}

class _AttendanceManagementScreenState extends State<AttendanceManagementScreen> {
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

    // 중팀장: 팀 전체 조회, 소팀장 이상: 다른 날짜(과거 주일 포함) 출결 수정 가능,
    // 사역팀장: 사역팀 소속 인원만 조회/수정
    Widget body;
    if (authProvider.isExecutive) {
      body = AttendanceAdminList(date: _selectedDate, service: _service, canEdit: true, canDownload: true);
    } else if (authProvider.isMidLeader) {
      body = AttendanceAdminList(date: _selectedDate, service: _service, canEdit: false, midTeamFilter: user.midTeam);
    } else if (authProvider.isSmallLeader) {
      body = AttendanceAdminList(date: _selectedDate, service: _service, canEdit: true, smallTeamFilter: user.department);
    } else {
      body = AttendanceAdminList(date: _selectedDate, service: _service, canEdit: true, ministryTeamFilter: user.ministryTeam);
    }

    return Scaffold(
      appBar: AppBar(title: const Text('출석 관리')),
      body: Column(
        children: [
          AttendanceDateHeader(date: _selectedDate, onTap: _pickDate),
          Expanded(child: body),
        ],
      ),
    );
  }
}
