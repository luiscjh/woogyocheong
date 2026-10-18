import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import '../models/attendance_model.dart';
import '../models/fee_model.dart';
import '../models/visit_model.dart';
import '../models/visit_slot_model.dart';
import '../models/position_model.dart';
import '../models/new_family_rotation_model.dart';
import '../models/banner_model.dart';
import '../models/ministry_meeting_model.dart';
import '../models/notification_model.dart';
import '../utils/constants.dart';
import 'demo_data.dart';

// demoMode = true 이면 Firebase 없이 인메모리 저장소를 사용
const bool demoMode = false;

class FirestoreService {
  FirebaseFirestore get _db => FirebaseFirestore.instance;
  final _demo = DemoData.instance;

  // ── Users ─────────────────────────────────────────────────────────────
  Stream<List<UserModel>> streamAllMembers() {
    if (demoMode) return _demo.streamAllMembers();
    return _db.collection('users').orderBy('name').snapshots()
        .map((s) => s.docs.map(UserModel.fromFirestore).toList());
  }

  Future<UserModel?> getUser(String uid) async {
    if (demoMode) return _demo.findUser(uid);
    final doc = await _db.collection('users').doc(uid).get();
    return doc.exists ? UserModel.fromFirestore(doc) : null;
  }

  // previousDepartment를 호출부가 이미 들고 있으면(대부분의 경우) 그대로 전달해
  // 변경 감지용 추가 조회 없이 바로 갱신할 수 있음. notify: false는 테스트 계정의
  // 역할 전환처럼 실제 소속팀 변경이 아닌 경우에 알림 생성을 건너뛰기 위함
  Future<void> updateUser(UserModel user, {String? previousDepartment, bool notify = true}) async {
    if (demoMode) { _demo.updateUser(user); return; }
    final oldDept = previousDepartment ??
        (await _db.collection('users').doc(user.uid).get()).data()?['department'] as String? ??
        '';
    await _db.collection('users').doc(user.uid).update(user.toMap());
    if (notify && oldDept.isNotEmpty && oldDept != user.department && user.department.isNotEmpty) {
      await _addNotification(
        userId: user.uid,
        title: '소속팀 변경',
        body: '소속팀이 ${AppTeams.deptLabel(user.department)}(으)로 변경되었습니다.',
        type: 'teamAssignment',
      );
    }
  }

  Future<void> deleteUser(String uid) async {
    if (demoMode) { _demo.deleteUser(uid); return; }
    await _db.collection('users').doc(uid).delete();
  }

  // 역할 양도: outgoing의 역할/추가 권한을 incoming에게 넘기고 outgoing은 팀원으로 전환.
  // 두 문서 갱신을 WriteBatch로 묶어, 한쪽만 반영돼 역할이 중복/유실되는 상태를 막음
  // (소속팀은 바뀌지 않으므로 소속팀 변경 알림 대상도 아님). role/permissions 두 필드만
  // 갱신해, 화면이 들고 있던 오래된 값으로 그사이 바뀐 연락처 등을 덮어쓰지 않게 함
  Future<void> transferRole(UserModel outgoing, UserModel incoming) async {
    final promoted = incoming.copyWith(role: outgoing.role, permissions: outgoing.permissions);
    final demoted = outgoing.copyWith(role: UserRole.member, permissions: const []);
    if (demoMode) {
      _demo.updateUser(promoted);
      _demo.updateUser(demoted);
      return;
    }
    final batch = _db.batch();
    batch.update(_db.collection('users').doc(promoted.uid),
        {'role': promoted.role, 'permissions': promoted.permissions});
    batch.update(_db.collection('users').doc(demoted.uid),
        {'role': demoted.role, 'permissions': demoted.permissions});
    await batch.commit();
  }

  Future<void> importMembers(List<UserModel> members) async {
    if (demoMode) {
      for (final m in members) { _demo.addUser(m); }
      return;
    }
    final batch = _db.batch();
    for (final m in members) { batch.set(_db.collection('users').doc(m.uid), m.toMap()); }
    await batch.commit();
  }

  // 회원 생성/수정(청년부 명단 화면의 "추가"/"수정") — role·department가 자리
  // (positions)에 해당하면 _stagePositionChange로 전임자 강등까지 한 트랜잭션에서
  // 처리한다. previous가 null이면 신규 생성(기존 자리 없음)으로 취급한다.
  Future<UserModel> saveMember(UserModel updated, {UserModel? previous, required String performedBy, bool notify = true}) async {
    final target = previous ??
        UserModel(uid: updated.uid, name: '', email: '', phone: '', role: UserRole.member, department: '', joinDate: updated.joinDate);
    if (demoMode) {
      final r = _demo.stagePositionChange(target: target, newRole: updated.role, newDepartment: updated.department, newExecutiveTitle: updated.executiveTitle);
      final finalUser = updated.copyWith(
        role: r.role,
        department: r.department,
        executiveTitle: r.executiveTitle,
        ministryTeam: r.resetMinistry ? '' : null,
        isMinistryLead: r.resetMinistry ? false : null,
        bannerAccessGranted: r.resetMinistry ? false : null,
      );
      if (previous == null) { _demo.addUser(finalUser); } else { _demo.updateUser(finalUser); }
      return finalUser;
    }
    late final UserModel finalUser0;
    await _db.runTransaction((txn) async {
      final r = await _stagePositionChange(txn, target: target, newRole: updated.role, newDepartment: updated.department, newExecutiveTitle: updated.executiveTitle, performedBy: performedBy);
      final finalUser = updated.copyWith(
        role: r.role,
        department: r.department,
        executiveTitle: r.executiveTitle,
        ministryTeam: r.resetMinistry ? '' : null,
        isMinistryLead: r.resetMinistry ? false : null,
        bannerAccessGranted: r.resetMinistry ? false : null,
      );
      finalUser0 = finalUser;
      txn.set(_db.collection('users').doc(updated.uid), finalUser.toMap());
      if (notify && previous != null && previous.department.isNotEmpty &&
          previous.department != finalUser.department && finalUser.department.isNotEmpty) {
        txn.set(_db.collection('notifications').doc(), _notificationData(
          userId: updated.uid,
          title: '소속팀 변경',
          body: '소속팀이 ${AppTeams.deptLabel(finalUser.department)}(으)로 변경되었습니다.',
          type: 'teamAssignment',
        ));
      }
    });
    return finalUser0;
  }

  // ── Positions (자리) ─────────────────────────────────────────────────
  // 권한을 사람이 아니라 "자리"(예: A-1 소팀장, 임원팀)에 붙여 관리한다.
  // users.role/department는 여전히 실제 값을 들고 있지만, 그 값은 이 자리에서
  // "파생된" 것으로 취급한다 — 자리의 holder가 바뀌면 전임자/후임자의
  // users.role/department가 같은 배치에서 함께 갱신된다.
  Stream<List<PositionModel>> streamAllPositions() {
    if (demoMode) return _demo.streamAllPositions();
    return _db.collection('positions').snapshots()
        .map((s) => s.docs.map(PositionModel.fromFirestore).toList());
  }

  Future<PositionModel?> getPosition(String id) async {
    if (demoMode) return _demo.getPosition(id);
    final doc = await _db.collection('positions').doc(id).get();
    return doc.exists ? PositionModel.fromFirestore(doc) : null;
  }

  // target의 role/department를 newRole/newDepartment로 바꿀 때 필요한 자리
  // 갱신(전임자 강등 + positions 문서 갱신)을 주어진 Transaction에 "쌓기만" 한다
  // (커밋은 호출자의 runTransaction 콜백이 끝나며 자동으로 한다) — 승인 처리 등
  // 다른 쓰기와 하나의 트랜잭션으로 묶기 위함. WriteBatch가 아니라 Transaction을
  // 쓰는 이유: 자리 문서를 읽고(get) 그 결과로 홀더 목록을 계산해 다시 쓰는(set)
  // 패턴이라, 읽기와 쓰기 사이에 다른 관리자의 동시 쓰기가 끼어들면 그 변경을
  // 덮어써 버릴 수 있다(갱신 유실) — Transaction은 커밋 시점에 읽은 문서가
  // 그사이 바뀌었으면 자동 재시도하므로 이 경합을 막는다. Firestore 트랜잭션은
  // "모든 읽기가 모든 쓰기보다 먼저" 규칙이 있어, 아래에서 기존/신규 자리 문서를
  // 먼저 둘 다 읽은 뒤에만 쓴다.
  // QA 테스트 계정(testing@church.com)은 자리 북키핑 대상에서 완전히 제외한다 —
  // 자리 자동 강등/충돌 집계에 실제 데이터처럼 섞이면 안 되므로, 이 함수를 호출하는
  // saveMember에서 이 지점 한 곳으로 막는다.
  // 반환값은 target의 users 문서에 최종 반영해야 할 role/department/
  // executiveTitle(+ 임원팀 승격 시 사역팀 필드 초기화 여부)이며, 자리가
  // 바뀌지 않았어도(또는 테스트 계정이라 자리 자체를 건드리지 않았어도) 호출자가
  // 그대로 쓸 수 있도록 항상 담아 돌려준다. newExecutiveTitle은 newRole이
  // executive일 때만 의미 있고(ExecutiveTitle.all 중 하나여야 함), 그 외 role이면
  // 무시되고 결과의 executiveTitle은 항상 ''으로 정리된다.
  Future<({String role, String department, String executiveTitle, bool resetMinistry})> _stagePositionChange(
    Transaction txn, {
    required UserModel target,
    required String newRole,
    required String newDepartment,
    String newExecutiveTitle = '',
    required String performedBy,
  }) async {
    final finalExecutiveTitle = newRole == UserRole.executive ? newExecutiveTitle : '';
    if (target.email == 'testing@church.com') {
      return (role: newRole, department: newDepartment, executiveTitle: finalExecutiveTitle, resetMinistry: false);
    }

    final oldPositionId = PositionRegistry.idFor(role: target.role, department: target.department, executiveTitle: target.executiveTitle);
    final newPositionId = PositionRegistry.idFor(role: newRole, department: newDepartment, executiveTitle: newExecutiveTitle);

    if (oldPositionId == newPositionId) {
      return (role: newRole, department: newDepartment, executiveTitle: finalExecutiveTitle, resetMinistry: false);
    }

    // 모든 읽기를 먼저 수행(Firestore 트랜잭션 제약: 읽기는 쓰기보다 먼저)
    final oldSnap = oldPositionId != null ? await txn.get(_db.collection('positions').doc(oldPositionId)) : null;
    final newSnap = newPositionId != null ? await txn.get(_db.collection('positions').doc(newPositionId)) : null;

    // 마이그레이션 전이라면 positions 문서가 아직 없을 수 있어 update() 대신
    // 항상 현재 상태를 읽고 전체 필드를 다시 쓰는 set()을 쓴다(없으면 새로 생성됨)
    if (oldPositionId != null) {
      final oldDef = PositionRegistry.byId(oldPositionId)!;
      final oldHolders = List<String>.from(oldSnap?.data()?['holderUids'] ?? []);
      txn.set(_db.collection('positions').doc(oldPositionId), {
        'role': oldDef.role,
        'department': oldDef.department,
        'capacity': oldDef.capacity,
        'holderUids': oldHolders.where((u) => u != target.uid).toList(),
        'updatedAt': Timestamp.now(),
        'updatedBy': performedBy,
      });
    }

    var resetMinistry = false;
    if (newPositionId != null) {
      final def = PositionRegistry.byId(newPositionId)!;
      final currentHolders = List<String>.from(newSnap?.data()?['holderUids'] ?? []);
      // 단일석(capacity==1)에 이미 다른 사람이 있으면 전임자를 팀원으로 강등
      // (role이 더 이상 executive가 아니게 되므로 executiveTitle도 함께 비움)
      if (def.capacity == 1 && currentHolders.isNotEmpty && currentHolders.first != target.uid) {
        txn.update(_db.collection('users').doc(currentHolders.first), {'role': UserRole.member, 'permissions': [], 'executiveTitle': ''});
      }
      final newHolders = def.capacity == 1 ? [target.uid] : {...currentHolders, target.uid}.toList();
      txn.set(_db.collection('positions').doc(newPositionId), {
        'role': def.role,
        'department': def.department,
        'capacity': def.capacity,
        'holderUids': newHolders,
        'updatedAt': Timestamp.now(),
        'updatedBy': performedBy,
      });
      resetMinistry = newRole == UserRole.executive;
    }

    return (role: newRole, department: newDepartment, executiveTitle: finalExecutiveTitle, resetMinistry: resetMinistry);
  }

  // 여러 자리를 한 번에(한 WriteBatch) 갱신. previousHolderUids와 holderUids를
  // 비교해 빠진 사람은 강등, 새로 추가된 사람은 승급시킨다. 자리 마이그레이션의
  // 충돌 해결(자리 1개씩 호출)과 향후 2단계(일괄 발령, 여러 개를 한 번에)에서
  // 그대로 재사용할 수 있도록 범용으로 작성함
  Future<void> applyPositionAssignments(List<PositionAssignment> assignments, {required String performedBy}) async {
    if (demoMode) {
      for (final a in assignments) { _demo.applyPositionAssignment(a, performedBy: performedBy); }
      return;
    }
    final batch = _db.batch();
    for (final a in assignments) {
      batch.set(_db.collection('positions').doc(a.positionId), {
        'role': a.role,
        'department': a.department,
        'capacity': a.capacity,
        'holderUids': a.holderUids,
        'updatedAt': Timestamp.now(),
        'updatedBy': performedBy,
      });
      for (final uid in a.previousHolderUids.where((u) => !a.holderUids.contains(u))) {
        batch.update(_db.collection('users').doc(uid), {'role': UserRole.member, 'permissions': [], 'executiveTitle': ''});
      }
      for (final uid in a.holderUids.where((u) => !a.previousHolderUids.contains(u))) {
        final update = <String, dynamic>{'role': a.role, 'department': a.department, 'executiveTitle': a.executiveTitle};
        if (a.role == UserRole.executive) {
          update['ministryTeam'] = '';
          update['isMinistryLead'] = false;
          update['bannerAccessGranted'] = false;
        }
        batch.update(_db.collection('users').doc(uid), update);
      }
    }
    await batch.commit();
  }

  // 자리 마이그레이션 미리보기: 현재 users 컬렉션을 스캔해 각 자리(23개 고정
  // 목록)에 해당하는 사람을 찾는다. Blaze 요금제/서비스 계정 없이 클라이언트에서
  // 그대로 실행 가능하도록 서버 함수 없이 구현. 여러 번 실행해도 안전(멱등) —
  // 항상 "현재 users 상태"를 기준으로 다시 계산한다.
  // QA 테스트 계정은 자리 북키핑 대상에서 제외(_stagePositionChange와 동일한
  // 원칙) — 테스트 계정은 역할 전환 섹션(_TestRoleSwitcherSection)에서 updateUser로
  // 직접 role/department를 바꾸므로 positions를 거치지 않는데, 그 상태에서
  // 마이그레이션을 돌리면 실제 홀더와 겹치는 가짜 충돌로 집계될 수 있다
  Future<List<PositionMigrationEntry>> previewPositionMigration() async {
    final users = demoMode
        ? _demo.allMembersSnapshot()
        : (await _db.collection('users').get()).docs.map(UserModel.fromFirestore).toList();
    final realUsers = users.where((u) => u.email != 'testing@church.com').toList();
    return PositionRegistry.all.map((def) {
      final matched = realUsers.where((u) => PositionRegistry.idFor(role: u.role, department: u.department, executiveTitle: u.executiveTitle) == def.id).toList();
      return PositionMigrationEntry(def: def, matched: matched);
    }).toList();
  }

  // 이메일(소문자/trim 정규화) → UserModel 매핑. 리더 명단 엑셀 업로드에서
  // "변경 후" 칸에 적힌 이메일로 실제 회원을 찾는 데 사용. QA 테스트 계정은
  // previewPositionMigration과 동일한 이유로 제외(엑셀로 자리에 지정할 수 없음)
  Future<Map<String, UserModel>> fetchUsersByEmail() async {
    final users = demoMode
        ? _demo.allMembersSnapshot()
        : (await _db.collection('users').get()).docs.map(UserModel.fromFirestore).toList();
    return {
      for (final u in users)
        if (u.email.toLowerCase() != 'testing@church.com') u.email.trim().toLowerCase(): u,
    };
  }

  // ── Attendance ────────────────────────────────────────────────────────
  Future<void> setAttendance({required String userId, required String userName, required DateTime date, required bool isPresent, String? note}) async {
    if (demoMode) {
      _demo.setAttendance(userId: userId, userName: userName, date: date, isPresent: isPresent, note: note);
      return;
    }
    final docId = '${userId}_${AttendanceModel.dateKey(date)}';
    final model = AttendanceModel(id: docId, userId: userId, userName: userName, date: date, isPresent: isPresent, note: note);
    await _db.collection('attendance').doc(docId).set(model.toMap());
  }

  Stream<List<AttendanceModel>> streamAllAttendance() {
    if (demoMode) return _demo.streamAllAttendance();
    return _db.collection('attendance').snapshots()
        .map((s) => s.docs.map(AttendanceModel.fromFirestore).toList());
  }

  Stream<List<AttendanceModel>> streamAttendanceByDate(DateTime date) {
    if (demoMode) return _demo.streamAttendanceByDate(date);
    return _db.collection('attendance')
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(DateTime(date.year, date.month, date.day)))
        .where('date', isLessThan: Timestamp.fromDate(DateTime(date.year, date.month, date.day + 1)))
        .snapshots()
        .map((s) => s.docs.map(AttendanceModel.fromFirestore).toList());
  }

  Future<AttendanceModel?> getAttendance(String userId, DateTime date) async {
    if (demoMode) return _demo.getAttendance(userId, date);
    final docId = '${userId}_${AttendanceModel.dateKey(date)}';
    final doc = await _db.collection('attendance').doc(docId).get();
    return doc.exists ? AttendanceModel.fromFirestore(doc) : null;
  }

  Stream<List<AttendanceModel>> streamUserAttendance(String userId) {
    if (demoMode) return _demo.streamUserAttendance(userId);
    return _db.collection('attendance')
        .where('userId', isEqualTo: userId)
        .orderBy('date', descending: true)
        .snapshots()
        .map((s) => s.docs.map(AttendanceModel.fromFirestore).toList());
  }

  // ── Fee ──────────────────────────────────────────────────────────────
  Future<void> setFee({required String userId, required String userName, required int year, required int month, required bool isPaid, String? note}) async {
    if (demoMode) {
      _demo.setFee(userId: userId, userName: userName, year: year, month: month, isPaid: isPaid, note: note);
      return;
    }
    final docId = '${userId}_${year}_${month.toString().padLeft(2, '0')}';
    final model = FeeModel(id: docId, userId: userId, userName: userName, year: year, month: month, isPaid: isPaid, paidDate: isPaid ? DateTime.now() : null, note: note);
    await _db.collection('fees').doc(docId).set(model.toMap());
  }

  Stream<List<FeeModel>> streamFeesByPeriod(int year, int month) {
    if (demoMode) return _demo.streamFeesByPeriod(year, month);
    return _db.collection('fees')
        .where('year', isEqualTo: year).where('month', isEqualTo: month)
        .snapshots()
        .map((s) => s.docs.map(FeeModel.fromFirestore).toList());
  }

  Future<FeeModel?> getFee(String userId, int year, int month) async {
    if (demoMode) return _demo.getFee(userId, year, month);
    final docId = '${userId}_${year}_${month.toString().padLeft(2, '0')}';
    final doc = await _db.collection('fees').doc(docId).get();
    return doc.exists ? FeeModel.fromFirestore(doc) : null;
  }

  Stream<List<FeeModel>> streamUserFees(String userId) {
    if (demoMode) return _demo.streamUserFees(userId);
    return _db.collection('fees')
        .where('userId', isEqualTo: userId)
        .orderBy('year', descending: true)
        .snapshots()
        .map((s) => s.docs.map(FeeModel.fromFirestore).toList());
  }

  // ── Visit ─────────────────────────────────────────────────────────────
  Future<void> requestVisit(VisitModel visit) async {
    if (demoMode) { _demo.addVisit(visit); return; }
    await _db.collection('visits').doc(visit.id).set(visit.toMap());
  }

  // previousStatus/visitUserId를 호출부가 이미 들고 있는 VisitModel에서 그대로
  // 전달하면 변경 감지용 추가 조회 없이 바로 갱신할 수 있음
  Future<void> updateVisitStatus(String visitId, String status,
      {String? adminNote, String? previousStatus, String? visitUserId}) async {
    if (demoMode) { _demo.updateVisitStatus(visitId, status, adminNote: adminNote); return; }
    var oldStatus = previousStatus;
    var userId = visitUserId;
    if (oldStatus == null || userId == null) {
      final doc = await _db.collection('visits').doc(visitId).get();
      oldStatus = doc.data()?['status'] as String? ?? '';
      userId = doc.data()?['userId'] as String? ?? '';
    }
    final update = <String, dynamic>{'status': status};
    if (adminNote != null) update['adminNote'] = adminNote;
    await _db.collection('visits').doc(visitId).update(update);
    if (userId.isNotEmpty && oldStatus != status) {
      await _addNotification(
        userId: userId,
        title: '심방 신청 상태 변경',
        body: "심방 신청이 '${VisitStatus.label(status)}' 상태로 변경되었습니다.",
        type: 'visit',
      );
    }
  }

  Future<void> deleteVisit(String visitId) async {
    if (demoMode) { _demo.deleteVisit(visitId); return; }
    await _db.collection('visits').doc(visitId).delete();
  }

  Stream<List<VisitModel>> streamAllVisits() {
    if (demoMode) return _demo.streamAllVisits();
    return _db.collection('visits')
        .orderBy('requestDate', descending: true)
        .snapshots()
        .map((s) => s.docs.map(VisitModel.fromFirestore).toList());
  }

  Stream<List<VisitModel>> streamUserVisits(String userId) {
    if (demoMode) return _demo.streamUserVisits(userId);
    return _db.collection('visits')
        .where('userId', isEqualTo: userId)
        .orderBy('requestDate', descending: true)
        .snapshots()
        .map((s) => s.docs.map(VisitModel.fromFirestore).toList());
  }

  // ── Visit Slots ───────────────────────────────────────────────────────
  Stream<List<VisitSlotModel>> streamVisitSlots() {
    if (demoMode) return _demo.streamVisitSlots();
    return _db.collection('visitSlots')
        .orderBy('dateTime')
        .snapshots()
        .map((s) => s.docs.map(VisitSlotModel.fromFirestore).toList());
  }

  Future<void> addVisitSlots(List<DateTime> dateTimes) async {
    if (demoMode) { _demo.addVisitSlots(dateTimes); return; }
    final batch = _db.batch();
    for (final dt in dateTimes) {
      batch.set(_db.collection('visitSlots').doc(), {'dateTime': Timestamp.fromDate(dt)});
    }
    await batch.commit();
  }

  Future<void> deleteVisitSlot(String id) async {
    if (demoMode) { _demo.deleteVisitSlot(id); return; }
    await _db.collection('visitSlots').doc(id).delete();
  }

  // ── New Family Rotation (주차 1~3별 고정 담당 리더) ──────────────────────
  Stream<List<NewFamilyRotationModel>> streamNewFamilyRotations() {
    if (demoMode) return _demo.streamNewFamilyRotations();
    return _db.collection('newFamilyRotations')
        .orderBy('weekNumber')
        .snapshots()
        .map((s) => s.docs.map(NewFamilyRotationModel.fromFirestore).toList());
  }

  // weekNumber 기준으로 upsert (이미 등록된 주차면 담당 리더를 교체)
  Future<void> setNewFamilyRotation(NewFamilyRotationModel rotation) async {
    if (demoMode) { _demo.setNewFamilyRotation(rotation); return; }
    await _db.collection('newFamilyRotations').doc('week${rotation.weekNumber}').set(rotation.toMap());
    await _addNotification(
      userId: rotation.leaderId,
      title: '새가족 로테이션 배정',
      body: '${rotation.weekNumber}주차 새가족 로테이션 담당으로 배정되었습니다.',
      type: 'newFamilyRotation',
    );
  }

  // ── Ministry Meetings (사역팀 회의 일정) ─────────────────────────────────
  Stream<List<MinistryMeetingModel>> streamMinistryMeetings(String ministryTeam) {
    if (demoMode) return _demo.streamMinistryMeetings(ministryTeam);
    return _db.collection('ministryMeetings')
        .where('ministryTeam', isEqualTo: ministryTeam)
        .orderBy('date', descending: true)
        .snapshots()
        .map((s) => s.docs.map(MinistryMeetingModel.fromFirestore).toList());
  }

  Future<void> addMinistryMeeting(MinistryMeetingModel meeting) async {
    if (demoMode) { _demo.addMinistryMeeting(meeting); return; }
    await _db.collection('ministryMeetings').doc(meeting.id).set(meeting.toMap());
  }

  Future<void> updateMinistryMeeting(MinistryMeetingModel meeting) async {
    if (demoMode) { _demo.updateMinistryMeeting(meeting); return; }
    await _db.collection('ministryMeetings').doc(meeting.id).update(meeting.toMap());
  }

  Future<void> deleteMinistryMeeting(String id) async {
    if (demoMode) { _demo.deleteMinistryMeeting(id); return; }
    await _db.collection('ministryMeetings').doc(id).delete();
  }

  // ── Notifications (심방/목사 권한/새가족 로테이션/팀 배정 등 이벤트 알림) ──
  // 지금은 인앱 알림함으로만 동작. Firebase 연결 후에는 이 알림 문서 생성을
  // 감지하는 Cloud Function에서 FCM 푸시를 함께 보내도록 확장하면 됨
  Stream<List<NotificationModel>> streamUserNotifications(String userId) {
    if (demoMode) return _demo.streamUserNotifications(userId);
    return _db.collection('notifications')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map(NotificationModel.fromFirestore).toList());
  }

  Future<void> markNotificationRead(String id) async {
    if (demoMode) { _demo.markNotificationRead(id); return; }
    await _db.collection('notifications').doc(id).update({'isRead': true});
  }

  Future<void> markAllNotificationsRead(String userId) async {
    if (demoMode) { _demo.markAllNotificationsRead(userId); return; }
    final unread = await _db.collection('notifications')
        .where('userId', isEqualTo: userId)
        .where('isRead', isEqualTo: false)
        .get();
    final batch = _db.batch();
    for (final doc in unread.docs) {
      batch.update(doc.reference, {'isRead': true});
    }
    await batch.commit();
  }

  Future<void> _addNotification({
    required String userId,
    required String title,
    required String body,
    required String type,
  }) async {
    await _db.collection('notifications').add(_notificationData(
      userId: userId, title: title, body: body, type: type,
    ));
  }

  Map<String, dynamic> _notificationData({
    required String userId,
    required String title,
    required String body,
    required String type,
  }) {
    return {
      'userId': userId,
      'title': title,
      'body': body,
      'type': type,
      'createdAt': Timestamp.fromDate(DateTime.now()),
      'isRead': false,
    };
  }

  // ── Banners ───────────────────────────────────────────────────────────
  Stream<List<BannerModel>> streamActiveBanners() {
    if (demoMode) return _demo.streamActiveBanners();
    return _db.collection('banners')
        .where('isActive', isEqualTo: true).orderBy('order')
        .snapshots()
        .map((s) => s.docs.map(BannerModel.fromFirestore).toList());
  }

  Stream<List<BannerModel>> streamAllBanners() {
    if (demoMode) return _demo.streamAllBanners();
    return _db.collection('banners').orderBy('order').snapshots()
        .map((s) => s.docs.map(BannerModel.fromFirestore).toList());
  }

  Future<String> addBanner(BannerModel banner) async {
    if (demoMode) { _demo.addBanner(banner); return 'demo_id'; }
    final ref = await _db.collection('banners').add(banner.toMap());
    return ref.id;
  }

  Future<void> updateBanner(BannerModel banner) async {
    if (demoMode) { _demo.updateBanner(banner); return; }
    await _db.collection('banners').doc(banner.id).update(banner.toMap());
  }

  Future<void> deleteBanner(String id) async {
    if (demoMode) { _demo.deleteBanner(id); return; }
    await _db.collection('banners').doc(id).delete();
  }
}
