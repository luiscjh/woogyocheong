import 'package:cloud_firestore/cloud_firestore.dart';

// 앱 전역 설정(단일 레코드). 현재는 기수 기반 이용 제한 기준만 담고 있음
class AppSettingsModel {
  // 관리자가 직접 지정하는 허용 기수 범위 [minAllowedCohort, maxAllowedCohort]
  final int minAllowedCohort;
  final int maxAllowedCohort;

  const AppSettingsModel({
    required this.minAllowedCohort,
    required this.maxAllowedCohort,
  });

  factory AppSettingsModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return AppSettingsModel(
      minAllowedCohort: data['minAllowedCohort'] ?? 1,
      maxAllowedCohort: data['maxAllowedCohort'] ?? 1,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'minAllowedCohort': minAllowedCohort,
      'maxAllowedCohort': maxAllowedCohort,
    };
  }

  AppSettingsModel copyWith({int? minAllowedCohort, int? maxAllowedCohort}) {
    return AppSettingsModel(
      minAllowedCohort: minAllowedCohort ?? this.minAllowedCohort,
      maxAllowedCohort: maxAllowedCohort ?? this.maxAllowedCohort,
    );
  }
}
