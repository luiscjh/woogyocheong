import 'package:cloud_firestore/cloud_firestore.dart';

class AttendanceModel {
  final String id;
  final String userId;
  final String userName;
  final DateTime date;
  final bool isPresent;
  final String? note;

  AttendanceModel({
    required this.id,
    required this.userId,
    required this.userName,
    required this.date,
    required this.isPresent,
    this.note,
  });

  factory AttendanceModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return AttendanceModel(
      id: doc.id,
      userId: data['userId'] ?? '',
      userName: data['userName'] ?? '',
      date: (data['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isPresent: data['isPresent'] ?? false,
      note: data['note'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'userName': userName,
      'date': Timestamp.fromDate(date),
      'isPresent': isPresent,
      'note': note,
    };
  }

  // 주차별 출석을 위한 날짜 키 (예: "2024-W01")
  static String weekKey(DateTime date) {
    final week = ((date.day - 1) / 7).floor() + 1;
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-W$week';
  }

  // 날짜 문자열 키 (년-월-일)
  static String dateKey(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  // 회원별 출석("참석") 횟수를 한 번의 순회로 집계. 여러 화면에서 회원마다 전체
  // 출석 목록을 반복 조회(O(n²))하는 대신, 이 결과(userId → 횟수)에서 조회하면
  // 됨(O(n))
  static Map<String, int> presentCountsByUser(List<AttendanceModel> attendance) {
    final counts = <String, int>{};
    for (final a in attendance) {
      if (a.isPresent) counts[a.userId] = (counts[a.userId] ?? 0) + 1;
    }
    return counts;
  }
}
