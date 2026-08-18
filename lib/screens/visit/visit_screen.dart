import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../providers/auth_provider.dart';
import '../../services/firestore_service.dart';
import '../../models/visit_model.dart';
import '../../models/visit_slot_model.dart';
import '../../utils/constants.dart';
import '../../widgets/warning_banner.dart';

class VisitScreen extends StatelessWidget {
  const VisitScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final service = FirestoreService();
    final user = authProvider.currentUser!;

    // 심방 신청 내용은 신청자 본인과 목사님만 조회 가능 (관리자 포함 그 외 전원은 본인 신청 내역만 조회)
    if (user.isPastor) {
      return _AdminVisitView(service: service, canConfirm: true);
    }
    return _MemberVisitView(service: service, user: user, isCohortRestricted: authProvider.isCohortRestricted);
  }
}

// ── Member View ───────────────────────────────────────────────────────────────

class _MemberVisitView extends StatelessWidget {
  final FirestoreService service;
  final dynamic user;
  final bool isCohortRestricted;

  const _MemberVisitView({required this.service, required this.user, required this.isCohortRestricted});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder<List<VisitModel>>(
        stream: service.streamUserVisits(user.uid),
        builder: (ctx, snap) {
          final visits = snap.data ?? [];
          return CustomScrollView(
            slivers: [
              if (isCohortRestricted)
                const SliverPadding(
                  padding: EdgeInsets.fromLTRB(16, 16, 16, 0),
                  sliver: SliverToBoxAdapter(
                    child: WarningBanner('허용된 기수 범위가 아니라 심방 신청 없이 조회만 가능합니다.'),
                  ),
                ),
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
      floatingActionButton: isCohortRestricted
          ? null
          : FloatingActionButton.extended(
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
  late final TextEditingController _deptCtrl;
  late final TextEditingController _teamCtrl;
  late final TextEditingController _nameCtrl;
  final _reasonCtrl = TextEditingController();
  DateTime? _preferredDate;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _deptCtrl = TextEditingController(text: '청년부');
    final String dept = widget.user.department;
    final String teamText = AppTeams.smallTeams.contains(dept)
        ? dept
        : dept == AppTeams.executiveTeam
            ? AppTeams.executiveTeam
            : '새가족';
    _teamCtrl = TextEditingController(text: teamText);
    _nameCtrl = TextEditingController(text: widget.user.name);
  }

  @override
  void dispose() {
    _deptCtrl.dispose();
    _teamCtrl.dispose();
    _nameCtrl.dispose();
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
      userName: _nameCtrl.text.trim(),
      phone: widget.user.phone,
      deptName: _deptCtrl.text.trim(),
      team: _teamCtrl.text.trim(),
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
              controller: _nameCtrl,
              decoration: const InputDecoration(
                labelText: '이름 *',
                prefixIcon: Icon(Icons.person_outline),
              ),
              validator: (v) => (v == null || v.isEmpty) ? '이름을 입력해 주세요.' : null,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _deptCtrl,
                    decoration: const InputDecoration(
                      labelText: '부서 *',
                      prefixIcon: Icon(Icons.groups_outlined),
                    ),
                    validator: (v) => (v == null || v.isEmpty) ? '부서를 입력해 주세요.' : null,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    controller: _teamCtrl,
                    decoration: const InputDecoration(
                      labelText: '팀 *',
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                    validator: (v) => (v == null || v.isEmpty) ? '팀을 입력해 주세요.' : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            StreamBuilder<List<VisitSlotModel>>(
              stream: widget.service.streamVisitSlots(),
              builder: (ctx, snap) {
                final now = DateTime.now();
                final slots = (snap.data ?? []).where((s) => s.dateTime.isAfter(now)).toList();
                // 목록이 바뀌어 더는 유효하지 않은 선택값이면 초기화
                if (_preferredDate != null && !slots.any((s) => s.dateTime == _preferredDate)) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) setState(() => _preferredDate = null);
                  });
                }
                return DropdownButtonFormField<DateTime>(
                  initialValue: _preferredDate,
                  decoration: const InputDecoration(
                    labelText: '선호 시간 선택 (선택사항)',
                    prefixIcon: Icon(Icons.calendar_today),
                  ),
                  hint: Text(slots.isEmpty ? '열려 있는 시간대가 없습니다' : '선호 시간 선택'),
                  items: slots
                      .map((s) => DropdownMenuItem(
                            value: s.dateTime,
                            child: Text(DateFormat('MM/dd (E) HH:mm', 'ko').format(s.dateTime)),
                          ))
                      .toList(),
                  onChanged: slots.isEmpty ? null : (v) => setState(() => _preferredDate = v),
                );
              },
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
                const Icon(Icons.person_outline, size: 16, color: AppColors.textSecondary),
                const SizedBox(width: 4),
                Expanded(child: Text('${visit.userName} · ${visit.deptName} · ${visit.team}')),
              ],
            ),
            if (visit.preferredDate != null) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.calendar_today, size: 16, color: AppColors.textSecondary),
                  const SizedBox(width: 4),
                  Text('선호 시간: ${DateFormat('yyyy년 MM월 dd일 HH:mm', 'ko').format(visit.preferredDate!)}'),
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
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => showDialog(
          context: context,
          builder: (_) => _VisitDetailDialog(visit: visit, service: service, canConfirm: canConfirm),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Row(
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
                  ],
                ),
              ),
              Text(DateFormat('MM/dd', 'ko').format(visit.requestDate),
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right, color: AppColors.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}

class _VisitDetailDialog extends StatelessWidget {
  final VisitModel visit;
  final FirestoreService service;
  final bool canConfirm;

  const _VisitDetailDialog({required this.visit, required this.service, this.canConfirm = false});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Expanded(child: Text(visit.userName)),
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
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _DetailRow(icon: Icons.phone_outlined, text: visit.phone),
              const SizedBox(height: 8),
              _DetailRow(icon: Icons.groups_outlined, text: '${visit.deptName} · ${visit.team}'),
              const SizedBox(height: 8),
              _DetailRow(
                icon: Icons.calendar_today,
                text: '신청일: ${DateFormat('yyyy년 MM월 dd일', 'ko').format(visit.requestDate)}',
              ),
              if (visit.preferredDate != null) ...[
                const SizedBox(height: 8),
                _DetailRow(
                  icon: Icons.schedule,
                  text: '선호 시간: ${DateFormat('yyyy년 MM월 dd일 HH:mm', 'ko').format(visit.preferredDate!)}',
                ),
              ],
              if (visit.reason != null && visit.reason!.isNotEmpty) ...[
                const SizedBox(height: 8),
                _DetailRow(icon: Icons.notes, text: visit.reason!),
              ],
              if (visit.adminNote != null && visit.adminNote!.isNotEmpty) ...[
                const Divider(height: 24),
                const Text('관리자 메모', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.textSecondary)),
                const SizedBox(height: 4),
                Text(visit.adminNote!),
              ],
              if (canConfirm) ...[
                const Divider(height: 24),
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
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('닫기')),
      ],
    );
  }

  Future<void> _updateStatus(BuildContext context, String status) async {
    await service.updateVisitStatus(visit.id, status, previousStatus: visit.status, visitUserId: visit.userId);
    if (context.mounted) Navigator.pop(context);
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _DetailRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: AppColors.textSecondary),
        const SizedBox(width: 8),
        Expanded(child: Text(text)),
      ],
    );
  }
}
