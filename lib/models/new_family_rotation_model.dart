import 'package:cloud_firestore/cloud_firestore.dart';

// 새가족팀장이 등록하는 '주차(1~3)별 담당 새가족팀 리더' 고정 배정
// 여기서 주차는 특정 일요일 날짜가 아니라, 새가족 개개인의 출석 횟수 기준
// 온보딩 진행 단계(1주차~3주차)를 의미함
class NewFamilyRotationModel {
  final String id;
  final int weekNumber; // 1 ~ AppTeams.newFamilyMaxWeeks
  final String leaderId;
  final String leaderName;

  NewFamilyRotationModel({
    required this.id,
    required this.weekNumber,
    required this.leaderId,
    required this.leaderName,
  });

  factory NewFamilyRotationModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return NewFamilyRotationModel(
      id: doc.id,
      weekNumber: data['weekNumber'] ?? 1,
      leaderId: data['leaderId'] ?? '',
      leaderName: data['leaderName'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'weekNumber': weekNumber,
      'leaderId': leaderId,
      'leaderName': leaderName,
    };
  }
}
