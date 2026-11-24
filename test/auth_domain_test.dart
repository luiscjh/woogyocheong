import 'package:church_youth_app/firebase_options.dart';
import 'package:church_youth_app/utils/auth_domain.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const web = DefaultFirebaseOptions.web;

  test('두 Hosting 주소에서는 접속한 주소를 authDomain으로(같은 출처 로그인)', () {
    expect(withHostAuthDomain(web, 'woogyochung.web.app').authDomain, 'woogyochung.web.app');
    expect(withHostAuthDomain(web, 'conference-c9c99.web.app').authDomain, 'conference-c9c99.web.app');
  });

  test('그 밖의 주소(로컬 등)는 기본 authDomain 유지', () {
    expect(withHostAuthDomain(web, 'localhost').authDomain, 'conference-c9c99.firebaseapp.com');
    expect(withHostAuthDomain(web, '127.0.0.1').authDomain, 'conference-c9c99.firebaseapp.com');
  });

  test('authDomain 외 값은 그대로', () {
    final o = withHostAuthDomain(web, 'woogyochung.web.app');
    expect(o.apiKey, web.apiKey);
    expect(o.projectId, web.projectId);
    expect(o.appId, web.appId);
  });
}
