import 'package:cloud_firestore/cloud_firestore.dart';

// 사역팀(콘텐츠팀 등) 회의 일정 기록: 일자/주제/논의 내용/정리 내용을 한 화면에서 관리
class MinistryMeetingModel {
  final String id;
  final String ministryTeam;
  final DateTime date;
  final String topic;
  final String discussion;
  final String summary;

  MinistryMeetingModel({
    required this.id,
    required this.ministryTeam,
    required this.date,
    required this.topic,
    required this.discussion,
    required this.summary,
  });

  factory MinistryMeetingModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return MinistryMeetingModel(
      id: doc.id,
      ministryTeam: data['ministryTeam'] ?? '',
      date: (data['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      topic: data['topic'] ?? '',
      discussion: data['discussion'] ?? '',
      summary: data['summary'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'ministryTeam': ministryTeam,
      'date': Timestamp.fromDate(date),
      'topic': topic,
      'discussion': discussion,
      'summary': summary,
    };
  }
}
