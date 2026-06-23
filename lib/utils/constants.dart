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
  static const admin = 'admin';
  static const member = 'member';
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
