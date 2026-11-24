import 'package:firebase_core/firebase_core.dart';

// 웹 Google 로그인을 지금 접속한 Hosting 주소에서 직접 처리하도록 authDomain을 바꾼다.
// 기본값(conference-c9c99.firebaseapp.com)은 다른 사이트라, Safari(ITP)와 최신 Chrome이
// 다른 사이트 저장공간을 막으면 로그인 결과를 받지 못해 오류가 난다. 두 Hosting 사이트
// 모두 /__/auth/handler를 제공하며, Google OAuth 웹 클라이언트에 각 주소의
// 승인된 JavaScript 원본과 리디렉션 URI(https://<주소>/__/auth/handler)가 등록돼 있어야 함
const hostingAuthDomains = {'woogyochung.web.app', 'conference-c9c99.web.app'};

FirebaseOptions withHostAuthDomain(FirebaseOptions options, String host) =>
    hostingAuthDomains.contains(host) ? options.copyWith(authDomain: host) : options;
