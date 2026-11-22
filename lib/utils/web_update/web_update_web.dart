import 'dart:js_interop';

// web/index.html의 새 배포 감지 스크립트와 연결한다. 스크립트가 main.dart.js가
// 바뀐 것을 알아채면 woogyocheongOnUpdate를 부르고, 앱이 뜨기 전에 이미 알아챘으면
// woogyocheongUpdateReady를 true로 둔다
@JS('woogyocheongUpdateReady')
external JSBoolean? get _updateReady;

@JS('woogyocheongOnUpdate')
external set _onUpdate(JSFunction? callback);

@JS('woogyocheongReload')
external void _reload();

void watchWebUpdates(void Function() onUpdate) {
  _onUpdate = onUpdate.toJS;
  if (_updateReady?.toDart ?? false) onUpdate();
}

void reloadWebPage() => _reload();
