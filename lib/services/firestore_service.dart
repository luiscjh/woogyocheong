import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import '../models/attendance_model.dart';
import '../models/fee_model.dart';
import '../models/visit_model.dart';
import '../models/banner_model.dart';
import '../utils/constants.dart';
import 'demo_data.dart';

// demoMode = true 이면 Firebase 없이 인메모리 저장소를 사용
const bool demoMode = true;

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

  Future<void> updateUser(UserModel user) async {
    if (demoMode) { _demo.updateUser(user); return; }
    await _db.collection('users').doc(user.uid).update(user.toMap());
  }

  Future<void> deleteUser(String uid) async {
    if (demoMode) { _demo.deleteUser(uid); return; }
    await _db.collection('users').doc(uid).delete();
  }

  // 역할 양도: outgoing의 역할/추가 권한을 incoming에게 넘기고 outgoing은 팀원으로 전환
  Future<void> transferRole(UserModel outgoing, UserModel incoming) async {
    await updateUser(incoming.copyWith(role: outgoing.role, permissions: outgoing.permissions));
    await updateUser(outgoing.copyWith(role: UserRole.member, permissions: const []));
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

  Future<void> updateVisitStatus(String visitId, String status, {String? adminNote}) async {
    if (demoMode) { _demo.updateVisitStatus(visitId, status, adminNote: adminNote); return; }
    final update = <String, dynamic>{'status': status};
    if (adminNote != null) update['adminNote'] = adminNote;
    await _db.collection('visits').doc(visitId).update(update);
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
