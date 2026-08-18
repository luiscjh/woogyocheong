import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../providers/auth_provider.dart';
import '../../services/firestore_service.dart';
import '../../models/ministry_meeting_model.dart';
import '../../utils/constants.dart';
import '../../widgets/confirm_dialog.dart';

// 사역팀(콘텐츠팀 등) 팀장 전용: 회의 일정을 일자/주제/논의 내용/정리 내용을
// 한 화면(폼)에서 함께 관리. 팀원 출석 대신 회의 기록으로 팀 운영을 트래킹.
// 팀장이 아닌 일반 팀원은 조회만 가능하고 추가/수정/삭제는 불가
class MinistryMeetingScreen extends StatelessWidget {
  const MinistryMeetingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.currentUser!;
    final readOnly = !auth.isMinistryLead;
    final service = FirestoreService();

    return Scaffold(
      appBar: AppBar(title: Text(readOnly ? '회의 일정' : '회의 일정 관리')),
      body: StreamBuilder<List<MinistryMeetingModel>>(
        stream: service.streamMinistryMeetings(user.ministryTeam),
        builder: (ctx, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final meetings = snap.data ?? [];
          if (meetings.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.event_note_outlined, size: 64, color: Colors.grey),
                  const SizedBox(height: 12),
                  const Text('등록된 회의 일정이 없습니다.'),
                  if (!readOnly) ...[
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () => _showMeetingForm(context, service, user.ministryTeam),
                      icon: const Icon(Icons.add),
                      label: const Text('회의 일정 추가'),
                    ),
                  ],
                ],
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: meetings.length,
            itemBuilder: (ctx, i) => _MeetingCard(
              meeting: meetings[i],
              onTap: () => readOnly
                  ? _showMeetingDetail(context, meetings[i])
                  : _showMeetingForm(context, service, user.ministryTeam, meeting: meetings[i]),
            ),
          );
        },
      ),
      floatingActionButton: readOnly
          ? null
          : FloatingActionButton(
              onPressed: () => _showMeetingForm(context, service, user.ministryTeam),
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              child: const Icon(Icons.add),
            ),
    );
  }

  void _showMeetingForm(BuildContext context, FirestoreService service, String ministryTeam,
      {MinistryMeetingModel? meeting}) {
    showDialog(
      context: context,
      builder: (_) => _MeetingFormDialog(service: service, ministryTeam: ministryTeam, meeting: meeting),
    );
  }

  void _showMeetingDetail(BuildContext context, MinistryMeetingModel meeting) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(meeting.topic.isEmpty ? '(제목 없음)' : meeting.topic),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                DateFormat('yyyy년 MM월 dd일 (E)', 'ko').format(meeting.date),
                style: const TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 16),
              const Text('논의 내용', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(meeting.discussion.isEmpty ? '-' : meeting.discussion),
              const SizedBox(height: 16),
              const Text('회의 내용 정리', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(meeting.summary.isEmpty ? '-' : meeting.summary),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('닫기')),
        ],
      ),
    );
  }
}

class _MeetingCard extends StatelessWidget {
  final MinistryMeetingModel meeting;
  final VoidCallback onTap;

  const _MeetingCard({required this.meeting, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: AppColors.primary.withValues(alpha: 0.1),
          child: const Icon(Icons.event_note_outlined, color: AppColors.primary),
        ),
        title: Text(meeting.topic.isEmpty ? '(제목 없음)' : meeting.topic),
        subtitle: Text(DateFormat('yyyy년 MM월 dd일 (E)', 'ko').format(meeting.date)),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }
}

class _MeetingFormDialog extends StatefulWidget {
  final FirestoreService service;
  final String ministryTeam;
  final MinistryMeetingModel? meeting;

  const _MeetingFormDialog({required this.service, required this.ministryTeam, this.meeting});

  @override
  State<_MeetingFormDialog> createState() => _MeetingFormDialogState();
}

class _MeetingFormDialogState extends State<_MeetingFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late DateTime _date;
  late final TextEditingController _topicCtrl;
  late final TextEditingController _discussionCtrl;
  late final TextEditingController _summaryCtrl;
  bool _isLoading = false;

  bool get isEditing => widget.meeting != null;

  @override
  void initState() {
    super.initState();
    _date = widget.meeting?.date ?? DateTime.now();
    _topicCtrl = TextEditingController(text: widget.meeting?.topic);
    _discussionCtrl = TextEditingController(text: widget.meeting?.discussion);
    _summaryCtrl = TextEditingController(text: widget.meeting?.summary);
  }

  @override
  void dispose() {
    _topicCtrl.dispose();
    _discussionCtrl.dispose();
    _summaryCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      final meeting = MinistryMeetingModel(
        id: widget.meeting?.id ?? const Uuid().v4(),
        ministryTeam: widget.ministryTeam,
        date: _date,
        topic: _topicCtrl.text.trim(),
        discussion: _discussionCtrl.text.trim(),
        summary: _summaryCtrl.text.trim(),
      );
      if (isEditing) {
        await widget.service.updateMinistryMeeting(meeting);
      } else {
        await widget.service.addMinistryMeeting(meeting);
      }
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _delete() async {
    final confirm = await confirmDestructiveAction(
      context,
      title: '회의 일정 삭제',
      content: '이 회의 일정을 삭제하시겠습니까?',
    );
    if (!confirm) return;
    await widget.service.deleteMinistryMeeting(widget.meeting!.id);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(isEditing ? '회의 일정 수정' : '회의 일정 추가'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.calendar_today),
                title: Text(DateFormat('yyyy년 MM월 dd일 (E)', 'ko').format(_date)),
                subtitle: const Text('일자'),
                onTap: _pickDate,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _topicCtrl,
                decoration: const InputDecoration(labelText: '회의 주제 *'),
                validator: (v) => (v == null || v.trim().isEmpty) ? '회의 주제를 입력해 주세요.' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _discussionCtrl,
                decoration: const InputDecoration(labelText: '논의 내용', alignLabelWithHint: true),
                maxLines: 4,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _summaryCtrl,
                decoration: const InputDecoration(labelText: '회의 내용 정리', alignLabelWithHint: true),
                maxLines: 4,
              ),
            ],
          ),
        ),
      ),
      actions: [
        if (isEditing)
          TextButton(
            onPressed: _isLoading ? null : _delete,
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('삭제'),
          ),
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소')),
        ElevatedButton(
          onPressed: _isLoading ? null : _save,
          child: _isLoading
              ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : Text(isEditing ? '저장' : '추가'),
        ),
      ],
    );
  }
}
