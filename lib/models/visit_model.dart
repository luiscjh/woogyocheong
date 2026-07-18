import 'package:cloud_firestore/cloud_firestore.dart';

class VisitModel {
  final String id;
  final String userId;
  final String userName;
  final String phone;
  final String deptName; // 부서명 (중팀)
  final String team;     // 팀 (소팀)
  final DateTime requestDate;
  final DateTime? preferredDate;
  final String status;
  final String? reason;
  final String? adminNote;

  VisitModel({
    required this.id,
    required this.userId,
    required this.userName,
    required this.phone,
    required this.deptName,
    required this.team,
    required this.requestDate,
    this.preferredDate,
    required this.status,
    this.reason,
    this.adminNote,
  });

  factory VisitModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return VisitModel(
      id: doc.id,
      userId: data['userId'] ?? '',
      userName: data['userName'] ?? '',
      phone: data['phone'] ?? '',
      deptName: data['deptName'] ?? '',
      team: data['team'] ?? '',
      requestDate: (data['requestDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      preferredDate: (data['preferredDate'] as Timestamp?)?.toDate(),
      status: data['status'] ?? 'pending',
      reason: data['reason'],
      adminNote: data['adminNote'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'userName': userName,
      'phone': phone,
      'deptName': deptName,
      'team': team,
      'requestDate': Timestamp.fromDate(requestDate),
      'preferredDate': preferredDate != null ? Timestamp.fromDate(preferredDate!) : null,
      'status': status,
      'reason': reason,
      'adminNote': adminNote,
    };
  }
}
