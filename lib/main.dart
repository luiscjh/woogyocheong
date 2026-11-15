import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'firebase_options.dart';
import 'providers/auth_provider.dart' as app_auth;
import 'screens/auth/login_screen.dart';
import 'screens/auth/onboarding_screen.dart';
import 'screens/home/home_screen.dart';
import 'services/demo_data.dart';
import 'services/firestore_service.dart' show demoMode;
import 'utils/theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (demoMode) {
    // 데모 모드: Firebase 초기화 없이 인메모리 데이터 사용
    DemoData.instance.init();
  } else {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  }

  await initializeDateFormatting('ko', null);
  runApp(const ChurchYouthApp());
}

class ChurchYouthApp extends StatelessWidget {
  const ChurchYouthApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => app_auth.AuthProvider()),
      ],
      child: MaterialApp(
        title: '우교청',
        theme: buildAppTheme(),
        debugShowCheckedModeBanner: false,
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        supportedLocales: const [Locale('ko'), Locale('en')],
        home: const _RootRouter(),
      ),
    );
  }
}

class _RootRouter extends StatelessWidget {
  const _RootRouter();

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<app_auth.AuthProvider>();
    switch (authProvider.status) {
      case app_auth.AuthStatus.initial:
      case app_auth.AuthStatus.loading:
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      case app_auth.AuthStatus.authenticated:
        if (authProvider.needsOnboarding) return const OnboardingScreen();
        // 역할·소속이 바뀌면(테스트 계정 역할 변경, 역할 양도 등) 홈 화면을 새로
        // 만들어, 이전 역할 기준으로 남아 있던 탭 선택·각 탭 화면 상태를 버림
        final u = authProvider.currentUser!;
        return HomeScreen(
          key: ValueKey('${u.uid}|${u.role}|${u.department}|${u.ministryTeam}|${u.isMinistryLead}|${u.bannerAccessGranted}'),
        );
      case app_auth.AuthStatus.unauthenticated:
        return const LoginScreen();
    }
  }
}
