import 'package:cloud_firestore/cloud_firestore.dart';

class BannerModel {
  final String id;
  final String title;
  final String? description;
  final String imageUrl;
  final int order;
  final bool isActive;
  final DateTime createdAt;
  final DateTime? startDate;
  final DateTime? endDate;

  BannerModel({
    required this.id,
    required this.title,
    this.description,
    required this.imageUrl,
    required this.order,
    required this.isActive,
    required this.createdAt,
    this.startDate,
    this.endDate,
  });

  // 날짜 예약 범위 안에 있는지 (날짜 미설정 시 항상 통과)
  bool get isInSchedule {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    if (startDate != null && today.isBefore(startDate!)) return false;
    if (endDate != null && today.isAfter(endDate!)) return false;
    return true;
  }

  bool get isVisibleNow => isActive && isInSchedule;

  factory BannerModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return BannerModel(
      id: doc.id,
      title: data['title'] ?? '',
      description: data['description'],
      imageUrl: data['imageUrl'] ?? '',
      order: data['order'] ?? 0,
      isActive: data['isActive'] ?? true,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      startDate: (data['startDate'] as Timestamp?)?.toDate(),
      endDate: (data['endDate'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'description': description,
      'imageUrl': imageUrl,
      'order': order,
      'isActive': isActive,
      'createdAt': Timestamp.fromDate(createdAt),
      'startDate': startDate != null ? Timestamp.fromDate(startDate!) : null,
      'endDate': endDate != null ? Timestamp.fromDate(endDate!) : null,
    };
  }
}
