import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'firebase_options.dart';
import 'providers/auth_provider.dart' as app_auth;
import 'screens/auth/login_screen.dart';
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
        home: const _RootRouter(),
      ),
    );
  }
}

class _RootRouter extends StatelessWidget {
  const _RootRouter();

  @override
  Widget build(BuildContext context) {
    final status = context.watch<app_auth.AuthProvider>().status;
    switch (status) {
      case app_auth.AuthStatus.initial:
      case app_auth.AuthStatus.loading:
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      case app_auth.AuthStatus.authenticated:
        return const HomeScreen();
      case app_auth.AuthStatus.unauthenticated:
        return const LoginScreen();
    }
  }
}
