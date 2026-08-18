import 'package:flutter/material.dart';
import '../utils/constants.dart';

// 삭제 등 되돌릴 수 없는 작업 전에 사용하는 공용 확인 다이얼로그
Future<bool> confirmDestructiveAction(
  BuildContext context, {
  required String title,
  required String content,
  String confirmLabel = '삭제',
}) async {
  final confirm = await showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      title: Text(title),
      content: Text(content),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('취소')),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, true),
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return confirm ?? false;
}
