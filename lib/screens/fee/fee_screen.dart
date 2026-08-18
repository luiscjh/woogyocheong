import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/firestore_service.dart';
import '../../models/fee_model.dart';
import '../../utils/constants.dart';
import '../../widgets/warning_banner.dart';

// 홈 하단 탭의 '회비' 화면: 역할과 무관하게 본인의 납부 여부만 확인/체크할 수 있음.
// 팀 전체 회비 현황 관리는 관리 탭의 '회비 관리'(FeeManagementScreen)에서 별도로 제공됨.
class FeeScreen extends StatefulWidget {
  const FeeScreen({super.key});

  @override
  State<FeeScreen> createState() => _FeeScreenState();
}

class _FeeScreenState extends State<FeeScreen> {
  final _service = FirestoreService();
  int _year = DateTime.now().year;
  int _month = DateTime.now().month;

  // 본인 회비 납부(마킹)는 조회 중인 달이 이번 달이면서, 그 달의 3~4주차일 때만 가능
  // (조회는 언제든 가능. 소팀장/중팀장의 회비 관리 화면은 이 제약과 무관하게 항상 수정 가능)
  bool get _isPayableWeek {
    final now = DateTime.now();
    if (_year != now.year || _month != now.month) return false;
    final week = ((now.day - 1) / 7).floor() + 1;
    return week == 3 || week == 4;
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final user = authProvider.currentUser!;
    final restricted = authProvider.isCohortRestricted;

    return Column(
      children: [
        FeePeriodSelector(
          year: _year,
          month: _month,
          onChanged: (y, m) => setState(() {
            _year = y;
            _month = m;
          }),
        ),
        Expanded(
          child: _MemberFeeView(
            userId: user.uid,
            userName: user.name,
            year: _year,
            month: _month,
            service: _service,
            canEdit: _isPayableWeek && !restricted,
            isCohortRestricted: restricted,
          ),
        ),
      ],
    );
  }
}

class FeePeriodSelector extends StatelessWidget {
  final int year;
  final int month;
  final void Function(int year, int month) onChanged;

  const FeePeriodSelector({super.key, required this.year, required this.month, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.primary,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left, color: Colors.white),
            onPressed: () {
              final prev = month == 1 ? DateTime(year - 1, 12) : DateTime(year, month - 1);
              onChanged(prev.year, prev.month);
            },
          ),
          Text(
            '$year년 ${month.toString().padLeft(2, '0')}월',
            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right, color: Colors.white),
            onPressed: () {
              final now = DateTime.now();
              final next = month == 12 ? DateTime(year + 1, 1) : DateTime(year, month + 1);
              if (next.isAfter(DateTime(now.year, now.month))) return;
              onChanged(next.year, next.month);
            },
          ),
        ],
      ),
    );
  }
}

class _MemberFeeView extends StatelessWidget {
  final String userId;
  final String userName;
  final int year;
  final int month;
  final FirestoreService service;
  final bool canEdit;
  final bool isCohortRestricted;

  const _MemberFeeView({
    required this.userId,
    required this.userName,
    required this.year,
    required this.month,
    required this.service,
    required this.canEdit,
    required this.isCohortRestricted,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<FeeModel?>(
      future: service.getFee(userId, year, month),
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final isPaid = snap.data?.isPaid ?? false;
        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const SizedBox(height: 32),
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isPaid ? AppColors.success : Colors.grey[200],
                ),
                child: Icon(
                  isPaid ? Icons.check : Icons.payments_outlined,
                  size: 60,
                  color: isPaid ? Colors.white : Colors.grey,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                isPaid ? '납부 완료' : '미납',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: isPaid ? AppColors.success : AppColors.warning,
                ),
              ),
              const SizedBox(height: 8),
              Text('$year년 ${month.toString().padLeft(2, '0')}월 회비',
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 16)),
              if (snap.data?.paidDate != null) ...[
                const SizedBox(height: 8),
                Text(
                  '납부일: ${snap.data!.paidDate!.toString().substring(0, 10)}',
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
              ],
              const SizedBox(height: 40),
              if (canEdit)
                if (!isPaid)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _setPaid(context, true),
                      icon: const Icon(Icons.check),
                      label: const Text('납부 완료로 표시'),
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.success),
                    ),
                  )
                else
                  OutlinedButton.icon(
                    onPressed: () => _setPaid(context, false),
                    icon: const Icon(Icons.undo),
                    label: const Text('납부 취소'),
                    style: OutlinedButton.styleFrom(foregroundColor: AppColors.error),
                  )
              else
                WarningBanner(
                  isCohortRestricted
                      ? '허용된 기수 범위가 아니라 조회만 가능합니다.'
                      : '회비 납부는 매월 3~4주차에만 가능합니다.',
                ),
              const SizedBox(height: 40),
              _FeeHistory(userId: userId, service: service),
            ],
          ),
        );
      },
    );
  }

  Future<void> _setPaid(BuildContext context, bool isPaid) async {
    await service.setFee(
      userId: userId,
      userName: userName,
      year: year,
      month: month,
      isPaid: isPaid,
    );
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isPaid ? '납부 처리되었습니다.' : '납부가 취소되었습니다.'),
          backgroundColor: isPaid ? AppColors.success : AppColors.warning,
        ),
      );
    }
  }
}

class _FeeHistory extends StatelessWidget {
  final String userId;
  final FirestoreService service;

  const _FeeHistory({required this.userId, required this.service});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<FeeModel>>(
      stream: service.streamUserFees(userId),
      builder: (ctx, snap) {
        final records = snap.data ?? [];
        if (records.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('납부 기록', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ...records.take(12).map((r) => ListTile(
              leading: Icon(
                r.isPaid ? Icons.check_circle : Icons.cancel,
                color: r.isPaid ? AppColors.success : AppColors.error,
              ),
              title: Text(r.periodLabel),
              trailing: Text(r.isPaid ? '납부' : '미납'),
              dense: true,
            )),
          ],
        );
      },
    );
  }
}
