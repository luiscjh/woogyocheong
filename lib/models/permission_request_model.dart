import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/constants.dart';

// 권한 신청 종류: 회원/리더가 관리자에게 요청할 수 있는 역할·소속
class PermissionRequestType {
  static const pastor = 'pastor';
  static const executive = 'executive';
  static const midLeader = 'midLeader';
  static const smallLeader = 'smallLeader';
  static const ministryTeam = 'ministryTeam';

  static const Map<String, String> labels = {
    pastor: '목사님',
    executive: '임원팀',
    midLeader: '중팀장',
    smallLeader: '소팀장',
    ministryTeam: '사역팀',
  };

  static String label(String type) => labels[type] ?? type;
}

// 권한 신청: 회원/리더가 관리자에게 더 높은 역할이나 사역팀 소속을 요청하고,
// 관리자가 한 화면에서 통합해서 승인/거절
class PermissionRequestModel {
  final String id;
  final String userId;
  final String userName;
  final String email;
  final DateTime requestDate;
  final String status; // pending, approved, rejected
  final String requestType; // PermissionRequestType.*
  // requestType이 midLeader/smallLeader일 때 요청 대상 소속팀(예: 'A-0', 'B-1').
  // executive/pastor는 소속이 고정이라 필요 없음
  final String? targetDepartment;
  // requestType이 ministryTeam일 때 요청 대상 사역팀(예: '콘텐츠팀')
  final String? targetMinistryTeam;

  PermissionRequestModel({
    required this.id,
    required this.userId,
    required this.userName,
    required this.email,
    required this.requestDate,
    required this.status,
    required this.requestType,
    this.targetDepartment,
    this.targetMinistryTeam,
  });

  // 신청 대상을 한 줄로 표시: "중팀장 (A-0 (중팀장))", "사역팀 (콘텐츠팀)" 등
  String get targetLabel {
    switch (requestType) {
      case PermissionRequestType.midLeader:
      case PermissionRequestType.smallLeader:
        final dept = targetDepartment;
        return dept == null
            ? PermissionRequestType.label(requestType)
            : '${PermissionRequestType.label(requestType)} (${AppTeams.deptLabel(dept)})';
      case PermissionRequestType.ministryTeam:
        final team = targetMinistryTeam;
        return team == null ? '사역팀' : '사역팀 ($team)';
      default:
        return PermissionRequestType.label(requestType);
    }
  }

  factory PermissionRequestModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return PermissionRequestModel(
      id: doc.id,
      userId: data['userId'] ?? '',
      userName: data['userName'] ?? '',
      email: data['email'] ?? '',
      requestDate: (data['requestDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      status: data['status'] ?? 'pending',
      requestType: data['requestType'] ?? PermissionRequestType.pastor,
      targetDepartment: data['targetDepartment'],
      targetMinistryTeam: data['targetMinistryTeam'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'userName': userName,
      'email': email,
      'requestDate': Timestamp.fromDate(requestDate),
      'status': status,
      'requestType': requestType,
      'targetDepartment': targetDepartment,
      'targetMinistryTeam': targetMinistryTeam,
    };
  }
}
