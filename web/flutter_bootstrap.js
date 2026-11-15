{{flutter_js}}
{{flutter_build_config}}

// 우교청은 서비스 워커를 쓰지 않는다. serviceWorkerSettings 없이 로드해
// Flutter 기본 서비스 워커(flutter_service_worker.js) 등록도 끈다.
// 업데이트는 firebase.json의 Cache-Control: no-cache로 매 접속마다 반영된다.
_flutter.loader.load();
