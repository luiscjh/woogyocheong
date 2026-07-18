import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/firestore_service.dart';
import '../../models/pastor_request_model.dart';
import '../../models/user_model.dart';
import '../../utils/constants.dart';

class PastorRequestManagementScreen extends StatefulWidget {
  const PastorRequestManagementScreen({super.key});

  @override
  State<PastorRequestManagementScreen> createState() => _PastorRequestManagementScreenState();
}

class _PastorRequestManagementScreenState extends State<PastorRequestManagementScreen> {
  final _service = FirestoreService();
  late int _year;
  late int _month;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _year = now.year;
    _month = now.month;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('목사 권한 신청 관리')),
      body: StreamBuilder<List<UserModel>>(
        stream: _service.streamAllMembers(),
        builder: (ctx, memberSnap) {
          return StreamBuilder<List<PastorRequestModel>>(
            stream: _service.streamPastorRequests(),
            builder: (ctx, reqSnap) {
              if (reqSnap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final requests = reqSnap.data ?? [];
              final members = {for (final m in memberSnap.data ?? []) m.uid: m};

              final pending = requests.where((r) => r.status == 'pending').toList();
              final history = requests
                  .where((r) =>
                      r.status != 'pending' &&
                      r.requestDate.year == _year &&
                      r.requestDate.month == _month)
                  .toList();

              return ListView(
                padding: const EdgeInsets.all(12),
                children: [
                  if (pending.isNotEmpty) ...[
                    Text('대기중인 신청 ${pending.length}건',
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.warning)),
                    const SizedBox(height: 8),
                    ...pending.map((req) => _RequestCard(request: req, requester: members[req.userId], service: _service)),
                    const SizedBox(height: 20),
                    const Divider(),
                    const SizedBox(height: 8),
                  ],
                  const Text('월별 신청 이력', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  _MonthSelector(
                    year: _year,
                    month: _month,
                    onChanged: (y, m) => setState(() {
                      _year = y;
                      _month = m;
                    }),
                  ),
                  const SizedBox(height: 12),
                  if (history.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 32),
                      child: Center(child: Text('이 달의 신청 이력이 없습니다.', style: TextStyle(color: AppColors.textSecondary))),
                    )
                  else
                    ...history.map((req) => _RequestCard(request: req, requester: members[req.userId], service: _service)),
                  if (pending.isEmpty && history.isEmpty && requests.isEmpty) ...[
                    const SizedBox(height: 32),
                    const Center(
                      child: Column(
                        children: [
                          Icon(Icons.church_outlined, size: 64, color: Colors.grey),
                          SizedBox(height: 12),
                          Text('목사 권한 신청이 없습니다.'),
                        ],
                      ),
                    ),
                  ],
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _MonthSelector extends StatelessWidget {
  final int year;
  final int month;
  final void Function(int year, int month) onChanged;

  const _MonthSelector({required this.year, required this.month, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
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
            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
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

class _RequestCard extends StatelessWidget {
  final PastorRequestModel request;
  final UserModel? requester;
  final FirestoreService service;

  const _RequestCard({required this.request, required this.requester, required this.service});

  String _statusLabel(String status) {
    switch (status) {
      case 'approved':
        return '승인됨';
      case 'rejected':
        return '거절됨';
      default:
        return '대기중';
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'approved':
        return AppColors.success;
      case 'rejected':
        return AppColors.error;
      default:
        return AppColors.warning;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(request.userName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: _statusColor(request.status).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    _statusLabel(request.status),
                    style: TextStyle(color: _statusColor(request.status), fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
                const Spacer(),
                Text(DateFormat('yyyy/MM/dd', 'ko').format(request.requestDate),
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
              ],
            ),
            const SizedBox(height: 6),
            Text(request.email, style: const TextStyle(color: AppColors.textSecondary)),
            if (request.status == 'pending') ...[
              const Divider(height: 20),
              Row(
                children: [
                  ElevatedButton(
                    onPressed: requester == null ? null : () => _approve(context),
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.success),
                    child: const Text('승인'),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton(
                    onPressed: () => _reject(context),
                    style: OutlinedButton.styleFrom(foregroundColor: AppColors.error),
                    child: const Text('거절'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _approve(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('목사 권한 승인'),
        content: Text('${request.userName}님에게 목사 권한을 부여하시겠습니까?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('취소')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('승인')),
        ],
      ),
    );
    if (confirm != true || requester == null) return;
    await service.approvePastorRequest(request.id, requester!);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${request.userName}님에게 목사 권한을 부여했습니다.'), backgroundColor: AppColors.success),
    );
  }

  Future<void> _reject(BuildContext context) async {
    await service.rejectPastorRequest(request.id);
  }
}
