import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/firestore_service.dart';
import '../../utils/constants.dart';

// Google 로그인으로 처음 가입한 회원의 소속(이름/팀)을 입력받는 온보딩 화면
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _cohortCtrl;
  String? _selectedTeam;
  DateTime? _birthDate;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthProvider>().currentUser;
    _nameCtrl = TextEditingController(text: user?.name ?? '');
    _cohortCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _cohortCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickBirthDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(2000, 1, 1),
      firstDate: DateTime(1950),
      lastDate: DateTime.now(),
      locale: const Locale('ko'),
    );
    if (picked != null) setState(() => _birthDate = picked);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_birthDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('생년월일을 선택해 주세요.'), backgroundColor: AppColors.warning),
      );
      return;
    }
    final authProvider = context.read<AuthProvider>();
    final user = authProvider.currentUser;
    if (user == null) return;

    setState(() => _isLoading = true);
    try {
      final updated = user.copyWith(
        name: _nameCtrl.text.trim(),
        department: _selectedTeam,
        birthDate: _birthDate,
        cohort: int.parse(_cohortCtrl.text.trim()),
      );
      await FirestoreService().updateUser(updated, previousDepartment: user.department);
      if (!mounted) return;
      authProvider.setCurrentUser(updated);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.church, size: 64, color: AppColors.primary),
                  const SizedBox(height: 12),
                  const Text(
                    '소속 등록',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.primary),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '우교청에 처음 오셨네요! 이름, 소속 팀, 생년월일, 기수를 입력해 주세요.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 32),
                  TextFormField(
                    controller: _nameCtrl,
                    decoration: const InputDecoration(
                      labelText: '이름 *',
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty) ? '이름을 입력해 주세요.' : null,
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: _selectedTeam,
                    decoration: const InputDecoration(
                      labelText: '팀 선택 *',
                      prefixIcon: Icon(Icons.groups_outlined),
                    ),
                    hint: const Text('소속 팀을 선택해 주세요'),
                    items: AppTeams.smallTeams
                        .map((t) => DropdownMenuItem(value: t, child: Text(AppTeams.deptLabel(t))))
                        .toList(),
                    onChanged: (v) => setState(() => _selectedTeam = v),
                    validator: (v) => (v == null || v.isEmpty) ? '팀을 선택해 주세요.' : null,
                  ),
                  const SizedBox(height: 16),
                  InkWell(
                    onTap: _pickBirthDate,
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: '생년월일 *',
                        prefixIcon: Icon(Icons.cake_outlined),
                      ),
                      child: Text(
                        _birthDate != null ? DateFormat('yyyy년 MM월 dd일').format(_birthDate!) : '생년월일을 선택해 주세요',
                        style: TextStyle(color: _birthDate != null ? null : Theme.of(context).hintColor),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _cohortCtrl,
                    decoration: const InputDecoration(
                      labelText: '기수 *',
                      prefixIcon: Icon(Icons.groups_2_outlined),
                    ),
                    keyboardType: TextInputType.number,
                    validator: (v) => (v == null || int.tryParse(v.trim()) == null) ? '기수를 숫자로 입력해 주세요.' : null,
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _submit,
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : const Text('가입 완료'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () => context.read<AuthProvider>().signOut(),
                    child: const Text('로그아웃'),
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
