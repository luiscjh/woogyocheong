import 'package:cloud_firestore/cloud_firestore.dart';

class VisitModel {
  final String id;
  final String userId;
  final String userName;
  final String phone;
  final String address;
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
    required this.address,
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
      address: data['address'] ?? '',
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
      'address': address,
      'requestDate': Timestamp.fromDate(requestDate),
      'preferredDate': preferredDate != null ? Timestamp.fromDate(preferredDate!) : null,
      'status': status,
      'reason': reason,
      'adminNote': adminNote,
    };
  }
}
