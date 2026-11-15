import 'dart:convert';
import 'dart:io';

import 'package:church_youth_app/models/attendance_model.dart';
import 'package:church_youth_app/services/push_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PushService.isSupportedFor', () {
    test('Android/iOS 앱에서만 사용', () {
      expect(PushService.isSupportedFor(isWeb: false, demo: false, platform: TargetPlatform.android), isTrue);
      expect(PushService.isSupportedFor(isWeb: false, demo: false, platform: TargetPlatform.iOS), isTrue);
    });
    test('웹(서비스 워커 없음 정책)·데모 모드·데스크톱은 제외', () {
      for (final p in TargetPlatform.values) {
        expect(PushService.isSupportedFor(isWeb: true, demo: false, platform: p), isFalse);
        expect(PushService.isSupportedFor(isWeb: false, demo: true, platform: p), isFalse);
      }
      expect(PushService.isSupportedFor(isWeb: false, demo: false, platform: TargetPlatform.macOS), isFalse);
      expect(PushService.isSupportedFor(isWeb: false, demo: false, platform: TargetPlatform.windows), isFalse);
    });
    test('테스트 환경(데스크톱 VM)에서는 아무 동작도 하지 않음', () async {
      // Firebase 초기화 없이 불러도 예외 없이 끝나야 함(isSupported=false)
      await PushService.instance.register('uid');
      await PushService.instance.unregister();
      await PushService.instance.detach();
    });
  });

  test('토큰 문서 필드가 firestore.rules validFcmToken과 같음', () {
    final data = PushService.tokenDocData('tok', TargetPlatform.android);
    expect(data.keys.toSet(), {'token', 'platform', 'updatedAt'});
    expect(data['token'], 'tok');
    expect(data['platform'], 'android');
    expect(data['updatedAt'], isA<FieldValue>());
    expect(PushService.tokenDocData('tok', TargetPlatform.iOS)['platform'], 'ios');

    final rules = File('firestore.rules').readAsStringSync();
    expect(rules, contains("hasOnly(['token', 'platform', 'updatedAt'])"));
    expect(rules, contains("platform in ['android', 'ios']"));
  });

  test('Cloud Function의 KST 날짜 키가 AttendanceModel.dateKey와 같은 형식', () {
    // functions/test/kst.test.ts와 같은 표를 사용: 그 순간의 한국 날짜로 앱이 만드는 키와 비교
    final fixture = jsonDecode(File('functions/test/fixtures/attendance_date_keys.json').readAsStringSync());
    for (final c in fixture['cases'] as List) {
      final kst = DateTime.parse(c['utc'] as String).toUtc().add(const Duration(hours: 9));
      final localKstDate = DateTime(kst.year, kst.month, kst.day); // 한국 기기에서의 오늘
      expect(AttendanceModel.dateKey(localKstDate), c['key'], reason: c['note'] as String);
      expect(localKstDate.weekday % 7, c['weekday'], reason: c['note'] as String);
    }
  });
}
