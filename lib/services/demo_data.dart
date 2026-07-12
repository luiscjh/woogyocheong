import 'dart:async';
import 'dart:typed_data';
import '../models/user_model.dart';
import '../models/attendance_model.dart';
import '../models/fee_model.dart';
import '../models/visit_model.dart';
import '../models/banner_model.dart';

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
    // 임원팀 (심방 확정 권한 부여됨)
    UserModel(uid: 'exec001', name: '이임원', email: 'exec@church.com', phone: '010-1111-2222', role: 'executive', department: 'A-1', joinDate: DateTime(2020, 6, 1), permissions: ['visit_confirm']),
    // 중팀장
    UserModel(uid: 'mid001', name: '박중팀', email: 'mid@church.com', phone: '010-2222-3333', role: 'mid_leader', department: 'A-0', joinDate: DateTime(2021, 1, 1)),
    UserModel(uid: 'mid002', name: '최중팀', email: 'midb@church.com', phone: '010-3333-4444', role: 'mid_leader', department: 'B-0', joinDate: DateTime(2021, 1, 1)),
    // 소팀장
    UserModel(uid: 'small001', name: '정소팀', email: 'small@church.com', phone: '010-4444-5555', role: 'small_leader', department: 'A-1', joinDate: DateTime(2021, 6, 1)),
    UserModel(uid: 'small002', name: '한소팀', email: 'smallb@church.com', phone: '010-5555-6666', role: 'small_leader', department: 'A-2', joinDate: DateTime(2021, 6, 1)),
    // 팀원
    UserModel(uid: 'member001', name: '이청년', email: 'lee@church.com', phone: '010-2345-6789', role: 'member', department: 'A-1', joinDate: DateTime(2021, 3, 1)),
    UserModel(uid: 'member002', name: '박믿음', email: 'park@church.com', phone: '010-3456-7890', role: 'member', department: 'A-2', joinDate: DateTime(2021, 6, 1)),
    UserModel(uid: 'member003', name: '최소망', email: 'choi@church.com', phone: '010-4567-8901', role: 'member', department: 'A-1', joinDate: DateTime(2022, 1, 1)),
    UserModel(uid: 'member004', name: '정사랑', email: 'jung@church.com', phone: '010-5678-9012', role: 'member', department: 'B-1', joinDate: DateTime(2022, 3, 1)),
    UserModel(uid: 'member005', name: '강기쁨', email: 'kang@church.com', phone: '010-6789-0123', role: 'member', department: 'B-2', joinDate: DateTime(2022, 6, 1)),
  ];

  final List<AttendanceModel> _attendance = [];
  final List<FeeModel> _fees = [];
  final List<VisitModel> _visits = [];
  final List<BannerModel> _banners = [];

  // StreamControllers
  final _usersCtrl = StreamController<List<UserModel>>.broadcast();
  final _attendanceCtrl = StreamController<List<AttendanceModel>>.broadcast();
  final _feesCtrl = StreamController<List<FeeModel>>.broadcast();
  final _visitsCtrl = StreamController<List<VisitModel>>.broadcast();
  final _bannersCtrl = StreamController<List<BannerModel>>.broadcast();

  void _initDemoData() {
    final now = DateTime.now();
    // 오늘 날짜 기준 최근 주일들 출석 샘플
    for (var i = 0; i < 4; i++) {
      final sunday = now.subtract(Duration(days: now.weekday % 7 + 7 * i));
      final date = DateTime(sunday.year, sunday.month, sunday.day);
      for (final u in _users.where((u) => !u.isAdmin)) {
        _attendance.add(AttendanceModel(
          id: '${u.uid}_${AttendanceModel.dateKey(date)}',
          userId: u.uid,
          userName: u.name,
          date: date,
          isPresent: i < 2 || u.uid != 'member003',
        ));
      }
    }

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
      VisitModel(id: 'v001', userId: 'member001', userName: '이청년', phone: '010-2345-6789', address: '서울시 강남구 테헤란로 123', requestDate: now.subtract(const Duration(days: 5)), status: 'pending', reason: '이사 후 첫 심방 부탁드립니다.'),
      VisitModel(id: 'v002', userId: 'member002', userName: '박믿음', phone: '010-3456-7890', address: '서울시 송파구 잠실로 456', requestDate: now.subtract(const Duration(days: 10)), preferredDate: now.add(const Duration(days: 7)), status: 'confirmed'),
      VisitModel(id: 'v003', userId: 'member003', userName: '최소망', phone: '010-4567-8901', address: '서울시 마포구 합정로 789', requestDate: now.subtract(const Duration(days: 20)), status: 'completed', adminNote: '심방 완료. 잘 지내고 있음.'),
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
    if (idx >= 0) _users[idx] = user;
    _usersCtrl.add(List.from(_users));
  }

  void deleteUser(String uid) {
    _users.removeWhere((u) => u.uid == uid);
    _usersCtrl.add(List.from(_users));
  }

  // ── Attendance ─────────────────────────────────────────────
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
        address: v.address, requestDate: v.requestDate, preferredDate: v.preferredDate,
        status: status, reason: v.reason, adminNote: adminNote ?? v.adminNote,
      );
    }
    _visitsCtrl.add(List.from(_visits));
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
