import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/firestore_service.dart';
import '../../models/visit_slot_model.dart';
import '../../utils/constants.dart';

class VisitSlotManagementScreen extends StatefulWidget {
  const VisitSlotManagementScreen({super.key});

  @override
  State<VisitSlotManagementScreen> createState() => _VisitSlotManagementScreenState();
}

class _VisitSlotManagementScreenState extends State<VisitSlotManagementScreen> {
  final _service = FirestoreService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('심방 시간 관리')),
      body: StreamBuilder<List<VisitSlotModel>>(
        stream: _service.streamVisitSlots(),
        builder: (ctx, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final now = DateTime.now();
          final slots = (snap.data ?? []).where((s) => s.dateTime.isAfter(now)).toList();
          if (slots.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.schedule_outlined, size: 64, color: Colors.grey),
                  const SizedBox(height: 12),
                  const Text('열려 있는 심방 가능 시간이 없습니다.'),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () => _showBatchDialog(context),
                    icon: const Icon(Icons.add),
                    label: const Text('시간대 등록'),
                  ),
                ],
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: slots.length,
            itemBuilder: (ctx, i) {
              final slot = slots[i];
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: const Icon(Icons.event_available, color: AppColors.primary),
                  title: Text(DateFormat('yyyy년 MM월 dd일 (E) HH:mm', 'ko').format(slot.dateTime)),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline, color: AppColors.error),
                    onPressed: () => _service.deleteVisitSlot(slot.id),
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showBatchDialog(context),
        icon: const Icon(Icons.add),
        label: const Text('시간대 일괄 등록'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
    );
  }

  void _showBatchDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => _SlotBatchDialog(service: _service),
    );
  }
}

class _SlotBatchDialog extends StatefulWidget {
  final FirestoreService service;

  const _SlotBatchDialog({required this.service});

  @override
  State<_SlotBatchDialog> createState() => _SlotBatchDialogState();
}

class _SlotBatchDialogState extends State<_SlotBatchDialog> {
  DateTime _date = _nextSunday();
  final List<TimeOfDay> _times = [];
  bool _isLoading = false;

  static DateTime _nextSunday() {
    final now = DateTime.now();
    final daysUntilSunday = (DateTime.sunday - now.weekday) % 7;
    final base = now.add(Duration(days: daysUntilSunday == 0 ? 7 : daysUntilSunday));
    return DateTime(base.year, base.month, base.day);
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _addTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 14, minute: 0),
    );
    if (picked != null && !_times.any((t) => t.hour == picked.hour && t.minute == picked.minute)) {
      setState(() {
        _times.add(picked);
        _times.sort((a, b) => (a.hour * 60 + a.minute).compareTo(b.hour * 60 + b.minute));
      });
    }
  }

  Future<void> _submit() async {
    if (_times.isEmpty) return;
    setState(() => _isLoading = true);
    final dateTimes = _times
        .map((t) => DateTime(_date.year, _date.month, _date.day, t.hour, t.minute))
        .toList();
    await widget.service.addVisitSlots(dateTimes);
    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${dateTimes.length}개의 시간대를 등록했습니다.'), backgroundColor: AppColors.success),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('심방 시간대 일괄 등록'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.calendar_today),
              title: Text(DateFormat('yyyy년 MM월 dd일 (E)', 'ko').format(_date)),
              onTap: _pickDate,
            ),
            const Divider(),
            Row(
              children: [
                const Text('시간 목록', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const Spacer(),
                TextButton.icon(
                  onPressed: _addTime,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('시간 추가'),
                ),
              ],
            ),
            if (_times.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text('등록할 시간을 추가해 주세요.', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: _times
                    .map((t) => Chip(
                          label: Text(t.format(context)),
                          onDeleted: () => setState(() => _times.remove(t)),
                        ))
                    .toList(),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소')),
        ElevatedButton(
          onPressed: _isLoading || _times.isEmpty ? null : _submit,
          child: _isLoading
              ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : Text('${_times.length}개 등록'),
        ),
      ],
    );
  }
}
