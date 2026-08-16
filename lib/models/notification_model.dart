import 'package:cloud_firestore/cloud_firestore.dart';

// 특정 이벤트(심방/목사 권한 신청 상태 변경, 새가족 로테이션 배정,
// 소팀/중팀 배정 변경 등)가 발생했을 때 해당 사용자에게 남기는 알림.
// 지금은 인앱 알림함으로 동작하고, 추후 Firebase 연결 시 이 레코드
// 생성 시점에 FCM 푸시를 함께 보내도록 확장 가능
class NotificationModel {
  final String id;
  final String userId;
  final String title;
  final String body;
  final String type; // visit / pastorRequest / newFamilyRotation / teamAssignment
  final DateTime createdAt;
  final bool isRead;

  NotificationModel({
    required this.id,
    required this.userId,
    required this.title,
    required this.body,
    required this.type,
    required this.createdAt,
    this.isRead = false,
  });

  factory NotificationModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return NotificationModel(
      id: doc.id,
      userId: data['userId'] ?? '',
      title: data['title'] ?? '',
      body: data['body'] ?? '',
      type: data['type'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isRead: data['isRead'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'title': title,
      'body': body,
      'type': type,
      'createdAt': Timestamp.fromDate(createdAt),
      'isRead': isRead,
    };
  }

  NotificationModel copyWith({bool? isRead}) {
    return NotificationModel(
      id: id,
      userId: userId,
      title: title,
      body: body,
      type: type,
      createdAt: createdAt,
      isRead: isRead ?? this.isRead,
    );
  }
}
