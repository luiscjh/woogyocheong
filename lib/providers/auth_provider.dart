import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/demo_data.dart';
import '../services/firestore_service.dart' show demoMode;

enum AuthStatus { initial, loading, authenticated, unauthenticated }

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();

  AuthStatus _status = AuthStatus.initial;
  UserModel? _currentUser;
  String? _error;

  AuthStatus get status => _status;
  UserModel? get currentUser => _currentUser;
  String? get error => _error;
  bool get isAdmin => _currentUser?.isAdmin ?? false;

  AuthProvider() {
    if (demoMode) {
      // 데모 모드에서는 로그인 상태 변화를 AuthService의 스트림으로 감지
      _authService.authStateChanges.listen((_) async {
        final user = DemoData.instance.currentUser;
        if (user == null) {
          _currentUser = null;
          _status = AuthStatus.unauthenticated;
        } else {
          _currentUser = user;
          _status = AuthStatus.authenticated;
        }
        notifyListeners();
      });
      // 초기 상태
      Future.microtask(() {
        _status = AuthStatus.unauthenticated;
        notifyListeners();
      });
    } else {
      _authService.authStateChanges.listen((firebaseUser) async {
        if (firebaseUser == null) {
          _currentUser = null;
          _status = AuthStatus.unauthenticated;
        } else {
          _currentUser = await _authService.getCurrentUserModel();
          _status = _currentUser != null
              ? AuthStatus.authenticated
              : AuthStatus.unauthenticated;
        }
        notifyListeners();
      });
    }
  }

  Future<bool> signIn(String email, String password) async {
    _status = AuthStatus.loading;
    _error = null;
    notifyListeners();
    try {
      _currentUser = await _authService.signIn(email, password);
      _status = AuthStatus.authenticated;
      notifyListeners();
      return true;
    } on Exception catch (e) {
      _error = _parseAuthError(e.toString());
      _status = AuthStatus.unauthenticated;
      notifyListeners();
      return false;
    }
  }

  Future<bool> signUp({
    required String email,
    required String password,
    required String name,
    required String phone,
    required String department,
  }) async {
    _status = AuthStatus.loading;
    _error = null;
    notifyListeners();
    try {
      _currentUser = await _authService.signUp(
        email: email,
        password: password,
        name: name,
        phone: phone,
        department: department,
      );
      _status = AuthStatus.authenticated;
      notifyListeners();
      return true;
    } on Exception catch (e) {
      _error = _parseAuthError(e.toString());
      _status = AuthStatus.unauthenticated;
      notifyListeners();
      return false;
    }
  }

  Future<void> signOut() async {
    await _authService.signOut();
    _currentUser = null;
    _status = AuthStatus.unauthenticated;
    notifyListeners();
  }

  Future<bool> signInWithGoogle() async {
    _status = AuthStatus.loading;
    _error = null;
    notifyListeners();
    try {
      _currentUser = await _authService.signInWithGoogle();
      _status = _currentUser != null ? AuthStatus.authenticated : AuthStatus.unauthenticated;
      notifyListeners();
      return _currentUser != null;
    } on Exception catch (e) {
      _error = _parseAuthError(e.toString());
      _status = AuthStatus.unauthenticated;
      notifyListeners();
      return false;
    }
  }

  Future<bool> resetPassword(String email) async {
    try {
      await _authService.resetPassword(email);
      return true;
    } catch (_) {
      return false;
    }
  }

  String _parseAuthError(String error) {
    if (error.contains('user-not-found')) return '등록되지 않은 이메일입니다.';
    if (error.contains('wrong-password')) return '비밀번호가 올바르지 않습니다.';
    if (error.contains('email-already-in-use')) return '이미 사용 중인 이메일입니다.';
    if (error.contains('weak-password')) return '비밀번호는 6자 이상이어야 합니다.';
    if (error.contains('invalid-email')) return '올바르지 않은 이메일 형식입니다.';
    if (error.contains('network-request-failed')) return '네트워크 연결을 확인해 주세요.';
    return '오류가 발생했습니다. 다시 시도해 주세요.';
  }
}
