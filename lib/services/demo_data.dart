import 'dart:async';
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

  final List<UserModel> _users = [
    UserModel(uid: 'admin001', name: '김관리', email: 'admin@church.com', phone: '010-1234-5678', role: 'admin', department: '청년부', joinDate: DateTime(2020, 1, 1)),
    UserModel(uid: 'member001', name: '이청년', email: 'lee@church.com', phone: '010-2345-6789', role: 'member', department: '1부', joinDate: DateTime(2021, 3, 1)),
    UserModel(uid: 'member002', name: '박믿음', email: 'park@church.com', phone: '010-3456-7890', role: 'member', department: '2부', joinDate: DateTime(2021, 6, 1)),
    UserModel(uid: 'member003', name: '최소망', email: 'choi@church.com', phone: '010-4567-8901', role: 'member', department: '1부', joinDate: DateTime(2022, 1, 1)),
    UserModel(uid: 'member004', name: '정사랑', email: 'jung@church.com', phone: '010-5678-9012', role: 'member', department: '2부', joinDate: DateTime(2022, 3, 1)),
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
    final filtered = _attendance
        .where((a) => AttendanceModel.dateKey(a.date) == dateStr)
        .toList();
    final ctrl = StreamController<List<AttendanceModel>>.broadcast();
    Future.microtask(() => ctrl.add(filtered));
    return ctrl.stream;
  }

  Stream<List<AttendanceModel>> streamUserAttendance(String userId) {
    final filtered = _attendance
        .where((a) => a.userId == userId)
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    final ctrl = StreamController<List<AttendanceModel>>.broadcast();
    Future.microtask(() => ctrl.add(filtered));
    return ctrl.stream;
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
    final filtered = _fees.where((f) => f.year == year && f.month == month).toList();
    final ctrl = StreamController<List<FeeModel>>.broadcast();
    Future.microtask(() => ctrl.add(filtered));
    return ctrl.stream;
  }

  Stream<List<FeeModel>> streamUserFees(String userId) {
    final filtered = _fees.where((f) => f.userId == userId).toList()
      ..sort((a, b) => b.year != a.year ? b.year.compareTo(a.year) : b.month.compareTo(a.month));
    final ctrl = StreamController<List<FeeModel>>.broadcast();
    Future.microtask(() => ctrl.add(filtered));
    return ctrl.stream;
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
    final sorted = List<VisitModel>.from(_visits)
      ..sort((a, b) => b.requestDate.compareTo(a.requestDate));
    final ctrl = StreamController<List<VisitModel>>.broadcast();
    Future.microtask(() => ctrl.add(sorted));
    return ctrl.stream;
  }

  Stream<List<VisitModel>> streamUserVisits(String userId) {
    final filtered = _visits.where((v) => v.userId == userId).toList()
      ..sort((a, b) => b.requestDate.compareTo(a.requestDate));
    final ctrl = StreamController<List<VisitModel>>.broadcast();
    Future.microtask(() => ctrl.add(filtered));
    return ctrl.stream;
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
    final filtered = _banners.where((b) => b.isActive).toList()
      ..sort((a, b) => a.order.compareTo(b.order));
    final ctrl = StreamController<List<BannerModel>>.broadcast();
    Future.microtask(() => ctrl.add(filtered));
    return ctrl.stream;
  }

  Stream<List<BannerModel>> streamAllBanners() {
    final sorted = List<BannerModel>.from(_banners)
      ..sort((a, b) => a.order.compareTo(b.order));
    final ctrl = StreamController<List<BannerModel>>.broadcast();
    Future.microtask(() => ctrl.add(sorted));
    return ctrl.stream;
  }

  void addBanner(BannerModel banner) {
    final id = 'banner_${DateTime.now().millisecondsSinceEpoch}';
    _banners.add(BannerModel(
      id: id, title: banner.title, description: banner.description,
      imageUrl: banner.imageUrl, order: _banners.length,
      isActive: banner.isActive, createdAt: banner.createdAt,
    ));
    _bannersCtrl.add(List.from(_banners));
  }

  void updateBanner(BannerModel banner) {
    final idx = _banners.indexWhere((b) => b.id == banner.id);
    if (idx >= 0) _banners[idx] = banner;
    _bannersCtrl.add(List.from(_banners));
  }

  void deleteBanner(String id) {
    _banners.removeWhere((b) => b.id == id);
    _bannersCtrl.add(List.from(_banners));
  }
}
