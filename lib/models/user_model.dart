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
  // 새가족팀 졸업(소팀 배정) 시 배정된 소팀. 이후 department가 실제 소팀으로
  // 바뀌어도 이 값은 남아있어, 소팀 배정 권한이 없는 조회자(예: 목사님)도
  // "누가 어느 팀으로 배정 확정됐는지" 정보를 확인할 수 있게 함
  final String? newFamilyGraduatedTo;
  // 사역팀(콘텐츠팀 등) 소속 — department(중팀/소팀/임원팀/새가족팀)와는
  // 완전히 독립된 별도 소속 축. 소팀장·일반 팀원이 자기 팀은 그대로 유지한
  // 채 추가로 소속될 수 있음. 빈 문자열이면 사역팀 미소속
  final String ministryTeam;
  // 사역팀장 여부 (ministryTeam이 설정된 경우에만 의미 있음)
  final bool isMinistryLead;
  // 배너 관리 권한 공유 여부 — 사역팀장이 아닌 일반 사역팀 팀원 중, 팀장이
  // 지정하여 배너 관리 권한을 위임(공유)받은 경우에만 true. 사역팀장 지정
  // 자체(누가 팀장인지)는 관리자만 변경 가능하고, 이 위임은 해당 팀 팀장이 부여함
  final bool bannerAccessGranted;
  // 생년월일 — 회원 정보 기록용. 나이 자체로 이용 제한을 걸지는 않고
  // 아래 cohort(기수) 기준으로만 제한하므로 참고용 정보에 가까움
  final DateTime? birthDate;
  // 기수 — 청년부 이용 가능 여부를 판단하는 기준값. 관리자가 설정하는
  // "현재 기수" 대비 허용 범위(AppSettingsModel)를 벗어나면 조회 전용으로
  // 전환됨(목사님 역할은 예외). null이면 아직 기수가 등록되지 않은
  // 상태로, 이 경우 제한 대상에서 제외됨
  final int? cohort;

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
    this.newFamilyGraduatedTo,
    this.ministryTeam = '',
    this.isMinistryLead = false,
    this.bannerAccessGranted = false,
    this.birthDate,
    this.cohort,
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
      newFamilyGraduatedTo: data['newFamilyGraduatedTo'],
      ministryTeam: data['ministryTeam'] ?? '',
      isMinistryLead: data['isMinistryLead'] ?? false,
      bannerAccessGranted: data['bannerAccessGranted'] ?? false,
      birthDate: (data['birthDate'] as Timestamp?)?.toDate(),
      cohort: data['cohort'] as int?,
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
      'newFamilyGraduatedTo': newFamilyGraduatedTo,
      'ministryTeam': ministryTeam,
      'isMinistryLead': isMinistryLead,
      'bannerAccessGranted': bannerAccessGranted,
      'birthDate': birthDate != null ? Timestamp.fromDate(birthDate!) : null,
      'cohort': cohort,
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
    String? newFamilyGraduatedTo,
    String? ministryTeam,
    bool? isMinistryLead,
    bool? bannerAccessGranted,
    DateTime? birthDate,
    int? cohort,
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
      newFamilyGraduatedTo: newFamilyGraduatedTo ?? this.newFamilyGraduatedTo,
      ministryTeam: ministryTeam ?? this.ministryTeam,
      isMinistryLead: isMinistryLead ?? this.isMinistryLead,
      bannerAccessGranted: bannerAccessGranted ?? this.bannerAccessGranted,
      birthDate: birthDate ?? this.birthDate,
      cohort: cohort ?? this.cohort,
    );
  }
}
