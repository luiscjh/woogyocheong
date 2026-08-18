import 'package:flutter/material.dart';
import '../utils/constants.dart';

// 조회 전용/이용 제한 등을 안내하는 공용 경고 배너
class WarningBanner extends StatelessWidget {
  final String message;
  final double? width;
  final double? fontSize;

  const WarningBanner(this.message, {super.key, this.width, this.fontSize});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        message,
        style: TextStyle(color: AppColors.warning, fontWeight: FontWeight.w600, fontSize: fontSize),
      ),
    );
  }
}
