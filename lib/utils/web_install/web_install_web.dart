import 'dart:js_interop';

// web/index.html의 설치 스크립트와 연결한다
@JS('woogyocheongInstallState')
external JSString _installState();

@JS('woogyocheongInstall')
external JSPromise<JSString> _install();

enum WebInstallState {
  installed, // 이미 설치된 앱(독립 창)으로 실행 중
  prompt, // 브라우저 설치 창을 바로 띄울 수 있음(크롬·엣지·삼성 인터넷)
  ios, // 아이폰·아이패드: 공유 → 홈 화면에 추가
  inapp, // 카카오톡 등 앱 안의 브라우저: 설치 불가, 다른 브라우저로 열어야 함
  manual, // 그 밖(이미 설치했거나 설치 창을 띄울 수 없는 브라우저): 메뉴에서 설치
}

WebInstallState webInstallState() {
  final state = _installState().toDart;
  return WebInstallState.values.firstWhere((s) => s.name == state, orElse: () => WebInstallState.manual);
}

// 설치 창을 띄우고, 사용자가 설치를 눌렀으면 true
Future<bool> promptWebInstall() async => (await _install().toDart).toDart == 'accepted';
