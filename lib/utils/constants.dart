import 'package:flutter/material.dart';

class AppColors {
  static const primary = Color(0xFF3F51B5);
  static const primaryDark = Color(0xFF303F9F);
  static const accent = Color(0xFFFF6F00);
  static const background = Color(0xFFF5F5F5);
  static const surface = Colors.white;
  static const error = Color(0xFFD32F2F);
  static const success = Color(0xFF388E3C);
  static const warning = Color(0xFFF57C00);
  static const textPrimary = Color(0xFF212121);
  static const textSecondary = Color(0xFF757575);
}

class AppStrings {
  static const appName = '우교청';
  static const attendance = '출석체크';
  static const fee = '회비납부';
  static const visit = '심방신청';
  static const members = '회원관리';
  static const banners = '배너관리';
  static const profile = '내 정보';
  static const adminDashboard = '관리자 대시보드';
}

class UserRole {
  static const member = 'member';
  static const smallLeader = 'small_leader';
  static const midLeader = 'mid_leader';
  static const executive = 'executive';
  static const admin = 'admin';

  static const Map<String, String> labels = {
    member: '팀원',
    smallLeader: '소팀장',
    midLeader: '중팀장',
    executive: '임원팀',
    admin: '관리자',
  };

  static String label(String role) => labels[role] ?? role;
}

class AppPermission {
  static const visitConfirm = 'visit_confirm';
}

class AppTeams {
  static const midTeams = ['A', 'B', 'C', 'D'];

  // X-0 = 중팀장 가상 소속팀, X-1~4 = 실제 소팀
  static const allDepts = [
    'A-0', 'A-1', 'A-2', 'A-3', 'A-4',
    'B-0', 'B-1', 'B-2', 'B-3', 'B-4',
    'C-0', 'C-1', 'C-2', 'C-3', 'C-4',
    'D-0', 'D-1', 'D-2', 'D-3', 'D-4',
  ];
  static const smallTeams = [
    'A-1', 'A-2', 'A-3', 'A-4',
    'B-1', 'B-2', 'B-3', 'B-4',
    'C-1', 'C-2', 'C-3', 'C-4',
    'D-1', 'D-2', 'D-3', 'D-4',
  ];

  static List<String> smallTeamsOf(String mid) =>
      smallTeams.where((t) => t.startsWith('$mid-')).toList();

  static String deptLabel(String dept) {
    if (dept.endsWith('-0')) return '$dept (중팀장)';
    return dept;
  }
}

class VisitStatus {
  static const pending = 'pending';
  static const confirmed = 'confirmed';
  static const completed = 'completed';
  static const cancelled = 'cancelled';

  static String label(String status) {
    switch (status) {
      case pending:
        return '대기중';
      case confirmed:
        return '확정';
      case completed:
        return '완료';
      case cancelled:
        return '취소';
      default:
        return '알 수 없음';
    }
  }

  static Color color(String status) {
    switch (status) {
      case pending:
        return AppColors.warning;
      case confirmed:
        return AppColors.primary;
      case completed:
        return AppColors.success;
      case cancelled:
        return AppColors.error;
      default:
        return AppColors.textSecondary;
    }
  }
}
