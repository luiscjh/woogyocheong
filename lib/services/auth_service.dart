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

  Future<UserModel> signUp({
    required String email,
    required String password,
    required String name,
    required String phone,
    required String department,
    String role = 'member',
  }) async {
    if (demoMode) {
      // 데모에서는 이미 있는 이메일 체크만
      if (DemoData.instance.findByEmail(email) != null) {
        throw Exception('email-already-in-use');
      }
      final uid = 'demo_${DateTime.now().millisecondsSinceEpoch}';
      final user = UserModel(uid: uid, name: name, email: email, phone: phone, role: role, department: department, joinDate: DateTime.now());
      DemoData.instance.addUser(user);
      _demoUser = user;
      DemoData.instance.currentUser = user;
      _demoAuthCtrl.add(null);
      return user;
    }
    final credential = await _auth.createUserWithEmailAndPassword(email: email, password: password);
    final uid = credential.user!.uid;
    final user = UserModel(uid: uid, name: name, email: email, phone: phone, role: role, department: department, joinDate: DateTime.now());
    await _firestore.collection('users').doc(uid).set(user.toMap());
    return user;
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
        user = UserModel(
          uid: 'google_demo_001',
          name: 'Google 데모유저',
          email: email,
          phone: '',
          role: 'member',
          department: '청년부',
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
      userModel = UserModel(
        uid: firebaseUser.uid,
        name: firebaseUser.displayName ?? '이름 없음',
        email: firebaseUser.email ?? '',
        phone: '',
        role: 'member',
        department: '청년부',
        joinDate: DateTime.now(),
      );
      await _firestore.collection('users').doc(userModel.uid).set(userModel.toMap());
    }
    return userModel;
  }

  Future<void> resetPassword(String email) async {
    if (demoMode) return; // 데모에서는 아무것도 안 함
    await _auth.sendPasswordResetEmail(email: email);
  }
}
