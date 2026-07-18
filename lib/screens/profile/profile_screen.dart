import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../providers/auth_provider.dart';
import '../../services/firestore_service.dart';
import '../../models/user_model.dart';
import '../../models/pastor_request_model.dart';
import '../../utils/constants.dart';

// 본인 역할을 스스로 양도할 수 있는 역할 (딱 해당 역할까지만 양도 가능)
const _transferableRoles = [UserRole.smallLeader, UserRole.midLeader, UserRole.executive, UserRole.pastor];

// 관리자~팀원 권한을 자유롭게 오가며 테스트할 수 있는 전용 계정
const _testAccountEmail = 'testing@church.com';

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
            if (user.email == _testAccountEmail) ...[
              const SizedBox(height: 20),
              _TestRoleSwitcherSection(user: user),
            ],
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
            if (user.role == UserRole.member) ...[
              const SizedBox(height: 20),
              _PastorRequestSection(user: user),
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
    // 목사님은 일반 회원이 아니라, 이미 목사님으로 등록된 사람에게만 양도 가능
    if (me.role == UserRole.pastor) {
      return all.where((m) => m.uid != me.uid && m.role == UserRole.pastor).toList();
    }
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
                  child: Text('양도할 수 있는 대상이 없습니다.'),
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

// 일반 회원이 관리자에게 목사 권한을 신청하는 섹션
class _PastorRequestSection extends StatelessWidget {
  final UserModel user;

  const _PastorRequestSection({required this.user});

  @override
  Widget build(BuildContext context) {
    final service = FirestoreService();
    return StreamBuilder<List<PastorRequestModel>>(
      stream: service.streamUserPastorRequests(user.uid),
      builder: (ctx, snap) {
        final requests = snap.data ?? [];
        final latest = requests.isNotEmpty ? requests.first : null;

        if (latest?.status == 'pending') {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.warning.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.hourglass_top, size: 18, color: AppColors.warning),
                SizedBox(width: 8),
                Text('목사 권한 신청 승인 대기중', style: TextStyle(color: AppColors.warning, fontWeight: FontWeight.w600)),
              ],
            ),
          );
        }

        return SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => _confirmRequest(context, service),
            icon: const Icon(Icons.church_outlined),
            label: const Text('목사 권한 신청'),
          ),
        );
      },
    );
  }

  Future<void> _confirmRequest(BuildContext context, FirestoreService service) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('목사 권한 신청'),
        content: const Text('관리자에게 목사 권한을 신청하시겠습니까?\n관리자가 승인하면 목사님 권한이 부여됩니다.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('취소')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('신청')),
        ],
      ),
    );
    if (confirm != true || !context.mounted) return;

    await service.requestPastorRole(PastorRequestModel(
      id: const Uuid().v4(),
      userId: user.uid,
      userName: user.name,
      email: user.email,
      requestDate: DateTime.now(),
      status: 'pending',
    ));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('목사 권한을 신청했습니다.'), backgroundColor: AppColors.success),
    );
  }
}

// 역할 + 소속(department)을 한 쌍으로 갖는 테스트 전환 옵션.
// 새가족/새가족팀 리더/팀장은 일반 소팀장·중팀장과 role은 같지만 department가
// 새가족팀이어야 실제 권한 스코프(회원관리/출석/회비/새가족 관리 화면)가
// 의도대로 동작하므로 role만으로는 구분할 수 없어 department를 함께 관리한다.
class _RoleOption {
  final String label;
  final String role;
  final String department;

  const _RoleOption(this.label, this.role, this.department);

  String get key => '$role|$department';
}

const _testRoleOptions = [
  _RoleOption('팀원', UserRole.member, 'A-1'),
  _RoleOption('소팀장', UserRole.smallLeader, 'A-1'),
  _RoleOption('중팀장', UserRole.midLeader, 'A-0'),
  _RoleOption('임원팀', UserRole.executive, AppTeams.executiveTeam),
  _RoleOption('목사님', UserRole.pastor, 'A-1'),
  _RoleOption('관리자', UserRole.admin, 'A-1'),
  _RoleOption('새가족', UserRole.member, AppTeams.newFamilyTeam),
  _RoleOption('새가족팀 리더', UserRole.smallLeader, AppTeams.newFamilyTeam),
  _RoleOption('새가족팀 팀장', UserRole.midLeader, AppTeams.newFamilyTeam),
];

// 테스트 전용 계정(testing@church.com)이 관리자~팀원 및 새가족 관련 역할을 즉시 오갈 수 있는 섹션
class _TestRoleSwitcherSection extends StatelessWidget {
  final UserModel user;

  const _TestRoleSwitcherSection({required this.user});

  _RoleOption get _currentOption {
    return _testRoleOptions.firstWhere(
      (o) => o.role == user.role && o.department == user.department,
      orElse: () => _testRoleOptions.firstWhere(
        (o) => o.role == user.role,
        orElse: () => _testRoleOptions.first,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.science_outlined, size: 18, color: AppColors.primary),
              SizedBox(width: 6),
              Text('테스트 계정 - 역할 전환', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primary)),
            ],
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _currentOption.key,
            decoration: const InputDecoration(labelText: '현재 역할', isDense: true, border: OutlineInputBorder()),
            items: _testRoleOptions
                .map((o) => DropdownMenuItem(value: o.key, child: Text(o.label)))
                .toList(),
            onChanged: (v) => _switchRole(context, v),
          ),
        ],
      ),
    );
  }

  Future<void> _switchRole(BuildContext context, String? key) async {
    if (key == null) return;
    final option = _testRoleOptions.firstWhere((o) => o.key == key);
    if (option.role == user.role && option.department == user.department) return;

    final service = FirestoreService();
    final updated = user.copyWith(role: option.role, department: option.department);
    await service.updateUser(updated);
    if (!context.mounted) return;
    context.read<AuthProvider>().setCurrentUser(updated);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('역할을 ${option.label}(으)로 전환했습니다.'), backgroundColor: AppColors.success),
    );
  }
}
