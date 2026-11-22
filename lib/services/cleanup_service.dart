import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import 'firestore_service.dart' show demoMode;

// 보관 기간이 지난 기록 정리 — 서버 예약 작업(Cloud Functions dailyCleanup)은
// Blaze 요금제가 필요해 배포하지 않았으므로, 그동안은 앱이 로그인할 때 대신 지운다.
// 그래서 정확히 기간이 되는 날이 아니라 기간이 지난 뒤 처음 앱을 열 때 지워진다
// - 앱 내 알림: 본인 알림 중 90일 지난 것(규칙도 본인 + 90일 지난 것만 삭제 허용)
// - 리더 명단 엑셀(leaderRosterUploads): expiresAt(반영 후 30일) 지난 것, 관리자만
// 실패해도 앱 사용에는 영향이 없도록 조용히 넘어가고 다음 로그인 때 다시 시도한다
class CleanupService {
  CleanupService._();
  static final CleanupService instance = CleanupService._();

  // firestore.rules의 notifications 삭제 조건(90일)과 같아야 함. 기기 시계가
  // 조금 빨라도 규칙에서 거부되지 않도록 앱은 하루 더 지난 것만 지운다
  static const notificationRetention = Duration(days: 90);
  static const _clockMargin = Duration(days: 1);

  String? _doneFor;

  Future<void> run({required String uid, required bool isAdmin}) async {
    if (demoMode || _doneFor == uid) return;
    _doneFor = uid;
    try {
      await _deleteOldNotifications(uid);
      if (isAdmin) await _deleteExpiredRosterUploads();
    } catch (e) {
      debugPrint('보관 기간 정리 실패(다음 로그인 때 재시도): $e');
      _doneFor = null;
    }
  }

  @visibleForTesting
  static bool isExpiredNotification(DateTime createdAt, DateTime now) =>
      createdAt.isBefore(now.subtract(notificationRetention + _clockMargin));

  Future<void> _deleteOldNotifications(String uid) async {
    final db = FirebaseFirestore.instance;
    // userId 단일 조건만 쓰고(별도 색인 불필요) 날짜는 앱에서 거른다 — 회원당 알림 수가 적음
    final snap = await db.collection('notifications').where('userId', isEqualTo: uid).get();
    final now = DateTime.now();
    final old = snap.docs.where((d) {
      final createdAt = d.data()['createdAt'];
      return createdAt is Timestamp && isExpiredNotification(createdAt.toDate(), now);
    }).toList();
    await _deleteAll(old.map((d) => d.reference).toList());
  }

  Future<void> _deleteExpiredRosterUploads() async {
    final snap = await FirebaseFirestore.instance
        .collection('leaderRosterUploads')
        .where('expiresAt', isLessThan: Timestamp.now())
        .get();
    await _deleteAll(snap.docs.map((d) => d.reference).toList());
  }

  // 한 번에 최대 500개까지 묶어 지운다(Firestore batch 한도)
  Future<void> _deleteAll(List<DocumentReference> refs) async {
    for (var i = 0; i < refs.length; i += 500) {
      final batch = FirebaseFirestore.instance.batch();
      for (final ref in refs.skip(i).take(500)) {
        batch.delete(ref);
      }
      await batch.commit();
    }
  }
}
