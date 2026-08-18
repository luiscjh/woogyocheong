import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/firestore_service.dart';
import '../../models/fee_model.dart';
import '../../models/user_model.dart';
import '../../utils/constants.dart';
import 'fee_screen.dart' show FeePeriodSelector;

// 관리 탭 전용: 소팀장/중팀장 등에게 부여된 권한 범위 내에서 팀 회비 납부 현황을 관리
// (개인 납부 체크는 홈의 '회비' 탭에서 본인만 가능하고, 이 화면은 팀 전체 현황용)
class FeeManagementScreen extends StatefulWidget {
  const FeeManagementScreen({super.key});

  @override
  State<FeeManagementScreen> createState() => _FeeManagementScreenState();
}

class _FeeManagementScreenState extends State<FeeManagementScreen> {
  final _service = FirestoreService();
  int _year = DateTime.now().year;
  int _month = DateTime.now().month;

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final user = authProvider.currentUser!;

    return Scaffold(
      appBar: AppBar(title: const Text('회비 관리')),
      body: Column(
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
            child: authProvider.isExecutive
                ? _AdminFeeView(year: _year, month: _month, service: _service, canEdit: true)
                // 새가족팀장: 하위에 별도 소팀 리더가 없어 본인이 새가족팀 전체 회비를 직접 관리
                : user.department == AppTeams.newFamilyTeam && authProvider.isMidLeader
                    ? _AdminFeeView(year: _year, month: _month, service: _service, canEdit: true, smallTeamFilter: user.department)
                    : authProvider.isMidLeader
                        ? _AdminFeeView(year: _year, month: _month, service: _service, canEdit: false, midTeamFilter: user.midTeam)
                        : _AdminFeeView(year: _year, month: _month, service: _service, canEdit: true, smallTeamFilter: user.department),
          ),
        ],
      ),
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
            var members = (memberSnap.data ?? []).where((m) => !m.isPastor).toList();
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
