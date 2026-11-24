import 'dart:io';

import 'package:church_youth_app/models/user_model.dart';
import 'package:church_youth_app/screens/auth/onboarding_screen.dart';
import 'package:church_youth_app/utils/privacy_consent.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('동의 항목마다 필수 표시와 보유 기간·거부 권리 안내가 있음', () {
    expect(PrivacyConsent.items, hasLength(3));
    for (final item in PrivacyConsent.items) {
      expect(item.title, startsWith('[필수]'));
      final labels = item.details.map((d) => d.$1).toList();
      expect(labels, containsAll(['보유 기간', '거부 권리']));
    }
  });

  test('방침 버전은 개인정보처리방침의 시행일과 같음', () {
    final html = File('web/privacy.html').readAsStringSync();
    final v = PrivacyConsent.policyVersion.split('-').map(int.parse).toList();
    expect(html, contains('시행일: ${v[0]}년 ${v[1]}월 ${v[2]}일'));
  });

  test('동의 기록은 회원 문서에 저장되고 다시 읽힘', () {
    final at = DateTime(2026, 11, 25, 10, 30);
    final u = UserModel(
      uid: 'u', name: '새회원', email: 'n@x.com', phone: '', role: 'member', department: 'A-1',
      joinDate: DateTime(2026, 11, 25),
    ).copyWith(privacyConsentAt: at, privacyConsentVersion: PrivacyConsent.policyVersion);
    final map = u.toMap();
    expect(map['privacyConsentVersion'], PrivacyConsent.policyVersion);
    expect((map['privacyConsentAt'] as dynamic).toDate(), at);
  });

  // 규칙의 userKeys()에 없는 필드를 쓰면 가입·온보딩이 거부되므로 둘을 맞춰 둠
  test('UserModel.toMap 필드가 firestore.rules의 userKeys()와 같음', () {
    final rules = File('firestore.rules').readAsStringSync();
    final body = RegExp(r'function userKeys\(\) \{\s*return \[([^\]]*)\]').firstMatch(rules)!.group(1)!;
    final ruleKeys = RegExp(r"'(\w+)'").allMatches(body).map((m) => m.group(1)).toSet();
    final mapKeys = UserModel(
      uid: 'u', name: '', email: '', phone: '', role: 'member', department: '', joinDate: DateTime(2026),
    ).toMap().keys.toSet();
    expect(ruleKeys, mapKeys);
  });

  testWidgets('전체 동의는 필수 항목을 모두 체크·해제하고, 항목을 펼치면 안내가 보임', (tester) async {
    var agreed = List<bool>.filled(PrivacyConsent.items.length, false);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: StatefulBuilder(
            builder: (context, setState) => PrivacyConsentSection(
              agreed: agreed,
              onChanged: (i, v) => setState(() => agreed[i] = v),
              onChangedAll: (v) => setState(() => agreed = List.filled(agreed.length, v)),
            ),
          ),
        ),
      ),
    ));

    await tester.tap(find.byKey(const Key('consent-all')));
    await tester.pump();
    expect(agreed, everyElement(isTrue));

    // 항목 하나를 해제하면 전체 동의도 풀림
    await tester.tap(find.byKey(const Key('consent-check-1')));
    await tester.pump();
    expect(agreed, [true, false, true]);
    expect(tester.widget<CheckboxListTile>(find.byKey(const Key('consent-all'))).value, isFalse);

    await tester.tap(find.byKey(const Key('consent-all')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('consent-all')));
    await tester.pump();
    expect(agreed, everyElement(isFalse));

    expect(find.text('Google LLC (미국) — Firebase 로그인 서비스'), findsNothing);
    await tester.tap(find.text('[필수] 개인정보 국외 이전 동의'));
    await tester.pumpAndSettle();
    expect(find.text('Google LLC (미국) — Firebase 로그인 서비스'), findsOneWidget);
  });
}
