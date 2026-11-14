{{flutter_js}}
{{flutter_build_config}}

// 우교청 PWA: Flutter 기본 서비스 워커(flutter_service_worker.js)는 Flutter
// 3.3x 이후 deprecated 되어 "스스로 등록 해제"만 하는 정리용 워커로 바뀌었다.
// 그걸 등록하면 우리 sw.js 등록까지 같은 scope에서 해제해 버리므로,
// serviceWorkerSettings 없이 로드해 Flutter 쪽 워커 등록을 끈다.
// 서비스 워커는 index.html에서 sw.js로 직접 등록한다.
_flutter.loader.load();
