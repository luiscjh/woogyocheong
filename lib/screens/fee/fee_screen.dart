import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/firestore_service.dart';
import '../../models/fee_model.dart';
import '../../models/user_model.dart';
import '../../utils/constants.dart';

class FeeScreen extends StatefulWidget {
  const FeeScreen({super.key});

  @override
  State<FeeScreen> createState() => _FeeScreenState();
}

class _FeeScreenState extends State<FeeScreen> {
  final _service = FirestoreService();
  int _year = DateTime.now().year;
  int _month = DateTime.now().month;

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final user = authProvider.currentUser!;

    return Column(
      children: [
        _PeriodSelector(
          year: _year,
          month: _month,
          onChanged: (y, m) => setState(() {
            _year = y;
            _month = m;
          }),
        ),
        Expanded(
          child: authProvider.isExecutive
              ? _AdminFeeView(year: _year, month: _month, service: _service, canEdit: true)
              : authProvider.isMidLeader
                  ? _AdminFeeView(year: _year, month: _month, service: _service, canEdit: false, midTeamFilter: user.midTeam)
                  : authProvider.isSmallLeader
                      ? _AdminFeeView(year: _year, month: _month, service: _service, canEdit: true, smallTeamFilter: user.department)
                      : _MemberFeeView(userId: user.uid, userName: user.name, year: _year, month: _month, service: _service),
        ),
      ],
    );
  }
}

class _PeriodSelector extends StatelessWidget {
  final int year;
  final int month;
  final void Function(int year, int month) onChanged;

  const _PeriodSelector({required this.year, required this.month, required this.onChanged});

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

  const _MemberFeeView({
    required this.userId,
    required this.userName,
    required this.year,
    required this.month,
    required this.service,
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

class _AdminFeeView extends StatelessWidget {
  final int year;
  final int month;
  final FirestoreService service;
  final bool canEdit;
  final String? smallTeamFilter;
  final String? midTeamFilter;

  const _AdminFeeView({
    required this.year,
    required this.month,
    required this.service,
    this.canEdit = true,
    this.smallTeamFilter,
    this.midTeamFilter,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<UserModel>>(
      stream: service.streamAllMembers(),
      builder: (ctx, memberSnap) {
        return StreamBuilder<List<FeeModel>>(
          stream: service.streamFeesByPeriod(year, month),
          builder: (ctx, feeSnap) {
            if (memberSnap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            // 목사님은 회비 납부 대상에서 제외
            var members = (memberSnap.data ?? []).where((m) => m.role != UserRole.pastor).toList();
            if (smallTeamFilter != null) {
              members = members.where((m) => m.department == smallTeamFilter).toList();
            } else if (midTeamFilter != null) {
              members = members.where((m) => m.midTeam == midTeamFilter).toList();
            }
            final fees = {for (final f in feeSnap.data ?? []) f.userId: f};
            final paidCount = members.where((m) => fees[m.uid]?.isPaid == true).length;

            return Column(
              children: [
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  child: Row(
                    children: [
                      _Stat(label: '전체', value: members.length, color: AppColors.primary),
                      const SizedBox(width: 24),
                      _Stat(label: '납부', value: paidCount, color: AppColors.success),
                      const SizedBox(width: 24),
                      _Stat(label: '미납', value: members.length - paidCount, color: AppColors.error),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    itemCount: members.length,
                    itemBuilder: (ctx, i) {
                      final m = members[i];
                      final fee = fees[m.uid];
                      final isPaid = fee?.isPaid ?? false;
                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: isPaid ? AppColors.success : Colors.grey[300],
                            child: Text(
                              m.name.isNotEmpty ? m.name[0] : '?',
                              style: TextStyle(
                                color: isPaid ? Colors.white : AppColors.textSecondary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          title: Text(m.name),
                          subtitle: Text(m.department),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _FeeChip(isPaid: isPaid),
                              if (canEdit) ...[
                                const SizedBox(width: 8),
                                PopupMenuButton<bool>(
                                  onSelected: (v) => service.setFee(
                                    userId: m.uid,
                                    userName: m.name,
                                    year: year,
                                    month: month,
                                    isPaid: v,
                                  ),
                                  itemBuilder: (_) => [
                                    const PopupMenuItem(value: true, child: Text('납부')),
                                    const PopupMenuItem(value: false, child: Text('미납')),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final int value;
  final Color color;

  const _Stat({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text('$value', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
        Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
      ],
    );
  }
}

class _FeeChip extends StatelessWidget {
  final bool isPaid;

  const _FeeChip({required this.isPaid});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isPaid ? AppColors.success.withValues(alpha: 0.1) : AppColors.error.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        isPaid ? '납부' : '미납',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: isPaid ? AppColors.success : AppColors.error,
        ),
      ),
    );
  }
}
