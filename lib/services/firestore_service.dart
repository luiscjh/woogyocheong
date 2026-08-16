import 'package:cloud_firestore/cloud_firestore.dart';
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
    final existing = await _db.collection('users').doc(user.uid).get();
    final oldDept = existing.data()?['department'] as String? ?? '';
    await _db.collection('users').doc(user.uid).update(user.toMap());
    if (oldDept.isNotEmpty && oldDept != user.department && user.department.isNotEmpty) {
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

  Future<void> updateVisitStatus(String visitId, String status, {String? adminNote}) async {
    if (demoMode) { _demo.updateVisitStatus(visitId, status, adminNote: adminNote); return; }
    final doc = await _db.collection('visits').doc(visitId).get();
    final oldStatus = doc.data()?['status'] as String? ?? '';
    final visitUserId = doc.data()?['userId'] as String? ?? '';
    final update = <String, dynamic>{'status': status};
    if (adminNote != null) update['adminNote'] = adminNote;
    await _db.collection('visits').doc(visitId).update(update);
    if (visitUserId.isNotEmpty && oldStatus != status) {
      await _addNotification(
        userId: visitUserId,
        title: '심방 신청 상태 변경',
        body: "심방 신청이 '${VisitStatus.label(status)}' 상태로 변경되었습니다.",
        type: 'visit',
      );
    }
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

  // ── Pastor Requests ─────────────────────────────────────────────────────
  Stream<List<PastorRequestModel>> streamPastorRequests() {
    if (demoMode) return _demo.streamPastorRequests();
    return _db.collection('pastorRequests')
        .orderBy('requestDate', descending: true)
        .snapshots()
        .map((s) => s.docs.map(PastorRequestModel.fromFirestore).toList());
  }

  Stream<List<PastorRequestModel>> streamUserPastorRequests(String userId) {
    if (demoMode) return _demo.streamUserPastorRequests(userId);
    return _db.collection('pastorRequests')
        .where('userId', isEqualTo: userId)
        .orderBy('requestDate', descending: true)
        .snapshots()
        .map((s) => s.docs.map(PastorRequestModel.fromFirestore).toList());
  }

  Future<void> requestPastorRole(PastorRequestModel request) async {
    if (demoMode) { _demo.addPastorRequest(request); return; }
    await _db.collection('pastorRequests').doc(request.id).set(request.toMap());
  }

  // 승인: 신청자 역할을 목사님으로 전환하고 신청 상태를 approved로 변경
  Future<void> approvePastorRequest(String requestId, UserModel requester) async {
    await updateUser(requester.copyWith(role: UserRole.pastor));
    await _updatePastorRequestStatus(requestId, 'approved');
  }

  Future<void> rejectPastorRequest(String requestId) async {
    await _updatePastorRequestStatus(requestId, 'rejected');
  }

  Future<void> _updatePastorRequestStatus(String id, String status) async {
    if (demoMode) { _demo.updatePastorRequestStatus(id, status); return; }
    final doc = await _db.collection('pastorRequests').doc(id).get();
    final requesterId = doc.data()?['userId'] as String? ?? '';
    await _db.collection('pastorRequests').doc(id).update({'status': status});
    if (requesterId.isNotEmpty) {
      await _addNotification(
        userId: requesterId,
        title: '목사 권한 신청 결과',
        body: status == 'approved' ? '목사 권한 신청이 승인되었습니다.' : '목사 권한 신청이 거절되었습니다.',
        type: 'pastorRequest',
      );
    }
  }

  // 승인/거절 등 처리가 끝난 신청 기록만 관리자가 삭제(정리) 가능
  Future<void> deletePastorRequest(String id) async {
    if (demoMode) { _demo.deletePastorRequest(id); return; }
    await _db.collection('pastorRequests').doc(id).delete();
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
    await _db.collection('notifications').add({
      'userId': userId,
      'title': title,
      'body': body,
      'type': type,
      'createdAt': Timestamp.fromDate(DateTime.now()),
      'isRead': false,
    });
  }

  // ── App Settings (기수 기반 이용 제한 기준) ─────────────────────────────
  Stream<AppSettingsModel> streamAppSettings() {
    if (demoMode) return _demo.streamAppSettings();
    return _db.collection('settings').doc('app').snapshots().map(AppSettingsModel.fromFirestore);
  }

  Future<void> updateAppSettings(AppSettingsModel settings) async {
    if (demoMode) { _demo.updateAppSettings(settings); return; }
    await _db.collection('settings').doc('app').set(settings.toMap());
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
