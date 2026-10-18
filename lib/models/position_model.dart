import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/constants.dart';
import 'user_model.dart';

// 자리(직책) 정적 정의 — role+department 조합에서 결정되는 메타데이터.
// Firestore positions 문서에도 role/department/capacity를 함께 저장하지만(조회 편의),
// 정답은 항상 이 레지스트리이고 문서 값은 그로부터 파생된 캐시일 뿐이다.
class PositionDef {
  final String id;
  final String role;
  final String department;
  // null이면 무제한(다인 가능: 총무, 새가족팀 리더). 그 외에는 항상 1(단일석).
  final int? capacity;
  // role=executive인 자리에서만 의미 있음(회장/부회장/총무/회계). 그 외엔 빈 문자열
  final String executiveTitle;

  const PositionDef({required this.id, required this.role, required this.department, this.capacity, this.executiveTitle = ''});

  bool get isMultiSeat => capacity == null;

  // 사람이 읽기 편한 자리 이름 (예: "D-4 소팀장", "A-0 중팀장", "임원팀 회장").
  // deptLabel은 "A-0" 같은 중팀장 소속에 "(중팀장)"을 덧붙이는데, 여기서는
  // 역할 이름을 뒤에 따로 붙이므로 중팀장 자리는 raw department 코드를 그대로 쓴다
  String get label {
    if (role == UserRole.executive) return '$department $executiveTitle';
    if (role == UserRole.midLeader) return '$department ${UserRole.label(role)}';
    return '${AppTeams.deptLabel(department)} ${UserRole.label(role)}';
  }
}

class PositionRegistry {
  PositionRegistry._();

  // department+role(+임원팀이면 executiveTitle) 조합에서 자리 ID를 계산한다.
  // 자리 모델 대상이 아닌 조합(role=member/admin/pastor, department가 맞지 않는
  // 상태, 또는 role=executive인데 유효한 직책이 없는 상태)은 null을 반환한다 —
  // 이 경우 호출자는 "자리 없음"으로 취급하면 된다.
  static String? idFor({required String role, required String department, String executiveTitle = ''}) {
    switch (role) {
      case UserRole.midLeader:
        if (department == AppTeams.newFamilyTeam || department.endsWith('-0')) {
          return '${department}_mid_leader';
        }
        return null;
      case UserRole.smallLeader:
        if (AppTeams.smallTeams.contains(department)) return '${department}_small_leader';
        return null;
      case UserRole.executive:
        if (department == AppTeams.executiveTeam && ExecutiveTitle.all.contains(executiveTitle)) {
          return '${department}_$executiveTitle';
        }
        return null;
      default:
        return null;
    }
  }

  // 전체 자리 목록(26개: 중팀장 4 + 일반 소팀장 16 + 새가족팀장 1 + 새가족팀리더 1 +
  // 임원팀 직책 4) — AppTeams.allDepts를 순회해 생성. 새가족팀은 예외적으로 두
  // 자리(팀장=단일석, 리더=다인석)를 모두 가지고, 임원팀은 회장/부회장/총무/회계
  // 4개 직책 자리로 세분화된다(총무만 다인석).
  static final List<PositionDef> all = _build();

  static final Map<String, PositionDef> _byId = {for (final d in all) d.id: d};
  static PositionDef? byId(String id) => _byId[id];

  static List<PositionDef> _build() {
    final defs = <PositionDef>[];
    for (final dept in AppTeams.allDepts) {
      if (dept == AppTeams.executiveTeam) {
        for (final title in ExecutiveTitle.all) {
          defs.add(PositionDef(
            id: '${dept}_$title',
            role: UserRole.executive,
            department: dept,
            capacity: ExecutiveTitle.capacityFor(title),
            executiveTitle: title,
          ));
        }
      } else if (dept == AppTeams.newFamilyTeam) {
        defs.add(PositionDef(id: '${dept}_mid_leader', role: UserRole.midLeader, department: dept, capacity: 1));
        defs.add(PositionDef(id: '${dept}_small_leader', role: UserRole.smallLeader, department: dept, capacity: null));
      } else if (dept.endsWith('-0')) {
        defs.add(PositionDef(id: '${dept}_mid_leader', role: UserRole.midLeader, department: dept, capacity: 1));
      } else {
        defs.add(PositionDef(id: '${dept}_small_leader', role: UserRole.smallLeader, department: dept, capacity: 1));
      }
    }
    return defs;
  }
}

// Firestore positions/{id} 문서의 런타임 표현
class PositionModel {
  final String id;
  final String role;
  final String department;
  final int? capacity;
  final List<String> holderUids;
  final DateTime? updatedAt;
  final String? updatedBy;

  const PositionModel({
    required this.id,
    required this.role,
    required this.department,
    this.capacity,
    this.holderUids = const [],
    this.updatedAt,
    this.updatedBy,
  });

  // capacity==1(단일석) 자리에서만 의미 있는 편의 getter
  String? get holderUid => holderUids.isEmpty ? null : holderUids.first;
  bool get isMultiSeat => capacity == null;
  bool get isVacant => holderUids.isEmpty;

  factory PositionModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return PositionModel(
      id: doc.id,
      role: data['role'] ?? '',
      department: data['department'] ?? '',
      capacity: data['capacity'] as int?,
      holderUids: List<String>.from(data['holderUids'] ?? []),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
      updatedBy: data['updatedBy'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'role': role,
      'department': department,
      'capacity': capacity,
      'holderUids': holderUids,
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : Timestamp.now(),
      'updatedBy': updatedBy,
    };
  }

  PositionModel copyWith({List<String>? holderUids, DateTime? updatedAt, String? updatedBy}) {
    return PositionModel(
      id: id,
      role: role,
      department: department,
      capacity: capacity,
      holderUids: holderUids ?? this.holderUids,
      updatedAt: updatedAt ?? this.updatedAt,
      updatedBy: updatedBy ?? this.updatedBy,
    );
  }
}

// 자리 하나에 대한 "최종 holder 목록"을 지정하는 배치 입력 단위.
// previousHolderUids와 holderUids를 비교해 빠진 사람은 member로 강등, 새로
// 추가된 사람은 role/department를 자리 값으로 승급시킨다. 지금은 마이그레이션
// 충돌 해결(자리 1개씩)에만 쓰지만, 2단계(여러 자리 일괄 발령)에서 리스트에
// 여러 항목을 담아 그대로 재사용할 수 있도록 범용으로 설계함
class PositionAssignment {
  final String positionId;
  final String role;
  final String department;
  final int? capacity;
  // role=executive인 자리에서만 의미 있음(회장/부회장/총무/회계)
  final String executiveTitle;
  final List<String> previousHolderUids;
  final List<String> holderUids;

  const PositionAssignment({
    required this.positionId,
    required this.role,
    required this.department,
    required this.capacity,
    this.executiveTitle = '',
    required this.previousHolderUids,
    required this.holderUids,
  });
}

// 자리 마이그레이션 미리보기 한 줄 — 어떤 자리에 현재 누가 매칭되는지.
// capacity==1인데 매칭된 사람이 2명 이상이면 충돌(관리자가 직접 선택 필요).
class PositionMigrationEntry {
  final PositionDef def;
  final List<UserModel> matched;

  const PositionMigrationEntry({required this.def, required this.matched});

  bool get isConflict => def.capacity == 1 && matched.length > 1;
  bool get isVacant => matched.isEmpty;
}
