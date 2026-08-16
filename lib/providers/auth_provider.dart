import 'dart:async';
import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../models/app_settings_model.dart';
import '../services/auth_service.dart';
import '../services/demo_data.dart';
import '../services/firestore_service.dart';
import '../utils/constants.dart';

enum AuthStatus { initial, loading, authenticated, unauthenticated }

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();
  final FirestoreService _firestoreService = FirestoreService();
  StreamSubscription<AppSettingsModel>? _settingsSub;

  AuthStatus _status = AuthStatus.initial;
  UserModel? _currentUser;
  String? _error;
  AppSettingsModel? _settings;

  AuthStatus get status => _status;
  UserModel? get currentUser => _currentUser;
  String? get error => _error;

  // Google 최초 가입 시 소속(팀)을 아직 선택하지 않은 상태
  bool get needsOnboarding => _currentUser != null && _currentUser!.department.isEmpty;

  bool get isAdmin => _currentUser?.isAdmin ?? false;
  bool get isExecutive => _currentUser?.isExecutive ?? false;
  bool get isMidLeader => _currentUser?.isMidLeader ?? false;
  bool get isSmallLeader => _currentUser?.isSmallLeader ?? false;
  // 사역팀(콘텐츠팀 등) 소속 여부/팀장 여부 — department와 독립된 별도 축
  bool get isMinistryLead => _currentUser?.isMinistryLead ?? false;
  bool get inContentTeam => _currentUser?.ministryTeam == AppTeams.contentTeam;

  // 출석/회비 수정 권한: 소팀장 이상
  bool get canEditAttendance => isSmallLeader;
  // 출석/회비 팀 조회 권한: 중팀장 이상
  bool get canViewTeam => isMidLeader;
  // 배너 관리 권한: 임원팀 이상이거나, 콘텐츠팀 팀장(고유 권한), 또는 팀장이
  // 직접 지정하여 권한을 공유받은 콘텐츠팀 팀원만 해당
  bool get canManageBanners =>
      isExecutive || (inContentTeam && isMinistryLead) || (inContentTeam && (_currentUser?.bannerAccessGranted ?? false));
  // 배너 관리 권한 "공유"(위임)를 실행할 수 있는지 여부: 관리자 또는 콘텐츠팀 팀장만 가능
  bool get canShareBannerAccess => isAdmin || (isMinistryLead && inContentTeam);
  // 회원 관리 권한: 소팀장 이상
  bool get canManageMembers => isSmallLeader;
  // 관리 탭 진입 권한: 회원 관리 권한, 배너 관리 권한이 있거나, 사역팀(콘텐츠팀) 소속으로
  // 회의 일정을 조회할 수 있는 경우
  bool get canAccessAdminTab => canManageMembers || canManageBanners || inContentTeam;

  AppSettingsModel? get appSettings => _settings;

  // 기수 기반 이용 제한 여부 — true이면 출석 체크/회비 납부/심방 신청 등 쓰기 동작이
  // 막히고 조회만 가능함. 목사님은 예외이며, 기수가 아직 등록되지 않았거나(cohort==null)
  // 설정값을 아직 못 불러온 경우에는 안전하게 제한하지 않음
  bool get isCohortRestricted {
    final user = _currentUser;
    final settings = _settings;
    if (user == null || settings == null) return false;
    if (user.role == UserRole.pastor) return false;
    final cohort = user.cohort;
    if (cohort == null) return false;
    return cohort < settings.minAllowedCohort || cohort > settings.maxAllowedCohort;
  }

  AuthProvider() {
    _settingsSub = _firestoreService.streamAppSettings().listen((settings) {
      _settings = settings;
      notifyListeners();
    });
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

  @override
  void dispose() {
    _settingsSub?.cancel();
    super.dispose();
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

  // 본인 역할 양도 등, 본인 데이터가 외부에서 갱신된 경우 세션에 즉시 반영
  void setCurrentUser(UserModel user) {
    _currentUser = user;
    if (demoMode) DemoData.instance.currentUser = user;
    notifyListeners();
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
