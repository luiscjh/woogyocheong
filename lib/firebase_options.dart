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

  // 에뮬레이터용 설정 (demo 프로젝트 ID 사용)
  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'demo-api-key',
    appId: '1:123456789:web:abcdef',
    messagingSenderId: '123456789',
    projectId: 'demo-church-youth',
    authDomain: 'demo-church-youth.firebaseapp.com',
    storageBucket: 'demo-church-youth.appspot.com',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'demo-api-key',
    appId: '1:123456789:android:abcdef',
    messagingSenderId: '123456789',
    projectId: 'demo-church-youth',
    storageBucket: 'demo-church-youth.appspot.com',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'demo-api-key',
    appId: '1:123456789:ios:abcdef',
    messagingSenderId: '123456789',
    projectId: 'demo-church-youth',
    storageBucket: 'demo-church-youth.appspot.com',
    iosBundleId: 'com.example.churchYouthApp',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'demo-api-key',
    appId: '1:123456789:ios:abcdef',
    messagingSenderId: '123456789',
    projectId: 'demo-church-youth',
    storageBucket: 'demo-church-youth.appspot.com',
    iosBundleId: 'com.example.churchYouthApp',
  );
}
