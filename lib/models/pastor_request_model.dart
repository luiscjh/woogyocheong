import 'package:cloud_firestore/cloud_firestore.dart';

// 목사 권한 신청: 일반 회원이 관리자에게 목사 권한을 요청하고, 관리자가 승인/거절
class PastorRequestModel {
  final String id;
  final String userId;
  final String userName;
  final String email;
  final DateTime requestDate;
  final String status; // pending, approved, rejected

  PastorRequestModel({
    required this.id,
    required this.userId,
    required this.userName,
    required this.email,
    required this.requestDate,
    required this.status,
  });

  factory PastorRequestModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return PastorRequestModel(
      id: doc.id,
      userId: data['userId'] ?? '',
      userName: data['userName'] ?? '',
      email: data['email'] ?? '',
      requestDate: (data['requestDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      status: data['status'] ?? 'pending',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'userName': userName,
      'email': email,
      'requestDate': Timestamp.fromDate(requestDate),
      'status': status,
    };
  }
}
