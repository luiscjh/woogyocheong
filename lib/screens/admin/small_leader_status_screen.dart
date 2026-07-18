import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/firestore_service.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../utils/constants.dart';

class SmallLeaderStatusScreen extends StatelessWidget {
  const SmallLeaderStatusScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final currentUser = authProvider.currentUser!;
    final service = FirestoreService();

    return Scaffold(
      appBar: AppBar(title: const Text('소팀장 현황')),
      body: StreamBuilder<List<UserModel>>(
        stream: service.streamAllMembers(),
        builder: (ctx, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final all = snap.data ?? [];
          var leaders = all.where((m) => m.role == UserRole.smallLeader).toList();
          if (!authProvider.isExecutive) {
            leaders = leaders.where((m) => m.midTeam == currentUser.midTeam).toList();
          }

          if (leaders.isEmpty) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.badge_outlined, size: 64, color: Colors.grey),
                  SizedBox(height: 12),
                  Text('현재 소팀장 역할을 맡고 있는 회원이 없습니다.'),
                ],
              ),
            );
          }

          final memberCounts = <String, int>{};
          for (final m in all) {
            if (m.role == UserRole.member) {
              memberCounts[m.department] = (memberCounts[m.department] ?? 0) + 1;
            }
          }

          leaders.sort((a, b) => a.department.compareTo(b.department));
          final grouped = <String, List<UserModel>>{};
          for (final l in leaders) {
            grouped.putIfAbsent(l.midTeam, () => []).add(l);
          }
          final midKeys = grouped.keys.toList()..sort();

          return ListView(
            padding: const EdgeInsets.all(12),
            children: [
              for (final mid in midKeys) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                  child: Text(
                    AppTeams.midTeams.contains(mid) ? '$mid중팀' : mid,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.primary),
                  ),
                ),
                ...grouped[mid]!.map((leader) => Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: const CircleAvatar(
                          backgroundColor: AppColors.primary,
                          child: Icon(Icons.badge, color: Colors.white, size: 20),
                        ),
                        title: Text(leader.name),
                        subtitle: Text(
                            '${AppTeams.deptLabel(leader.department)} · 팀원 ${memberCounts[leader.department] ?? 0}명'),
                        trailing: Text(leader.phone,
                            style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                      ),
                    )),
              ],
            ],
          );
        },
      ),
    );
  }
}
