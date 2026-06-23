import 'package:cloud_firestore/cloud_firestore.dart';

class FeeModel {
  final String id;
  final String userId;
  final String userName;
  final int year;
  final int month;
  final bool isPaid;
  final DateTime? paidDate;
  final String? note;

  FeeModel({
    required this.id,
    required this.userId,
    required this.userName,
    required this.year,
    required this.month,
    required this.isPaid,
    this.paidDate,
    this.note,
  });

  String get periodLabel => '$year년 ${month.toString().padLeft(2, '0')}월';

  factory FeeModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return FeeModel(
      id: doc.id,
      userId: data['userId'] ?? '',
      userName: data['userName'] ?? '',
      year: data['year'] ?? DateTime.now().year,
      month: data['month'] ?? DateTime.now().month,
      isPaid: data['isPaid'] ?? false,
      paidDate: (data['paidDate'] as Timestamp?)?.toDate(),
      note: data['note'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'userName': userName,
      'year': year,
      'month': month,
      'isPaid': isPaid,
      'paidDate': paidDate != null ? Timestamp.fromDate(paidDate!) : null,
      'note': note,
    };
  }
}
