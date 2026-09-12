import 'package:cloud_firestore/cloud_firestore.dart';

// 앱 전역 설정(단일 레코드). 현재는 기수 기반 이용 제한 기준만 담고 있음
//
// 기수는 매년 1씩 올라가고(숫자가 높을수록 나이가 어림) 허용 범위도 그대로
// 따라 밀려야 하므로, 관리자가 매년 min/max를 다시 입력하는 대신 "기준 연도에
// 어떤 범위였는지"만 한 번 등록해두면 이후 연도는 자동 계산한다.
// 예: 2026년 기준 24~30기로 등록 -> 2027년엔 자동으로 25~31기
class AppSettingsModel {
  final int baseYear;
  final int baseMinCohort;
  final int baseMaxCohort;

  const AppSettingsModel({
    required this.baseYear,
    required this.baseMinCohort,
    required this.baseMaxCohort,
  });

  int minAllowedCohortFor(int year) => baseMinCohort + (year - baseYear);
  int maxAllowedCohortFor(int year) => baseMaxCohort + (year - baseYear);

  int get minAllowedCohort => minAllowedCohortFor(DateTime.now().year);
  int get maxAllowedCohort => maxAllowedCohortFor(DateTime.now().year);

  factory AppSettingsModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    final now = DateTime.now().year;
    return AppSettingsModel(
      baseYear: data['baseYear'] ?? now,
      baseMinCohort: data['baseMinCohort'] ?? 1,
      baseMaxCohort: data['baseMaxCohort'] ?? 1,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'baseYear': baseYear,
      'baseMinCohort': baseMinCohort,
      'baseMaxCohort': baseMaxCohort,
    };
  }

  AppSettingsModel copyWith({int? baseYear, int? baseMinCohort, int? baseMaxCohort}) {
    return AppSettingsModel(
      baseYear: baseYear ?? this.baseYear,
      baseMinCohort: baseMinCohort ?? this.baseMinCohort,
      baseMaxCohort: baseMaxCohort ?? this.baseMaxCohort,
    );
  }
}
