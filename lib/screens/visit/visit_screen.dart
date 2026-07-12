import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../providers/auth_provider.dart';
import '../../services/firestore_service.dart';
import '../../models/visit_model.dart';
import '../../utils/constants.dart';

class VisitScreen extends StatelessWidget {
  const VisitScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final service = FirestoreService();

    if (authProvider.isAdmin) {
      return _AdminVisitView(service: service, canConfirm: true);
    } else if (authProvider.isExecutive) {
      return _AdminVisitView(service: service, canConfirm: authProvider.canConfirmVisit);
    }
    return _MemberVisitView(service: service, user: authProvider.currentUser!);
  }
}

// ── Member View ───────────────────────────────────────────────────────────────

class _MemberVisitView extends StatelessWidget {
  final FirestoreService service;
  final dynamic user;

  const _MemberVisitView({required this.service, required this.user});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder<List<VisitModel>>(
        stream: service.streamUserVisits(user.uid),
        builder: (ctx, snap) {
          final visits = snap.data ?? [];
          return CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.all(16),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    if (visits.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 48),
                        child: Center(
                          child: Column(
                            children: [
                              Icon(Icons.favorite_border, size: 64, color: Colors.grey),
                              SizedBox(height: 12),
                              Text('신청한 심방이 없습니다.', style: TextStyle(color: AppColors.textSecondary)),
                            ],
                          ),
                        ),
                      )
                    else
                      ...visits.map((v) => _VisitCard(visit: v)),
                  ]),
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showRequestDialog(context),
        icon: const Icon(Icons.add),
        label: const Text('심방 신청'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
    );
  }

  void _showRequestDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _VisitRequestForm(service: service, user: user),
    );
  }
}

class _VisitRequestForm extends StatefulWidget {
  final FirestoreService service;
  final dynamic user;

  const _VisitRequestForm({required this.service, required this.user});

  @override
  State<_VisitRequestForm> createState() => _VisitRequestFormState();
}

class _VisitRequestFormState extends State<_VisitRequestForm> {
  final _formKey = GlobalKey<FormState>();
  final _addressCtrl = TextEditingController();
  final _reasonCtrl = TextEditingController();
  DateTime? _preferredDate;
  bool _isLoading = false;

  @override
  void dispose() {
    _addressCtrl.dispose();
    _reasonCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    final id = const Uuid().v4();
    final visit = VisitModel(
      id: id,
      userId: widget.user.uid,
      userName: widget.user.name,
      phone: widget.user.phone,
      address: _addressCtrl.text.trim(),
      requestDate: DateTime.now(),
      preferredDate: _preferredDate,
      status: 'pending',
      reason: _reasonCtrl.text.trim().isEmpty ? null : _reasonCtrl.text.trim(),
    );
    await widget.service.requestVisit(visit);
    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('심방 신청이 완료되었습니다.'),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('심방 신청', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const Spacer(),
                IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
              ],
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _addressCtrl,
              decoration: const InputDecoration(
                labelText: '주소 *',
                prefixIcon: Icon(Icons.home_outlined),
              ),
              validator: (v) => (v == null || v.isEmpty) ? '주소를 입력해 주세요.' : null,
            ),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.calendar_today),
              title: Text(
                _preferredDate == null
                    ? '선호 날짜 선택 (선택사항)'
                    : DateFormat('yyyy년 MM월 dd일', 'ko').format(_preferredDate!),
              ),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: DateTime.now().add(const Duration(days: 7)),
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(const Duration(days: 90)),
                );
                if (picked != null) setState(() => _preferredDate = picked);
              },
              trailing: _preferredDate != null
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () => setState(() => _preferredDate = null),
                    )
                  : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _reasonCtrl,
              decoration: const InputDecoration(
                labelText: '신청 사유 (선택사항)',
                prefixIcon: Icon(Icons.notes),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 24),
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
                    : const Text('신청하기'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VisitCard extends StatelessWidget {
  final VisitModel visit;

  const _VisitCard({required this.visit});

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
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: VisitStatus.color(visit.status).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    VisitStatus.label(visit.status),
                    style: TextStyle(
                      color: VisitStatus.color(visit.status),
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  DateFormat('MM/dd', 'ko').format(visit.requestDate),
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.home_outlined, size: 16, color: AppColors.textSecondary),
                const SizedBox(width: 4),
                Expanded(child: Text(visit.address)),
              ],
            ),
            if (visit.preferredDate != null) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.calendar_today, size: 16, color: AppColors.textSecondary),
                  const SizedBox(width: 4),
                  Text('선호일: ${DateFormat('yyyy년 MM월 dd일', 'ko').format(visit.preferredDate!)}'),
                ],
              ),
            ],
            if (visit.reason != null && visit.reason!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(visit.reason!, style: const TextStyle(color: AppColors.textSecondary)),
            ],
            if (visit.adminNote != null && visit.adminNote!.isNotEmpty) ...[
              const Divider(height: 16),
              Text('관리자 메모: ${visit.adminNote!}',
                  style: const TextStyle(color: AppColors.primary, fontSize: 12)),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Admin View ────────────────────────────────────────────────────────────────

class _AdminVisitView extends StatelessWidget {
  final FirestoreService service;
  final bool canConfirm;

  const _AdminVisitView({required this.service, this.canConfirm = false});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<VisitModel>>(
      stream: service.streamAllVisits(),
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final visits = snap.data ?? [];
        final pending = visits.where((v) => v.status == 'pending').length;

        return Column(
          children: [
            if (pending > 0)
              Container(
                padding: const EdgeInsets.all(12),
                color: AppColors.warning.withValues(alpha: 0.1),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, color: AppColors.warning),
                    const SizedBox(width: 8),
                    Text('대기 중인 신청 $pending건',
                        style: const TextStyle(color: AppColors.warning, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            Expanded(
              child: visits.isEmpty
                  ? const Center(child: Text('신청된 심방이 없습니다.'))
                  : ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: visits.length,
                      itemBuilder: (ctx, i) => _AdminVisitCard(visit: visits[i], service: service, canConfirm: canConfirm),
                    ),
            ),
          ],
        );
      },
    );
  }
}

class _AdminVisitCard extends StatelessWidget {
  final VisitModel visit;
  final FirestoreService service;
  final bool canConfirm;

  const _AdminVisitCard({required this.visit, required this.service, this.canConfirm = false});

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
                Text(visit.userName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: VisitStatus.color(visit.status).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    VisitStatus.label(visit.status),
                    style: TextStyle(color: VisitStatus.color(visit.status), fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
                const Spacer(),
                Text(DateFormat('MM/dd', 'ko').format(visit.requestDate),
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
              ],
            ),
            const SizedBox(height: 8),
            Text(visit.phone, style: const TextStyle(color: AppColors.textSecondary)),
            Text(visit.address),
            if (visit.preferredDate != null)
              Text('선호일: ${DateFormat('yyyy/MM/dd', 'ko').format(visit.preferredDate!)}'),
            if (visit.reason != null) Text(visit.reason!),
            if (canConfirm) ...[
              const Divider(height: 16),
              Row(
                children: [
                  for (final status in ['confirmed', 'completed', 'cancelled'])
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: TextButton(
                        onPressed: visit.status == status
                            ? null
                            : () => _updateStatus(context, status),
                        style: TextButton.styleFrom(
                          foregroundColor: VisitStatus.color(status),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        ),
                        child: Text(VisitStatus.label(status), style: const TextStyle(fontSize: 12)),
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _updateStatus(BuildContext context, String status) async {
    await service.updateVisitStatus(visit.id, status);
  }
}
