import 'dart:async';
import 'dart:typed_data';
import 'package:uuid/uuid.dart';
import '../models/user_model.dart';
import '../models/attendance_model.dart';
import '../models/fee_model.dart';
import '../models/visit_model.dart';
import '../models/visit_slot_model.dart';
import '../models/pastor_request_model.dart';
import '../models/new_family_rotation_model.dart';
import '../models/banner_model.dart';
import '../models/ministry_meeting_model.dart';
import '../models/notification_model.dart';
import '../models/app_settings_model.dart';
import '../utils/constants.dart';

// 싱글턴 인메모리 저장소 – 데모 모드에서 Firebase 대신 사용
class DemoData {
  DemoData._();
  static final DemoData instance = DemoData._();

  UserModel? currentUser;

  // 데모 모드 업로드 이미지 인메모리 캐시 (mem://<key> → bytes)
  final Map<String, Uint8List> _imageCache = {};

  String cacheImage(Uint8List bytes) {
    final key = 'img_${DateTime.now().millisecondsSinceEpoch}';
    _imageCache[key] = bytes;
    return 'mem://$key';
  }

  Uint8List? getImageBytes(String url) {
    if (!url.startsWith('mem://')) return null;
    return _imageCache[url.substring(6)];
  }

  final List<UserModel> _users = [
    UserModel(uid: 'admin001', name: '김관리', email: 'admin@church.com', phone: '010-1234-5678', role: 'admin', department: 'A-1', joinDate: DateTime(2020, 1, 1)),
    // 목사님 (관리자와 동일한 권한 + 심방 신청 내용은 목사님과 신청자 본인만 조회 가능)
    UserModel(uid: 'pastor001', name: '최목사', email: 'pastor@church.com', phone: '010-0000-1111', role: 'pastor', department: 'A-1', joinDate: DateTime(2019, 1, 1)),
    // 임원팀 (소팀 없이 임원팀 자체가 소속팀)
    UserModel(uid: 'exec001', name: '이임원', email: 'exec@church.com', phone: '010-1111-2222', role: 'executive', department: AppTeams.executiveTeam, joinDate: DateTime(2020, 6, 1)),
    UserModel(uid: 'exec002', name: '박임원', email: 'execb@church.com', phone: '010-1111-3333', role: 'executive', department: AppTeams.executiveTeam, joinDate: DateTime(2020, 6, 1)),
    // 중팀장
    UserModel(uid: 'mid001', name: '박중팀', email: 'mid@church.com', phone: '010-2222-3333', role: 'mid_leader', department: 'A-0', joinDate: DateTime(2021, 1, 1)),
    UserModel(uid: 'mid002', name: '최중팀', email: 'midb@church.com', phone: '010-3333-4444', role: 'mid_leader', department: 'B-0', joinDate: DateTime(2021, 1, 1)),
    // 소팀장
    UserModel(uid: 'small001', name: '정소팀', email: 'small@church.com', phone: '010-4444-5555', role: 'small_leader', department: 'A-1', joinDate: DateTime(2021, 6, 1)),
    UserModel(uid: 'small002', name: '한소팀', email: 'smallb@church.com', phone: '010-5555-6666', role: 'small_leader', department: 'A-2', joinDate: DateTime(2021, 6, 1)),
    // 새가족팀 (중팀에 속하지 않는 독립된 소팀)
    // 새가족팀장: 중팀장과 동일한 권한 수준. 로테이션 명단 등록 권한 보유
    UserModel(uid: 'newfamilyhead001', name: '오새가족', email: 'newfamily@church.com', phone: '010-7777-8888', role: 'mid_leader', department: AppTeams.newFamilyTeam, joinDate: DateTime(2023, 1, 1)),
    // 새가족팀 리더: 소팀장과 동일한 권한 수준. 주차별로 로테이션하며 새가족 나눔 모임을 이끔
    UserModel(uid: 'newfamilyleader001', name: '장리더', email: 'leader1@church.com', phone: '010-6666-7777', role: 'small_leader', department: AppTeams.newFamilyTeam, joinDate: DateTime(2023, 3, 1)),
    UserModel(uid: 'newfamilyleader002', name: '윤리더', email: 'leader2@church.com', phone: '010-6666-8888', role: 'small_leader', department: AppTeams.newFamilyTeam, joinDate: DateTime(2023, 6, 1)),
    // 팀원
    // cohort=19: 현재 기수(20) 허용 범위(11~20) 안 — 정상 이용 데모용
    UserModel(uid: 'member001', name: '이청년', email: 'lee@church.com', phone: '010-2345-6789', role: 'member', department: 'A-1', joinDate: DateTime(2021, 3, 1), birthDate: DateTime(2001, 4, 12), cohort: 19),
    // cohort=5: 현재 기수(20) 허용 범위(11~20) 밖 — 기수 제한(읽기 전용) 데모용
    UserModel(uid: 'member002', name: '박믿음', email: 'park@church.com', phone: '010-3456-7890', role: 'member', department: 'A-2', joinDate: DateTime(2021, 6, 1), birthDate: DateTime(1994, 9, 3), cohort: 5),
    UserModel(uid: 'member003', name: '최소망', email: 'choi@church.com', phone: '010-4567-8901', role: 'member', department: 'A-1', joinDate: DateTime(2022, 1, 1)),
    UserModel(uid: 'member004', name: '정사랑', email: 'jung@church.com', phone: '010-5678-9012', role: 'member', department: 'B-1', joinDate: DateTime(2022, 3, 1)),
    UserModel(uid: 'member005', name: '강기쁨', email: 'kang@church.com', phone: '010-6789-0123', role: 'member', department: 'B-2', joinDate: DateTime(2022, 6, 1)),
    // 새가족팀 팀원 - 출석 1회: 1주차 담당 리더 매칭 확인용
    UserModel(uid: 'member006', name: '김새싹', email: 'newbie1@church.com', phone: '010-8888-9999', role: 'member', department: AppTeams.newFamilyTeam, joinDate: DateTime(2026, 6, 1)),
    // 새가족팀 팀원 - 출석 2회: 2주차 담당 리더 매칭 확인용
    UserModel(uid: 'member007', name: '이새록', email: 'newbie2@church.com', phone: '010-9999-0000', role: 'member', department: AppTeams.newFamilyTeam, joinDate: DateTime(2026, 6, 15)),
    // 새가족팀 팀원 - 출석 0회(갓 가입) 상태, 홈 화면 'n주차' 배지의 0주차 케이스 확인용
    UserModel(uid: 'member008', name: '박새순', email: 'newbie3@church.com', phone: '010-1010-2020', role: 'member', department: AppTeams.newFamilyTeam, joinDate: DateTime.now()),
    // 새가족팀 팀원 - 출석 3회: 3주차 담당 리더 매칭 확인용
    UserModel(uid: 'member009', name: '한새길', email: 'newbie4@church.com', phone: '010-1111-2020', role: 'member', department: AppTeams.newFamilyTeam, joinDate: DateTime(2026, 5, 1)),
    // 콘텐츠팀(사역팀) 팀장 - department(A-1)는 그대로 유지한 채 ministryTeam만
    // 별도로 부여됨. 배너 관리 + 사역팀 회원 관리 + 회의 일정 관리 권한 보유
    // (소팀장 현황·회비 관리는 실제 중팀장 역할이 아니므로 제외됨. AuthProvider 참고)
    UserModel(uid: 'content001', name: '김콘텐츠', email: 'content@church.com', phone: '010-1212-3434', role: 'member', department: 'A-1', joinDate: DateTime(2024, 1, 1), ministryTeam: AppTeams.contentTeam, isMinistryLead: true),
    // 콘텐츠팀(사역팀) 팀원 - 팀장이 아닌 일반 팀원. department는 실제 소속 소팀(D-4)을
    // 그대로 유지한 채 ministryTeam만 추가로 부여됨. 배너 관리 권한은 팀장이 지정
    // 해야만 부여되므로 기본값(false)을 유지
    UserModel(uid: 'content002', name: '이콘텐츠', email: 'content2@church.com', phone: '010-1212-5656', role: 'member', department: 'D-4', joinDate: DateTime(2024, 3, 1), ministryTeam: AppTeams.contentTeam),
    // 테스트 계정: 내 정보 화면에서 관리자~팀원 역할을 자유롭게 전환하며 테스트 가능
    UserModel(uid: 'testing001', name: '테스트유저', email: 'testing@church.com', phone: '010-0000-0000', role: 'admin', department: 'A-1', joinDate: DateTime(2026, 1, 1)),
  ];

  final List<AttendanceModel> _attendance = [];
  final List<FeeModel> _fees = [];
  final List<VisitModel> _visits = [];
  final List<VisitSlotModel> _visitSlots = [];
  final List<PastorRequestModel> _pastorRequests = [];
  final List<NewFamilyRotationModel> _newFamilyRotations = [];
  final List<BannerModel> _banners = [];
  final List<MinistryMeetingModel> _ministryMeetings = [];
  final List<NotificationModel> _notifications = [];

  // 앱 전역 설정(단일 레코드) — 기수 기반 이용 제한 기준
  AppSettingsModel _settings = const AppSettingsModel(minAllowedCohort: 11, maxAllowedCohort: 20);

  // StreamControllers
  final _usersCtrl = StreamController<List<UserModel>>.broadcast();
  final _attendanceCtrl = StreamController<List<AttendanceModel>>.broadcast();
  final _feesCtrl = StreamController<List<FeeModel>>.broadcast();
  final _visitsCtrl = StreamController<List<VisitModel>>.broadcast();
  final _visitSlotsCtrl = StreamController<List<VisitSlotModel>>.broadcast();
  final _pastorRequestsCtrl = StreamController<List<PastorRequestModel>>.broadcast();
  final _newFamilyRotationsCtrl = StreamController<List<NewFamilyRotationModel>>.broadcast();
  final _bannersCtrl = StreamController<List<BannerModel>>.broadcast();
  final _ministryMeetingsCtrl = StreamController<List<MinistryMeetingModel>>.broadcast();
  final _notificationsCtrl = StreamController<List<NotificationModel>>.broadcast();
  final _settingsCtrl = StreamController<AppSettingsModel>.broadcast();

  void _initDemoData() {
    final now = DateTime.now();
    // 오늘 날짜 기준 최근 주일들 출석 샘플
    for (var i = 0; i < 4; i++) {
      final sunday = now.subtract(Duration(days: now.weekday % 7 + 7 * i));
      final date = DateTime(sunday.year, sunday.month, sunday.day);
      // member008(박새순)은 갓 가입한 새가족으로 출석 기록이 전혀 없는 상태를 시연하기 위해 제외
      for (final u in _users.where((u) => !u.isAdmin && u.uid != 'member008')) {
        // 새가족팀 팀원은 주차(1~3) 매칭 데모를 위해 출석 횟수를 개별로 다르게 부여
        bool present;
        if (u.uid == 'member006') {
          present = i < 1; // 1주차
        } else if (u.uid == 'member007') {
          present = i < 2; // 2주차
        } else if (u.uid == 'member009') {
          present = i < 3; // 3주차
        } else {
          present = i < 2 || u.uid != 'member003';
        }
        _attendance.add(AttendanceModel(
          id: '${u.uid}_${AttendanceModel.dateKey(date)}',
          userId: u.uid,
          userName: u.name,
          date: date,
          isPresent: present,
        ));
      }
    }

    // 새가족 로테이션 샘플: 1주차=윤리더, 2주차=장리더, 3주차는 미배정 상태로 시연
    _newFamilyRotations.addAll([
      NewFamilyRotationModel(
        id: const Uuid().v4(),
        weekNumber: 1,
        leaderId: 'newfamilyleader002',
        leaderName: '윤리더',
      ),
      NewFamilyRotationModel(
        id: const Uuid().v4(),
        weekNumber: 2,
        leaderId: 'newfamilyleader001',
        leaderName: '장리더',
      ),
    ]);

    // 콘텐츠팀(사역팀) 회의 일정 샘플
    _ministryMeetings.addAll([
      MinistryMeetingModel(
        id: const Uuid().v4(),
        ministryTeam: AppTeams.contentTeam,
        date: now.subtract(const Duration(days: 7)),
        topic: '7월 홍보 콘텐츠 기획',
        discussion: '여름수련회 홍보 카드뉴스 시안 검토, SNS 업로드 일정 조율',
        summary: '카드뉴스 시안 A안으로 확정, 다음 주까지 초안 제작 후 재검토 예정',
      ),
    ]);

    // 최근 3개월 회비 샘플
    for (var m = 0; m < 3; m++) {
      final month = now.month - m <= 0 ? now.month - m + 12 : now.month - m;
      final year = now.month - m <= 0 ? now.year - 1 : now.year;
      for (final u in _users.where((u) => !u.isAdmin)) {
        _fees.add(FeeModel(
          id: '${u.uid}_${year}_${month.toString().padLeft(2, '0')}',
          userId: u.uid,
          userName: u.name,
          year: year,
          month: month,
          isPaid: m > 0 || u.uid != 'member004',
          paidDate: m < 2 ? now.subtract(Duration(days: m * 30 + 5)) : null,
        ));
      }
    }

    // 심방 신청 샘플
    _visits.addAll([
      VisitModel(id: 'v001', userId: 'member001', userName: '이청년', phone: '010-2345-6789', deptName: '청년부', team: 'A-1', requestDate: now.subtract(const Duration(days: 5)), status: 'pending', reason: '이사 후 첫 심방 부탁드립니다.'),
      VisitModel(id: 'v002', userId: 'member002', userName: '박믿음', phone: '010-3456-7890', deptName: '청년부', team: 'A-2', requestDate: now.subtract(const Duration(days: 10)), preferredDate: now.add(const Duration(days: 7)), status: 'confirmed'),
      VisitModel(id: 'v003', userId: 'member003', userName: '최소망', phone: '010-4567-8901', deptName: '청년부', team: 'A-1', requestDate: now.subtract(const Duration(days: 20)), status: 'completed', adminNote: '심방 완료. 잘 지내고 있음.'),
    ]);

    // 심방 가능 시간대 샘플 (관리자가 미리 오픈해 둔 시간대)
    final nextSunday = now.add(Duration(days: (7 - now.weekday) % 7 + 7));
    _visitSlots.addAll([
      VisitSlotModel(id: const Uuid().v4(), dateTime: DateTime(nextSunday.year, nextSunday.month, nextSunday.day, 14, 0)),
      VisitSlotModel(id: const Uuid().v4(), dateTime: DateTime(nextSunday.year, nextSunday.month, nextSunday.day, 16, 0)),
      VisitSlotModel(id: const Uuid().v4(), dateTime: DateTime(nextSunday.year, nextSunday.month, nextSunday.day + 7, 14, 0)),
    ]);

    // 알림 샘플 (위 심방/로테이션 시드 데이터와 맞춘 예시)
    _notifications.addAll([
      NotificationModel(
        id: const Uuid().v4(),
        userId: 'member002',
        title: '심방 신청 상태 변경',
        body: "심방 신청이 '확정' 상태로 변경되었습니다.",
        type: 'visit',
        createdAt: now.subtract(const Duration(days: 9)),
      ),
      NotificationModel(
        id: const Uuid().v4(),
        userId: 'member003',
        title: '심방 신청 상태 변경',
        body: "심방 신청이 '완료' 상태로 변경되었습니다.",
        type: 'visit',
        createdAt: now.subtract(const Duration(days: 19)),
        isRead: true,
      ),
      NotificationModel(
        id: const Uuid().v4(),
        userId: 'newfamilyleader001',
        title: '새가족 로테이션 배정',
        body: '2주차 새가족 로테이션 담당으로 배정되었습니다.',
        type: 'newFamilyRotation',
        createdAt: now.subtract(const Duration(days: 3)),
      ),
    ]);
  }

  void init() {
    _initDemoData();
  }

  // ── Users ──────────────────────────────────────────────────
  Stream<List<UserModel>> streamAllMembers() {
    Future.microtask(() => _usersCtrl.add(List.from(_users)));
    return _usersCtrl.stream;
  }

  UserModel? findUser(String uid) {
    try {
      return _users.firstWhere((u) => u.uid == uid);
    } catch (_) {
      return null;
    }
  }

  UserModel? findByEmail(String email) {
    try {
      return _users.firstWhere((u) => u.email == email);
    } catch (_) {
      return null;
    }
  }

  void addUser(UserModel user) {
    _users.add(user);
    _usersCtrl.add(List.from(_users));
  }

  void updateUser(UserModel user) {
    final idx = _users.indexWhere((u) => u.uid == user.uid);
    // 소팀/중팀(department) 배정이 실제로 바뀐 경우에만 알림 발송
    if (idx >= 0 && _users[idx].department != user.department && user.department.isNotEmpty) {
      addNotification(
        userId: user.uid,
        title: '소속팀 변경',
        body: '소속팀이 ${AppTeams.deptLabel(user.department)}(으)로 변경되었습니다.',
        type: 'teamAssignment',
      );
    }
    if (idx >= 0) _users[idx] = user;
    _usersCtrl.add(List.from(_users));
  }

  void deleteUser(String uid) {
    _users.removeWhere((u) => u.uid == uid);
    _usersCtrl.add(List.from(_users));
  }

  // ── Attendance ─────────────────────────────────────────────
  Stream<List<AttendanceModel>> streamAllAttendance() {
    Future.microtask(() => _attendanceCtrl.add(List.from(_attendance)));
    return _attendanceCtrl.stream;
  }

  Stream<List<AttendanceModel>> streamAttendanceByDate(DateTime date) {
    final dateStr = AttendanceModel.dateKey(date);
    Future.microtask(() => _attendanceCtrl.add(List.from(_attendance)));
    return _attendanceCtrl.stream.map(
      (list) => list.where((a) => AttendanceModel.dateKey(a.date) == dateStr).toList(),
    );
  }

  Stream<List<AttendanceModel>> streamUserAttendance(String userId) {
    Future.microtask(() => _attendanceCtrl.add(List.from(_attendance)));
    return _attendanceCtrl.stream.map(
      (list) => (list.where((a) => a.userId == userId).toList()
        ..sort((a, b) => b.date.compareTo(a.date))),
    );
  }

  AttendanceModel? getAttendance(String userId, DateTime date) {
    final dateStr = AttendanceModel.dateKey(date);
    try {
      return _attendance.firstWhere(
          (a) => a.userId == userId && AttendanceModel.dateKey(a.date) == dateStr);
    } catch (_) {
      return null;
    }
  }

  void setAttendance({required String userId, required String userName, required DateTime date, required bool isPresent, String? note}) {
    final id = '${userId}_${AttendanceModel.dateKey(date)}';
    _attendance.removeWhere((a) => a.id == id);
    _attendance.add(AttendanceModel(id: id, userId: userId, userName: userName, date: date, isPresent: isPresent, note: note));
    _attendanceCtrl.add(List.from(_attendance));
  }

  // ── Fees ───────────────────────────────────────────────────
  Stream<List<FeeModel>> streamFeesByPeriod(int year, int month) {
    Future.microtask(() => _feesCtrl.add(List.from(_fees)));
    return _feesCtrl.stream.map(
      (list) => list.where((f) => f.year == year && f.month == month).toList(),
    );
  }

  Stream<List<FeeModel>> streamUserFees(String userId) {
    Future.microtask(() => _feesCtrl.add(List.from(_fees)));
    return _feesCtrl.stream.map(
      (list) => (list.where((f) => f.userId == userId).toList()
        ..sort((a, b) => b.year != a.year ? b.year.compareTo(a.year) : b.month.compareTo(a.month))),
    );
  }

  FeeModel? getFee(String userId, int year, int month) {
    try {
      return _fees.firstWhere((f) => f.userId == userId && f.year == year && f.month == month);
    } catch (_) {
      return null;
    }
  }

  void setFee({required String userId, required String userName, required int year, required int month, required bool isPaid, String? note}) {
    final id = '${userId}_${year}_${month.toString().padLeft(2, '0')}';
    _fees.removeWhere((f) => f.id == id);
    _fees.add(FeeModel(id: id, userId: userId, userName: userName, year: year, month: month, isPaid: isPaid, paidDate: isPaid ? DateTime.now() : null, note: note));
    _feesCtrl.add(List.from(_fees));
  }

  // ── Visits ─────────────────────────────────────────────────
  Stream<List<VisitModel>> streamAllVisits() {
    Future.microtask(() => _visitsCtrl.add(List.from(_visits)));
    return _visitsCtrl.stream.map(
      (list) => (List<VisitModel>.from(list)..sort((a, b) => b.requestDate.compareTo(a.requestDate))),
    );
  }

  Stream<List<VisitModel>> streamUserVisits(String userId) {
    Future.microtask(() => _visitsCtrl.add(List.from(_visits)));
    return _visitsCtrl.stream.map(
      (list) => (list.where((v) => v.userId == userId).toList()
        ..sort((a, b) => b.requestDate.compareTo(a.requestDate))),
    );
  }

  void addVisit(VisitModel visit) {
    _visits.add(visit);
    _visitsCtrl.add(List.from(_visits));
  }

  void updateVisitStatus(String id, String status, {String? adminNote}) {
    final idx = _visits.indexWhere((v) => v.id == id);
    if (idx >= 0) {
      final v = _visits[idx];
      _visits[idx] = VisitModel(
        id: v.id, userId: v.userId, userName: v.userName, phone: v.phone,
        deptName: v.deptName, team: v.team, requestDate: v.requestDate, preferredDate: v.preferredDate,
        status: status, reason: v.reason, adminNote: adminNote ?? v.adminNote,
      );
      if (v.status != status) {
        addNotification(
          userId: v.userId,
          title: '심방 신청 상태 변경',
          body: '심방 신청이 \'${VisitStatus.label(status)}\' 상태로 변경되었습니다.',
          type: 'visit',
        );
      }
    }
    _visitsCtrl.add(List.from(_visits));
  }

  // ── Visit Slots (관리자가 오픈해 둔 심방 가능 시간대) ──────────
  Stream<List<VisitSlotModel>> streamVisitSlots() {
    Future.microtask(() => _visitSlotsCtrl.add(_sortedVisitSlots()));
    return _visitSlotsCtrl.stream.map((_) => _sortedVisitSlots());
  }

  List<VisitSlotModel> _sortedVisitSlots() =>
      (List<VisitSlotModel>.from(_visitSlots)..sort((a, b) => a.dateTime.compareTo(b.dateTime)));

  void addVisitSlots(List<DateTime> dateTimes) {
    for (final dt in dateTimes) {
      _visitSlots.add(VisitSlotModel(id: const Uuid().v4(), dateTime: dt));
    }
    _visitSlotsCtrl.add(_sortedVisitSlots());
  }

  void deleteVisitSlot(String id) {
    _visitSlots.removeWhere((s) => s.id == id);
    _visitSlotsCtrl.add(_sortedVisitSlots());
  }

  // ── Pastor Requests (일반 회원 → 관리자에게 목사 권한 신청) ──────
  Stream<List<PastorRequestModel>> streamPastorRequests() {
    Future.microtask(() => _pastorRequestsCtrl.add(_sortedPastorRequests()));
    return _pastorRequestsCtrl.stream.map((_) => _sortedPastorRequests());
  }

  Stream<List<PastorRequestModel>> streamUserPastorRequests(String userId) {
    Future.microtask(() => _pastorRequestsCtrl.add(_sortedPastorRequests()));
    return _pastorRequestsCtrl.stream.map(
      (_) => _sortedPastorRequests().where((r) => r.userId == userId).toList(),
    );
  }

  List<PastorRequestModel> _sortedPastorRequests() =>
      (List<PastorRequestModel>.from(_pastorRequests)..sort((a, b) => b.requestDate.compareTo(a.requestDate)));

  void addPastorRequest(PastorRequestModel request) {
    _pastorRequests.add(request);
    _pastorRequestsCtrl.add(_sortedPastorRequests());
  }

  void updatePastorRequestStatus(String id, String status) {
    final idx = _pastorRequests.indexWhere((r) => r.id == id);
    if (idx >= 0) {
      final r = _pastorRequests[idx];
      _pastorRequests[idx] = PastorRequestModel(
        id: r.id, userId: r.userId, userName: r.userName, email: r.email,
        requestDate: r.requestDate, status: status,
      );
      addNotification(
        userId: r.userId,
        title: '목사 권한 신청 결과',
        body: status == 'approved' ? '목사 권한 신청이 승인되었습니다.' : '목사 권한 신청이 거절되었습니다.',
        type: 'pastorRequest',
      );
    }
    _pastorRequestsCtrl.add(_sortedPastorRequests());
  }

  void deletePastorRequest(String id) {
    _pastorRequests.removeWhere((r) => r.id == id);
    _pastorRequestsCtrl.add(_sortedPastorRequests());
  }

  // ── New Family Rotation (새가족팀장이 등록하는 주차 1~3별 고정 담당 리더) ──
  Stream<List<NewFamilyRotationModel>> streamNewFamilyRotations() {
    Future.microtask(() => _newFamilyRotationsCtrl.add(_sortedRotations()));
    return _newFamilyRotationsCtrl.stream.map((_) => _sortedRotations());
  }

  List<NewFamilyRotationModel> _sortedRotations() =>
      (List<NewFamilyRotationModel>.from(_newFamilyRotations)..sort((a, b) => a.weekNumber.compareTo(b.weekNumber)));

  // weekNumber 기준 upsert: 이미 등록된 주차면 담당 리더를 교체
  void setNewFamilyRotation(NewFamilyRotationModel rotation) {
    _newFamilyRotations.removeWhere((r) => r.weekNumber == rotation.weekNumber);
    _newFamilyRotations.add(rotation);
    _newFamilyRotationsCtrl.add(_sortedRotations());
    addNotification(
      userId: rotation.leaderId,
      title: '새가족 로테이션 배정',
      body: '${rotation.weekNumber}주차 새가족 로테이션 담당으로 배정되었습니다.',
      type: 'newFamilyRotation',
    );
  }

  // ── Ministry Meetings (사역팀 회의 일정: 일자/주제/논의 내용/정리) ──────
  Stream<List<MinistryMeetingModel>> streamMinistryMeetings(String ministryTeam) {
    Future.microtask(() => _ministryMeetingsCtrl.add(_sortedMeetings()));
    return _ministryMeetingsCtrl.stream.map(
      (_) => _sortedMeetings().where((m) => m.ministryTeam == ministryTeam).toList(),
    );
  }

  List<MinistryMeetingModel> _sortedMeetings() =>
      (List<MinistryMeetingModel>.from(_ministryMeetings)..sort((a, b) => b.date.compareTo(a.date)));

  void addMinistryMeeting(MinistryMeetingModel meeting) {
    _ministryMeetings.add(meeting);
    _ministryMeetingsCtrl.add(_sortedMeetings());
  }

  void updateMinistryMeeting(MinistryMeetingModel meeting) {
    final idx = _ministryMeetings.indexWhere((m) => m.id == meeting.id);
    if (idx >= 0) _ministryMeetings[idx] = meeting;
    _ministryMeetingsCtrl.add(_sortedMeetings());
  }

  void deleteMinistryMeeting(String id) {
    _ministryMeetings.removeWhere((m) => m.id == id);
    _ministryMeetingsCtrl.add(_sortedMeetings());
  }

  // ── Notifications (심방/목사 권한/새가족 로테이션/팀 배정 등 이벤트 알림) ──
  Stream<List<NotificationModel>> streamUserNotifications(String userId) {
    Future.microtask(() => _notificationsCtrl.add(_sortedNotifications()));
    return _notificationsCtrl.stream.map(
      (_) => _sortedNotifications().where((n) => n.userId == userId).toList(),
    );
  }

  List<NotificationModel> _sortedNotifications() =>
      (List<NotificationModel>.from(_notifications)..sort((a, b) => b.createdAt.compareTo(a.createdAt)));

  void addNotification({required String userId, required String title, required String body, required String type}) {
    _notifications.add(NotificationModel(
      id: const Uuid().v4(),
      userId: userId,
      title: title,
      body: body,
      type: type,
      createdAt: DateTime.now(),
    ));
    _notificationsCtrl.add(_sortedNotifications());
  }

  void markNotificationRead(String id) {
    final idx = _notifications.indexWhere((n) => n.id == id);
    if (idx >= 0) _notifications[idx] = _notifications[idx].copyWith(isRead: true);
    _notificationsCtrl.add(_sortedNotifications());
  }

  void markAllNotificationsRead(String userId) {
    for (var i = 0; i < _notifications.length; i++) {
      if (_notifications[i].userId == userId && !_notifications[i].isRead) {
        _notifications[i] = _notifications[i].copyWith(isRead: true);
      }
    }
    _notificationsCtrl.add(_sortedNotifications());
  }

  // ── App Settings (기수 기반 이용 제한 기준) ──────────────────
  Stream<AppSettingsModel> streamAppSettings() {
    Future.microtask(() => _settingsCtrl.add(_settings));
    return _settingsCtrl.stream;
  }

  void updateAppSettings(AppSettingsModel settings) {
    _settings = settings;
    _settingsCtrl.add(_settings);
  }

  // ── Banners ────────────────────────────────────────────────
  Stream<List<BannerModel>> streamActiveBanners() {
    Future.microtask(() => _bannersCtrl.add(_sortedBanners()));
    return _bannersCtrl.stream.map((list) => list.where((b) => b.isVisibleNow).toList());
  }

  Stream<List<BannerModel>> streamAllBanners() {
    Future.microtask(() => _bannersCtrl.add(_sortedBanners()));
    return _bannersCtrl.stream;
  }

  List<BannerModel> _sortedBanners() =>
      (List<BannerModel>.from(_banners)..sort((a, b) => a.order.compareTo(b.order)));

  void addBanner(BannerModel banner) {
    final id = 'banner_${DateTime.now().millisecondsSinceEpoch}';
    _banners.add(BannerModel(
      id: id, title: banner.title, description: banner.description,
      imageUrl: banner.imageUrl, order: _banners.length,
      isActive: banner.isActive, createdAt: banner.createdAt,
    ));
    _bannersCtrl.add(_sortedBanners());
  }

  void updateBanner(BannerModel banner) {
    final idx = _banners.indexWhere((b) => b.id == banner.id);
    if (idx >= 0) _banners[idx] = banner;
    _bannersCtrl.add(_sortedBanners());
  }

  void deleteBanner(String id) {
    _banners.removeWhere((b) => b.id == id);
    _bannersCtrl.add(_sortedBanners());
  }
}
