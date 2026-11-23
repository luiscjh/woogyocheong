import 'dart:js_interop';

// web/index.html의 설치 스크립트와 연결한다
@JS('woogyocheongInstallState')
external JSString _installState();

@JS('woogyocheongInstall')
external JSPromise<JSString> _install();

@JS('woogyocheongOpenExternal')
external JSBoolean _openExternal();

enum WebInstallState {
  installed, // 이미 설치된 앱(독립 창)으로 실행 중
  prompt, // 브라우저 설치 창을 바로 띄울 수 있음(크롬·엣지·삼성 인터넷)
  android, // 안드로이드 브라우저인데 아직 설치 창을 띄울 수 없음(준비 중이거나 이미 설치됨)
  ios, // 아이폰·아이패드: 공유 → 홈 화면에 추가
  inappAndroid, // 안드로이드 카카오톡 등 앱 안의 브라우저: 크롬으로 다시 열어야 함
  inappIos, // iOS 카카오톡 등 앱 안의 브라우저: Safari로 다시 열어야 함
  manual, // 그 밖(PC 등): 브라우저 메뉴에서 설치
}

WebInstallState webInstallState() {
  final state = _installState().toDart;
  return WebInstallState.values.firstWhere((s) => s.name == state, orElse: () => WebInstallState.manual);
}

// 설치 창을 띄우고, 사용자가 설치를 눌렀으면 true
Future<bool> promptWebInstall() async => (await _install().toDart).toDart == 'accepted';

// 앱 안의 브라우저에서 외부 브라우저로 다시 연다. 열 방법이 없으면 false
bool openInExternalBrowser() => _openExternal().toDart;
