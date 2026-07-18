import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/constants.dart';

class UserModel {
  final String uid;
  final String name;
  final String email;
  final String phone;
  final String role;
  final String department; // 소팀 (A-1 ~ D-4)
  final DateTime joinDate;
  final String? profileImageUrl;
  final List<String> permissions; // 관리자가 부여한 추가 권한

  UserModel({
    required this.uid,
    required this.name,
    required this.email,
    required this.phone,
    required this.role,
    required this.department,
    required this.joinDate,
    this.profileImageUrl,
    this.permissions = const [],
  });

  // 역할 계층 헬퍼
  // 목사님은 관리자와 동일한 권한을 가짐
  bool get isAdmin => role == UserRole.admin || role == UserRole.pastor;
  bool get isExecutive => role == UserRole.executive || isAdmin;
  bool get isMidLeader => role == UserRole.midLeader || isExecutive;
  bool get isSmallLeader => role == UserRole.smallLeader || isMidLeader;

  // 소속 중팀 (department 'A-1' → 'A')
  // 임원팀/새가족팀처럼 하이픈 없는 소속은 소팀 하위 구분이 없으므로 자기 자신이 곧 상위(중팀 수준) 단위가 됨
  String get midTeam => department.contains('-') ? department.split('-')[0] : department;

  // 추가 권한 확인 (관리자는 항상 true)
  bool hasPermission(String perm) => isAdmin || permissions.contains(perm);

  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UserModel(
      uid: doc.id,
      name: data['name'] ?? '',
      email: data['email'] ?? '',
      phone: data['phone'] ?? '',
      role: data['role'] ?? 'member',
      department: data['department'] ?? '',
      joinDate: (data['joinDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      profileImageUrl: data['profileImageUrl'],
      permissions: List<String>.from(data['permissions'] ?? []),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'email': email,
      'phone': phone,
      'role': role,
      'department': department,
      'joinDate': Timestamp.fromDate(joinDate),
      'profileImageUrl': profileImageUrl,
      'permissions': permissions,
    };
  }

  UserModel copyWith({
    String? name,
    String? email,
    String? phone,
    String? role,
    String? department,
    DateTime? joinDate,
    String? profileImageUrl,
    List<String>? permissions,
  }) {
    return UserModel(
      uid: uid,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      role: role ?? this.role,
      department: department ?? this.department,
      joinDate: joinDate ?? this.joinDate,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      permissions: permissions ?? this.permissions,
    );
  }
}
