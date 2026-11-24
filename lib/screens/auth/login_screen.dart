import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../utils/constants.dart';
import '../../utils/web_install.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    final provider = context.read<AuthProvider>();
    final ok = await provider.signIn(_emailCtrl.text.trim(), _passwordCtrl.text);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(provider.error ?? '로그인 실패'), backgroundColor: AppColors.error),
      );
    }
  }

  Future<void> _signInWithGoogle() async {
    // 카카오톡 등 앱 안의 브라우저는 Google이 로그인을 막아 두었으므로, 시도하기 전에
    // 외부 브라우저(Chrome·Safari)로 다시 열도록 안내
    if (isInAppBrowser()) {
      await _showOpenExternalDialog();
      return;
    }
    final provider = context.read<AuthProvider>();
    final ok = await provider.signInWithGoogle();
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(provider.error ?? 'Google 로그인 실패'), backgroundColor: AppColors.error),
      );
    }
  }

  Future<void> _showOpenExternalDialog() async {
    var failed = false;
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Chrome이나 Safari에서 열어 주세요'),
          content: Text(
            '카카오톡 같은 앱 안의 화면에서는 Google이 로그인을 막아 두었어요.\n'
            '아래 버튼으로 Chrome(아이폰은 Safari)에서 연 뒤 다시 로그인해 주세요.'
            '${failed ? '\n\n이 앱에서는 자동으로 열 수 없어요. 화면 오른쪽 위(또는 아래)의 메뉴(⋯)에서 '
                '"Safari로 열기" 또는 "다른 브라우저로 열기"를 눌러 주세요.' : ''}',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('닫기')),
            ElevatedButton(
              onPressed: () {
                if (!openInExternalBrowser()) setDialogState(() => failed = true);
              },
              child: const Text('브라우저로 열기'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _resetPassword() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('이메일을 입력해 주세요.')),
      );
      return;
    }
    final ok = await context.read<AuthProvider>().resetPassword(email);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ok ? '비밀번호 재설정 메일을 보냈습니다.' : '오류가 발생했습니다.'),
          backgroundColor: ok ? AppColors.success : AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final isLoading = auth.status == AuthStatus.loading;
    // Google 로그인 화면에서 돌아왔는데 실패한 경우의 안내
    final notice = auth.loginNotice;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  const Icon(Icons.church, size: 72, color: AppColors.primary),
                  const SizedBox(height: 12),
                  Text(
                    AppStrings.appName,
                    style: Theme.of(context)
                        .textTheme
                        .headlineMedium
                        ?.copyWith(fontWeight: FontWeight.bold, color: AppColors.primary),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '우리 교회 청년부',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 40),
                  TextFormField(
                    controller: _emailCtrl,
                    decoration: const InputDecoration(
                      labelText: '이메일',
                      prefixIcon: Icon(Icons.email_outlined),
                    ),
                    keyboardType: TextInputType.emailAddress,
                    validator: (v) => (v == null || v.isEmpty) ? '이메일을 입력해 주세요.' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _passwordCtrl,
                    decoration: InputDecoration(
                      labelText: '비밀번호',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility),
                        onPressed: () => setState(() => _obscure = !_obscure),
                      ),
                    ),
                    obscureText: _obscure,
                    validator: (v) => (v == null || v.isEmpty) ? '비밀번호를 입력해 주세요.' : null,
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: _resetPassword,
                      child: const Text('비밀번호 찾기'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: isLoading ? null : _login,
                      child: isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : const Text('로그인'),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Expanded(child: Divider()),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text('또는', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary)),
                      ),
                      const Expanded(child: Divider()),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: isLoading ? null : _signInWithGoogle,
                      icon: const _GoogleLogo(),
                      label: const Text('Google로 로그인'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        side: const BorderSide(color: Color(0xFFDADADA)),
                        foregroundColor: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  if (notice != null) ...[
                    const SizedBox(height: 12),
                    Text(notice, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.error, fontSize: 13)),
                  ],
                  const SizedBox(height: 12),
                  Text(
                    '계정이 없으신가요? Google로 로그인하면 자동으로 가입됩니다.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GoogleLogo extends StatelessWidget {
  const _GoogleLogo();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 20,
      height: 20,
      child: CustomPaint(painter: _GoogleLogoPainter()),
    );
  }
}

class _GoogleLogoPainter extends CustomPainter {
  const _GoogleLogoPainter();

  @override
  void paint(Canvas canvas, Size size) {
    const blue = Color(0xFF4285F4);
    const red = Color(0xFFEA4335);
    const yellow = Color(0xFFFBBC05);
    const green = Color(0xFF34A853);

    final paint = Paint()..style = PaintingStyle.fill;
    final center = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2;

    // Red arc (top-left to bottom-left)
    paint.color = red;
    canvas.drawArc(Rect.fromCircle(center: center, radius: r), 3.525, 1.85, true, paint);
    // Yellow arc (bottom-left to bottom-right)
    paint.color = yellow;
    canvas.drawArc(Rect.fromCircle(center: center, radius: r), 5.375, 1.00, true, paint);
    // Green arc (bottom-right to top-right)
    paint.color = green;
    canvas.drawArc(Rect.fromCircle(center: center, radius: r), 0.05, 1.55, true, paint);
    // Blue arc (top-right to top-left) + right bar
    paint.color = blue;
    canvas.drawArc(Rect.fromCircle(center: center, radius: r), 1.60, 1.92, true, paint);

    // White inner circle
    paint.color = Colors.white;
    canvas.drawCircle(center, r * 0.6, paint);

    // Blue right bar
    paint.color = blue;
    canvas.drawRect(
      Rect.fromLTWH(center.dx, center.dy - r * 0.22, r, r * 0.44),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
