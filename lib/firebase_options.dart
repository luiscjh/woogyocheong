import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyBCRwYsL0UbtfLm5Ut91SnsE9cTGPxuqbs',
    appId: '1:484620994680:web:2fa1bf06958735152b058d',
    messagingSenderId: '484620994680',
    projectId: 'conference-c9c99',
    authDomain: 'conference-c9c99.firebaseapp.com',
    storageBucket: 'conference-c9c99.firebasestorage.app',
    measurementId: 'G-G85DR0Z159',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyA-qArPggXhxKoV8ZfY5OGvnQgCD_vhhyI',
    appId: '1:484620994680:android:e1b6162b7fe689652b058d',
    messagingSenderId: '484620994680',
    projectId: 'conference-c9c99',
    storageBucket: 'conference-c9c99.firebasestorage.app',
  );
  // iOS 앱은 Firebase 프로젝트에 등록되어 GoogleService-Info.plist는 실키로
  // 받아뒀지만, 이 맥의 Ruby 툴체인(xcodeproj gem) 문제로 flutterfire configure가
  // Xcode 프로젝트 연동 단계에서 중단돼 Podfile 등 네이티브 설정은 아직 미완료임.
  // 실제 iOS 빌드 전에 flutterfire configure --platforms=ios를 다시 완주해야 함
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyBKbli8uFIMueKn0ri8XVnZ3Yh9KO8ivEQ',
    appId: '1:484620994680:ios:de71546eb58733652b058d',
    messagingSenderId: '484620994680',
    projectId: 'conference-c9c99',
    storageBucket: 'conference-c9c99.firebasestorage.app',
    iosBundleId: 'com.example.churchYouthApp',
  );

  // macOS 앱은 Firebase 프로젝트에 아직 등록하지 않았음(모바일 출시가 목표라 후순위)
  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'demo-api-key',
    appId: '1:123456789:ios:abcdef',
    messagingSenderId: '123456789',
    projectId: 'demo-church-youth',
    storageBucket: 'demo-church-youth.appspot.com',
    iosBundleId: 'com.example.churchYouthApp',
  );
}
