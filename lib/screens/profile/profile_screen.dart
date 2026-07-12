import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/auth_provider.dart';
import '../../services/firestore_service.dart';
import '../../models/user_model.dart';
import '../../utils/constants.dart';

// 본인 역할을 스스로 양도할 수 있는 역할 (딱 해당 역할까지만 양도 가능)
const _transferableRoles = [UserRole.smallLeader, UserRole.midLeader, UserRole.executive];

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser;
    if (user == null) return const SizedBox.shrink();

    return Scaffold(
      appBar: AppBar(title: const Text('내 정보')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            CircleAvatar(
              radius: 48,
              backgroundColor: AppColors.primary,
              backgroundImage: user.profileImageUrl != null
                  ? NetworkImage(user.profileImageUrl!)
                  : null,
              child: user.profileImageUrl == null
                  ? Text(
                      user.name.isNotEmpty ? user.name[0] : '?',
                      style: const TextStyle(fontSize: 36, color: Colors.white),
                    )
                  : null,
            ),
            const SizedBox(height: 16),
            Text(
              user.name,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            if (user.role != UserRole.member)
              Container(
                margin: const EdgeInsets.only(top: 6),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(UserRole.label(user.role), style: const TextStyle(color: AppColors.accent, fontWeight: FontWeight.w600)),
              ),
            const SizedBox(height: 32),
            _InfoCard(
              items: [
                _InfoItem(icon: Icons.email_outlined, label: '이메일', value: user.email),
                _InfoItem(icon: Icons.phone_outlined, label: '전화번호', value: user.phone.isEmpty ? '-' : user.phone),
                _InfoItem(icon: Icons.group_outlined, label: '부서/그룹', value: user.department.isEmpty ? '-' : user.department),
                _InfoItem(
                  icon: Icons.calendar_today_outlined,
                  label: '가입일',
                  value: DateFormat('yyyy년 MM월 dd일', 'ko').format(user.joinDate),
                ),
              ],
            ),
            if (_transferableRoles.contains(user.role)) ...[
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _showTransferDialog(context, user),
                  icon: const Icon(Icons.swap_horiz),
                  label: Text('${UserRole.label(user.role)} 역할 양도'),
                ),
              ),
            ],
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _confirmLogout(context),
                icon: const Icon(Icons.logout),
                label: const Text('로그아웃'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.error,
                  side: const BorderSide(color: AppColors.error),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<UserModel> _candidatesFor(UserModel me, List<UserModel> all) {
    final others = all.where((m) => m.uid != me.uid && m.role == UserRole.member);
    if (me.role == UserRole.smallLeader) {
      return others.where((m) => m.department == me.department).toList();
    } else if (me.role == UserRole.midLeader) {
      return others.where((m) => m.midTeam == me.midTeam).toList();
    } else if (me.role == UserRole.executive) {
      return others.toList();
    }
    return const [];
  }

  void _showTransferDialog(BuildContext context, UserModel me) {
    final service = FirestoreService();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('${UserRole.label(me.role)} 역할 양도'),
        content: SizedBox(
          width: double.maxFinite,
          child: StreamBuilder<List<UserModel>>(
            stream: service.streamAllMembers(),
            builder: (ctx, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const SizedBox(height: 80, child: Center(child: CircularProgressIndicator()));
              }
              final candidates = _candidatesFor(me, snap.data ?? []);
              if (candidates.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Text('양도할 수 있는 팀원이 없습니다.'),
                );
              }
              return SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: candidates
                      .map((c) => ListTile(
                            leading: CircleAvatar(child: Text(c.name.isNotEmpty ? c.name[0] : '?')),
                            title: Text(c.name),
                            subtitle: Text(c.email),
                            onTap: () => _confirmTransfer(context, service, me, c),
                          ))
                      .toList(),
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소')),
        ],
      ),
    );
  }

  Future<void> _confirmTransfer(BuildContext context, FirestoreService service, UserModel me, UserModel target) async {
    final roleLabel = UserRole.label(me.role);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('역할 양도 확인'),
        content: Text('${target.name}님에게 $roleLabel 역할을 양도하시겠습니까?\n양도 후 회원님은 팀원으로 전환됩니다.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('취소')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('양도')),
        ],
      ),
    );
    if (confirm != true || !context.mounted) return;

    await service.transferRole(me, target);
    if (!context.mounted) return;

    context.read<AuthProvider>().setCurrentUser(me.copyWith(role: UserRole.member, permissions: const []));
    Navigator.pop(context); // 후보 목록 다이얼로그 닫기
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${target.name}님에게 $roleLabel 역할을 양도했습니다.'), backgroundColor: AppColors.success),
    );
  }

  Future<void> _confirmLogout(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('로그아웃'),
        content: const Text('정말 로그아웃하시겠습니까?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('취소')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('로그아웃'),
          ),
        ],
      ),
    );
    if (confirm == true && context.mounted) {
      final nav = Navigator.of(context);
      await context.read<AuthProvider>().signOut();
      nav.popUntil((r) => r.isFirst);
    }
  }
}

class _InfoCard extends StatelessWidget {
  final List<_InfoItem> items;

  const _InfoCard({required this.items});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Column(
          children: items
              .map((item) => ListTile(
                    leading: Icon(item.icon, color: AppColors.primary),
                    title: Text(item.label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                    subtitle: Text(item.value, style: const TextStyle(fontSize: 16, color: AppColors.textPrimary)),
                  ))
              .toList(),
        ),
      ),
    );
  }
}

class _InfoItem {
  final IconData icon;
  final String label;
  final String value;

  const _InfoItem({required this.icon, required this.label, required this.value});
}
