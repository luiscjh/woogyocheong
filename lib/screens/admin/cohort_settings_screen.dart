import 'package:flutter/material.dart';
import '../../services/firestore_service.dart';
import '../../models/app_settings_model.dart';
import '../../utils/constants.dart';

// 관리자 전용: 기수 기반 이용 제한 기준(허용 기수 범위)을 설정하는 화면.
// 허용 범위를 벗어난 기수의 회원은 로그인은 되지만 조회만 가능해짐(목사님 제외)
class CohortSettingsScreen extends StatefulWidget {
  const CohortSettingsScreen({super.key});

  @override
  State<CohortSettingsScreen> createState() => _CohortSettingsScreenState();
}

class _CohortSettingsScreenState extends State<CohortSettingsScreen> {
  final _service = FirestoreService();
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _minCtrl;
  late final TextEditingController _maxCtrl;
  bool _isLoading = false;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _minCtrl = TextEditingController();
    _maxCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _minCtrl.dispose();
    _maxCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final min = int.parse(_minCtrl.text.trim());
    final max = int.parse(_maxCtrl.text.trim());
    if (min > max) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('최소 기수는 최대 기수보다 클 수 없습니다.'), backgroundColor: AppColors.warning),
      );
      return;
    }
    setState(() => _isLoading = true);
    try {
      final settings = AppSettingsModel(minAllowedCohort: min, maxAllowedCohort: max);
      await _service.updateAppSettings(settings);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('기수 제한 설정이 저장되었습니다.'), backgroundColor: AppColors.success),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('기수 제한 설정')),
      body: StreamBuilder<AppSettingsModel>(
        stream: _service.streamAppSettings(),
        builder: (ctx, snap) {
          if (snap.connectionState == ConnectionState.waiting && !_initialized) {
            return const Center(child: CircularProgressIndicator());
          }
          final settings = snap.data;
          if (settings != null && !_initialized) {
            _minCtrl.text = settings.minAllowedCohort.toString();
            _maxCtrl.text = settings.maxAllowedCohort.toString();
            _initialized = true;
          }
          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '허용 기수 범위를 벗어난 회원은 앱에 로그인은 되지만, 출석 체크·회비 납부·'
                    '심방 신청 등 쓰기 동작이 막히고 조회만 가능합니다. 목사님 역할은 이 제한에서'
                    ' 제외됩니다.',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _minCtrl,
                          decoration: const InputDecoration(labelText: '최소 허용 기수 *', prefixIcon: Icon(Icons.arrow_downward)),
                          keyboardType: TextInputType.number,
                          validator: (v) => (v == null || int.tryParse(v.trim()) == null) ? '숫자를 입력해 주세요.' : null,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Text('~', style: TextStyle(fontSize: 18, color: AppColors.textSecondary)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _maxCtrl,
                          decoration: const InputDecoration(labelText: '최대 허용 기수 *', prefixIcon: Icon(Icons.arrow_upward)),
                          keyboardType: TextInputType.number,
                          validator: (v) => (v == null || int.tryParse(v.trim()) == null) ? '숫자를 입력해 주세요.' : null,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (settings != null)
                    Text(
                      '현재 허용 범위: ${settings.minAllowedCohort}기 ~ ${settings.maxAllowedCohort}기',
                      style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _save,
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : const Text('저장'),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
