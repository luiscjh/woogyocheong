import 'package:cloud_firestore/cloud_firestore.dart';

// 관리자가 사전에 열어 둔 심방 가능 시간대
class VisitSlotModel {
  final String id;
  final DateTime dateTime;

  VisitSlotModel({required this.id, required this.dateTime});

  factory VisitSlotModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return VisitSlotModel(
      id: doc.id,
      dateTime: (data['dateTime'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {'dateTime': Timestamp.fromDate(dateTime)};
  }
}
