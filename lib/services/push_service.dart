import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'firestore_service.dart' show demoMode;

// 푸시 알림(FCM) 수신 등록 — Android/iOS 앱에서만 동작한다.
// - 웹은 일부러 제외: 웹 푸시는 서비스 워커가 필요한데, 웹 빌드는 서비스
//   워커 없이 운영하기로 했다(web/index.html이 남은 워커를 전부 해제함).
//   그래서 웹에서는 FirebaseMessaging API를 한 번도 호출하지 않는다
//   (getToken이 firebase-messaging-sw.js를 등록하기 때문)
// - demoMode(Firebase 없이 인메모리)에서도 아무것도 하지 않는다
// - 토큰은 users/{uid}/fcmTokens/{token}에 {token, platform, updatedAt}로
//   저장하고, Cloud Functions(functions/)가 알림 문서 생성 시 이 토큰으로
//   발송한다. 로그아웃/탈퇴 시 이 기기의 토큰 문서를 지운다
class PushService {
  PushService._();
  static final PushService instance = PushService._();

  // 포그라운드에서 받은 알림을 SnackBar로 보여주기 위한 키(MaterialApp에 연결)
  final GlobalKey<ScaffoldMessengerState> messengerKey = GlobalKey<ScaffoldMessengerState>();

  String? _uid;
  String? _token;
  StreamSubscription<String>? _refreshSub;
  StreamSubscription<RemoteMessage>? _messageSub;

  // 푸시를 쓰는 플랫폼인지 — 테스트에서 각 조건을 넣어 볼 수 있게 분리
  @visibleForTesting
  static bool isSupportedFor({required bool isWeb, required bool demo, required TargetPlatform platform}) {
    if (isWeb || demo) return false;
    return platform == TargetPlatform.android || platform == TargetPlatform.iOS;
  }

  static bool get isSupported =>
      isSupportedFor(isWeb: kIsWeb, demo: demoMode, platform: defaultTargetPlatform);

  // users/{uid}/fcmTokens/{token} 문서 내용 — firestore.rules의 validFcmToken()과
  // 필드가 정확히 같아야 함(추가 필드를 넣으면 규칙에서 거부됨)
  @visibleForTesting
  static Map<String, dynamic> tokenDocData(String token, TargetPlatform platform) {
    return {
      'token': token,
      'platform': platform == TargetPlatform.iOS ? 'ios' : 'android',
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  DocumentReference<Map<String, dynamic>> _tokenRef(String uid, String token) =>
      FirebaseFirestore.instance.collection('users').doc(uid).collection('fcmTokens').doc(token);

  // 로그인(회원 문서 확인) 직후 호출. 같은 uid로 여러 번 불려도 한 번만 등록한다.
  // 알림 권한 거부·APNs 미설정(iOS 서명 전) 등으로 실패해도 앱 사용에는 영향 없게
  // 오류를 삼킨다
  Future<void> register(String uid) async {
    if (!isSupported || _uid == uid) return;
    if (_uid != null) await _stopListening();
    _uid = uid;
    try {
      final messaging = FirebaseMessaging.instance;
      // iOS 권한 창, Android 13+ POST_NOTIFICATIONS 권한 요청(그 이하 버전은 바로 허용)
      final settings = await messaging.requestPermission(alert: true, badge: true, sound: true);
      if (settings.authorizationStatus == AuthorizationStatus.denied) return;
      // iOS 포그라운드 수신 시 시스템 배너는 띄우지 않고 아래 SnackBar로만 표시
      await messaging.setForegroundNotificationPresentationOptions(alert: false, badge: true, sound: false);
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        // APNs 토큰은 앱 시작 직후 잠깐 늦게 올 수 있어 몇 초 기다린다. 끝내 없으면
        // Apple 개발자 계정/APNs 키/Push 권한이 설정되지 않은 빌드 — FCM 토큰을 받을 수 없음
        String? apns;
        for (var i = 0; i < 5 && apns == null; i++) {
          apns = await messaging.getAPNSToken();
          if (apns == null) await Future<void>.delayed(const Duration(seconds: 1));
        }
        if (apns == null || _uid != uid) return;
      }
      final token = await messaging.getToken();
      if (_uid != uid) return; // 그사이 로그아웃/계정 전환
      if (token != null) {
        await _saveToken(uid, token);
        if (_uid != uid) {
          // 저장하는 사이 로그아웃됨 — 방금 쓴 문서를 되돌림(이미 인증이 없으면 실패해도 무방)
          _token = null;
          try {
            await _tokenRef(uid, token).delete();
          } catch (_) {}
          return;
        }
      }
      _refreshSub = messaging.onTokenRefresh.listen((t) async {
        final current = _uid;
        if (current == null) return;
        final old = _token;
        try {
          await _saveToken(current, t);
          if (old != null && old != t) await _tokenRef(current, old).delete();
        } catch (e) {
          debugPrint('FCM 토큰 갱신 저장 실패: $e');
        }
      });
      _messageSub = FirebaseMessaging.onMessage.listen(_showForeground);
    } catch (e) {
      debugPrint('푸시 등록 실패(앱 사용에는 영향 없음): $e');
    }
  }

  Future<void> _saveToken(String uid, String token) async {
    _token = token;
    await _tokenRef(uid, token).set(tokenDocData(token, defaultTargetPlatform));
  }

  void _showForeground(RemoteMessage message) {
    final n = message.notification;
    if (n == null) return;
    final text = [n.title, n.body].where((s) => s != null && s.isNotEmpty).join('\n');
    if (text.isEmpty) return;
    messengerKey.currentState?.showSnackBar(
      SnackBar(content: Text(text), duration: const Duration(seconds: 4)),
    );
  }

  Future<void> _stopListening() async {
    await _refreshSub?.cancel();
    await _messageSub?.cancel();
    _refreshSub = null;
    _messageSub = null;
  }

  // 로그아웃/탈퇴 직전(아직 로그인 상태일 때) 호출 — 이 기기의 토큰 문서를 지우고
  // FCM 토큰 자체도 폐기해, 다음 사람이 같은 기기로 로그인해도 이전 계정 알림이
  // 오지 않게 한다. 실패해도 로그아웃은 계속 진행(남은 토큰은 서버의 무효 토큰
  // 정리·60일 정리 작업이 지움)
  Future<void> unregister() async {
    if (!isSupported) return;
    final uid = _uid;
    final token = _token;
    _uid = null;
    _token = null;
    await _stopListening();
    try {
      if (uid != null && token != null) await _tokenRef(uid, token).delete();
      await FirebaseMessaging.instance.deleteToken();
    } catch (e) {
      debugPrint('푸시 해제 실패: $e');
    }
  }

  // 로그인 세션이 외부 요인(토큰 만료 등)으로 끊겼을 때 — 이미 인증이 없어
  // 문서는 지울 수 없으므로 리스너만 정리
  Future<void> detach() async {
    if (!isSupported) return;
    _uid = null;
    _token = null;
    await _stopListening();
  }
}
