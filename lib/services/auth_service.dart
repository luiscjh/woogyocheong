import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../models/user_model.dart';
import 'demo_data.dart';
import 'firestore_service.dart';

class AuthService {
  FirebaseAuth get _auth => FirebaseAuth.instance;
  FirebaseFirestore get _firestore => FirebaseFirestore.instance;

  // 데모 모드용 auth state 스트림
  final _demoAuthCtrl = StreamController<User?>.broadcast();
  UserModel? _demoUser;

  Stream<User?> get authStateChanges {
    if (demoMode) return _demoAuthCtrl.stream;
    return _auth.authStateChanges();
  }

  Stream<UserModel?> get demoUserStream => _demoAuthCtrl.stream.map((_) => _demoUser);

  Future<UserModel?> signIn(String email, String password) async {
    if (demoMode) {
      final user = DemoData.instance.findByEmail(email);
      if (user == null) throw Exception('user-not-found');
      if (password.length < 4) throw Exception('wrong-password');
      _demoUser = user;
      DemoData.instance.currentUser = user;
      _demoAuthCtrl.add(null); // null은 단순히 state 변경 신호
      return user;
    }
    final credential = await _auth.signInWithEmailAndPassword(email: email, password: password);
    if (credential.user == null) return null;
    return _fetchUserModel(credential.user!.uid);
  }

  Future<void> signOut() async {
    if (demoMode) {
      _demoUser = null;
      DemoData.instance.currentUser = null;
      _demoAuthCtrl.add(null);
      return;
    }
    await _auth.signOut();
  }

  Future<UserModel?> getCurrentUserModel() async {
    if (demoMode) return _demoUser;
    final user = _auth.currentUser;
    if (user == null) return null;
    return _fetchUserModel(user.uid);
  }

  Future<UserModel?> _fetchUserModel(String uid) async {
    final doc = await _firestore.collection('users').doc(uid).get();
    if (!doc.exists) return null;
    return UserModel.fromFirestore(doc);
  }

  Future<UserModel?> signInWithGoogle() async {
    if (demoMode) {
      const email = 'google_demo@gmail.com';
      var user = DemoData.instance.findByEmail(email);
      if (user == null) {
        // department를 비워두면 앱에서 소속 선택 온보딩 화면으로 안내됨
        user = UserModel(
          uid: 'google_demo_001',
          name: 'Google 데모유저',
          email: email,
          phone: '',
          role: 'member',
          department: '',
          joinDate: DateTime.now(),
        );
        DemoData.instance.addUser(user);
      }
      DemoData.instance.currentUser = user;
      _demoAuthCtrl.add(null);
      return user;
    }

    UserCredential userCredential;
    if (kIsWeb) {
      userCredential = await _auth.signInWithPopup(GoogleAuthProvider());
    } else {
      final googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) return null;
      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      userCredential = await _auth.signInWithCredential(credential);
    }

    final firebaseUser = userCredential.user!;
    var userModel = await _fetchUserModel(firebaseUser.uid);
    if (userModel == null) {
      // department를 비워두면 앱에서 소속 선택 온보딩 화면으로 안내됨
      userModel = UserModel(
        uid: firebaseUser.uid,
        name: firebaseUser.displayName ?? '이름 없음',
        email: firebaseUser.email ?? '',
        phone: '',
        role: 'member',
        department: '',
        joinDate: DateTime.now(),
      );
      await _firestore.collection('users').doc(userModel.uid).set(userModel.toMap());
    }
    return userModel;
  }

  // 회원 탈퇴: Firebase는 오래된 로그인 세션으로 계정 삭제를 막으므로(requires-recent-login)
  // 먼저 본인 확인(재인증)을 받은 뒤, 회원 문서 → 인증 계정 순으로 삭제한다. 인증 계정을
  // 먼저 지우면 규칙상 본인 문서를 더 이상 지울 수 없기 때문. 출석/회비/심방 기록은
  // 청년부 운영 기록으로 남는다(개인정보처리방침에 고지). Google 재인증을 취소하면 false
  Future<bool> deleteAccount({String? password}) async {
    if (demoMode) {
      final me = _demoUser;
      if (me != null) DemoData.instance.deleteUser(me.uid);
      await signOut();
      return true;
    }
    final user = _auth.currentUser;
    if (user == null) return false;

    final isPasswordAccount = user.providerData.any((p) => p.providerId == 'password');
    if (isPasswordAccount) {
      await user.reauthenticateWithCredential(
        EmailAuthProvider.credential(email: user.email ?? '', password: password ?? ''),
      );
    } else if (kIsWeb) {
      await user.reauthenticateWithPopup(GoogleAuthProvider());
    } else {
      // 이미 로그인된 Google 계정이 있으면 signIn()이 화면 없이 바로 통과하므로, 먼저 로그아웃해
      // 본인 확인 화면(계정 선택)이 실제로 뜨게 함
      final googleSignIn = GoogleSignIn();
      await googleSignIn.signOut();
      final googleUser = await googleSignIn.signIn();
      if (googleUser == null) return false;
      final googleAuth = await googleUser.authentication;
      await user.reauthenticateWithCredential(GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      ));
    }

    await _firestore.collection('users').doc(user.uid).delete();
    try {
      await user.delete();
    } catch (_) {
      // 회원 문서는 이미 지워졌으므로 그대로 두면 정보 없는 로그인 상태가 남음 — 로그아웃시키고
      // 호출부에서 개인정보처리방침의 삭제 요청 경로를 안내
      await signOut();
      throw Exception('account-delete-incomplete');
    }
    if (!kIsWeb) await GoogleSignIn().signOut();
    return true;
  }

  // 탈퇴 시 비밀번호 재확인이 필요한 계정(이메일/비밀번호 로그인)인지
  bool get needsPasswordForDeletion =>
      !demoMode && (_auth.currentUser?.providerData.any((p) => p.providerId == 'password') ?? false);

  Future<void> resetPassword(String email) async {
    if (demoMode) return; // 데모에서는 아무것도 안 함
    await _auth.sendPasswordResetEmail(email: email);
  }
}
