import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/firestore_service.dart';
import '../../models/notification_model.dart';
import '../../utils/constants.dart';

class NotificationScreen extends StatelessWidget {
  const NotificationScreen({super.key});

  static IconData _iconFor(String type) {
    switch (type) {
      case 'visit':
        return Icons.favorite_border;
      case 'pastorRequest':
        return Icons.church_outlined;
      case 'newFamilyRotation':
        return Icons.event_repeat_outlined;
      case 'teamAssignment':
        return Icons.people_outline;
      default:
        return Icons.notifications_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.read<AuthProvider>().currentUser!;
    final service = FirestoreService();

    return Scaffold(
      appBar: AppBar(
        title: const Text('알림'),
        actions: [
          TextButton(
            onPressed: () => service.markAllNotificationsRead(user.uid),
            child: const Text('모두 읽음', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: StreamBuilder<List<NotificationModel>>(
        stream: service.streamUserNotifications(user.uid),
        builder: (ctx, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final notifications = snap.data ?? [];
          if (notifications.isEmpty) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.notifications_none, size: 64, color: Colors.grey),
                  SizedBox(height: 12),
                  Text('받은 알림이 없습니다.'),
                ],
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: notifications.length,
            itemBuilder: (ctx, i) {
              final n = notifications[i];
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                color: n.isRead ? null : AppColors.primary.withValues(alpha: 0.05),
                child: ListTile(
                  onTap: () {
                    if (!n.isRead) service.markNotificationRead(n.id);
                  },
                  leading: CircleAvatar(
                    backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                    child: Icon(_iconFor(n.type), color: AppColors.primary, size: 20),
                  ),
                  title: Text(n.title, style: TextStyle(fontWeight: n.isRead ? FontWeight.normal : FontWeight.bold)),
                  subtitle: Text(n.body),
                  trailing: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        DateFormat('MM/dd HH:mm').format(n.createdAt),
                        style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                      ),
                      if (!n.isRead) ...[
                        const SizedBox(height: 4),
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(color: AppColors.accent, shape: BoxShape.circle),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
