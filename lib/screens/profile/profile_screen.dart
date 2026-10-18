import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../providers/auth_provider.dart';
import '../../services/firestore_service.dart';
import '../../models/user_model.dart';
import '../../utils/constants.dart';
import '../../widgets/warning_banner.dart';

// 본인 역할을 스스로 양도할 수 있는 역할 — 목사님만 가능
const _transferableRoles = [UserRole.pastor];

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
                  icon: Icons.cake_outlined,
                  label: '생년월일',
                  value: user.birthDate != null ? DateFormat('yyyy년 MM월 dd일', 'ko').format(user.birthDate!) : '-',
                ),
                _InfoItem(
                  icon: Icons.groups_2_outlined,
                  label: '기수',
                  value: user.cohort != null ? '${user.cohort}기' : '-',
                ),
                _InfoItem(
                  icon: Icons.calendar_today_outlined,
                  label: '가입일',
                  value: DateFormat('yyyy년 MM월 dd일', 'ko').format(user.joinDate),
                ),
              ],
            ),
            if (context.watch<AuthProvider>().isCohortRestricted) ...[
              const SizedBox(height: 16),
              const WarningBanner(
                '현재 허용된 기수 범위가 아니라 조회만 가능한 상태입니다. 궁금한 점은 관리자에게 문의해 주세요.',
                width: double.infinity,
                fontSize: 13,
              ),
            ],
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
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextButton(
                  onPressed: () => launchUrl(Uri.parse(AppLinks.privacyPolicy), mode: LaunchMode.externalApplication),
                  child: const Text('개인정보처리방침', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                ),
                const Text('|', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                TextButton(
                  onPressed: () => _confirmDeleteAccount(context, user),
                  child: const Text('회원 탈퇴', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // 역할 양도는 목사님만 가능 — 소속팀 제한 없이 전체 팀원 중 아무에게나 양도
  List<UserModel> _candidatesFor(UserModel me, List<UserModel> all) {
    if (!me.isPastor) return const [];
    return all.where((m) => m.uid != me.uid && m.role == UserRole.member).toList();
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

    try {
      await service.transferRole(me, target);
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('역할 양도에 실패했습니다. 네트워크 상태를 확인하고 다시 시도해 주세요.'), backgroundColor: AppColors.error),
      );
      return;
    }
    if (!context.mounted) return;

    context.read<AuthProvider>().setCurrentUser(me.copyWith(role: UserRole.member, permissions: const []));
    Navigator.pop(context); // 후보 목록 다이얼로그 닫기
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${target.name}님에게 $roleLabel 역할을 양도했습니다.'), backgroundColor: AppColors.success),
    );
  }

  Future<void> _confirmDeleteAccount(BuildContext context, UserModel me) async {
    // 목사님 역할은 앱에 한 명만 있어야 하므로, 탈퇴 전에 먼저 양도하도록 안내
    if (me.isPastor) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('목사님 역할은 탈퇴 전에 먼저 다른 분께 양도해 주세요.')),
      );
      return;
    }
    // QA용 테스트 계정은 규칙상 본인 역할을 바꿀 수 있는 예외 계정이라, 탈퇴로 이 이메일이
    // 비면 다른 사람이 같은 이메일로 가입해 그 예외를 가져갈 수 있음 — 탈퇴를 막아 계정을 선점해 둠
    if (me.email == _testAccountEmail) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('테스트 계정은 탈퇴할 수 없습니다.')),
      );
      return;
    }
    final auth = context.read<AuthProvider>();
    final needsPassword = auth.needsPasswordForDeletion;
    final passwordCtrl = TextEditingController();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('회원 탈퇴'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '탈퇴하면 로그인 계정과 회원 정보(이름, 연락처, 생년월일, 소속 등)가 즉시 삭제되며 되돌릴 수 없습니다.\n\n'
              '출석·회비·심방·권한 신청 기록과 알림은 청년부 운영 기록으로 남으며, 여기에는 이름(심방 기록은 연락처 포함)이 함께 저장돼 있습니다. '
              '이 기록의 삭제를 원하시면 개인정보처리방침의 연락처로 요청해 주세요.',
            ),
            if (needsPassword) ...[
              const SizedBox(height: 16),
              TextField(
                controller: passwordCtrl,
                obscureText: true,
                decoration: const InputDecoration(labelText: '비밀번호 확인'),
              ),
            ] else ...[
              const SizedBox(height: 12),
              const Text('본인 확인을 위해 Google 로그인을 한 번 더 진행합니다.',
                  style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
            ],
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('취소')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('탈퇴'),
          ),
        ],
      ),
    );
    final password = passwordCtrl.text;
    // 다이얼로그 닫힘 애니메이션이 끝난 뒤 정리
    WidgetsBinding.instance.addPostFrameCallback((_) => passwordCtrl.dispose());
    if (confirm != true || !context.mounted) return;

    final nav = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    // 처리 중 중복 탭 방지용 진행 표시
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const PopScope(canPop: false, child: Center(child: CircularProgressIndicator())),
    );
    final error = await auth.deleteAccount(password: needsPassword ? password : null);
    nav.pop(); // 진행 표시 닫기
    // N1: 탈퇴가 중간에 실패해 로그아웃된 경우에도 빈 내 정보 화면이 남지 않게 첫 화면으로 돌아감
    if (error != null && error.isNotEmpty && auth.currentUser == null) {
      nav.popUntil((r) => r.isFirst);
      messenger.showSnackBar(SnackBar(content: Text(error), backgroundColor: AppColors.error));
      return;
    }
    if (error == null) {
      nav.popUntil((r) => r.isFirst);
      messenger.showSnackBar(const SnackBar(content: Text('탈퇴가 완료되었습니다.')));
    } else if (error.isNotEmpty) {
      messenger.showSnackBar(SnackBar(content: Text(error), backgroundColor: AppColors.error));
    }
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

// 역할 + 소속(department)을 한 쌍으로 갖는 테스트 전환 옵션.
// 새가족/새가족팀 리더/팀장은 일반 소팀장·중팀장과 role은 같지만 department가
// 새가족팀이어야 실제 권한 스코프(회원관리/출석/회비/새가족 관리 화면)가
// 의도대로 동작하므로 role만으로는 구분할 수 없어 department를 함께 관리한다.
class _RoleOption {
  final String label;
  final String role;
  final String department;
  // 사역팀(콘텐츠팀 등) 소속 여부 — department와 독립된 별도 축이므로 함께 관리
  final String ministryTeam;
  final bool isMinistryLead;
  // role=executive일 때만 의미 있음(회장/부회장/총무/회계)
  final String executiveTitle;

  const _RoleOption(this.label, this.role, this.department,
      {this.ministryTeam = '', this.isMinistryLead = false, this.executiveTitle = ''});

  String get key => '$role|$department|$ministryTeam|$isMinistryLead|$executiveTitle';

  bool matches(UserModel u) =>
      role == u.role &&
      department == u.department &&
      ministryTeam == u.ministryTeam &&
      isMinistryLead == u.isMinistryLead &&
      executiveTitle == u.executiveTitle;
}

const _testRoleOptions = [
  _RoleOption('팀원', UserRole.member, 'A-1'),
  _RoleOption('소팀장', UserRole.smallLeader, 'A-1'),
  _RoleOption('중팀장', UserRole.midLeader, 'A-0'),
  // 임원팀은 모두 직책 필수 — QA에서 단일석/다인석을 모두 확인할 수 있도록 4개 모두 제공
  _RoleOption('임원팀 회장', UserRole.executive, AppTeams.executiveTeam, executiveTitle: ExecutiveTitle.president),
  _RoleOption('임원팀 부회장', UserRole.executive, AppTeams.executiveTeam, executiveTitle: ExecutiveTitle.vicePresident),
  _RoleOption('임원팀 총무', UserRole.executive, AppTeams.executiveTeam, executiveTitle: ExecutiveTitle.secretary),
  _RoleOption('임원팀 회계', UserRole.executive, AppTeams.executiveTeam, executiveTitle: ExecutiveTitle.treasurer),
  _RoleOption('목사님', UserRole.pastor, 'A-1'),
  _RoleOption('관리자', UserRole.admin, 'A-1'),
  _RoleOption('새가족', UserRole.member, AppTeams.newFamilyTeam),
  _RoleOption('새가족팀 리더', UserRole.smallLeader, AppTeams.newFamilyTeam),
  _RoleOption('새가족팀 팀장', UserRole.midLeader, AppTeams.newFamilyTeam),
  // 사역팀은 department와 독립된 축이라 role=팀원 + 실제 소속팀(A-1)을 유지한 채 ministryTeam만 부여
  _RoleOption('콘텐츠팀 팀장', UserRole.member, 'A-1', ministryTeam: AppTeams.contentTeam, isMinistryLead: true),
];

// 테스트 전용 계정(testing@church.com)이 관리자~팀원 및 새가족 관련 역할을 즉시 오갈 수 있는 섹션
class _TestRoleSwitcherSection extends StatelessWidget {
  final UserModel user;

  const _TestRoleSwitcherSection({required this.user});

  // 정확히 일치하는 옵션이 없으면 role+department, 그다음 role만 일치하는
  // 옵션으로 순서대로 완화하며 찾고, 그마저 없으면 첫 옵션을 기본값으로 사용
  _RoleOption get _currentOption {
    final matchers = <bool Function(_RoleOption)>[
      (o) => o.matches(user),
      (o) => o.role == user.role && o.department == user.department,
      (o) => o.role == user.role,
    ];
    for (final matches in matchers) {
      final found = _testRoleOptions.where(matches);
      if (found.isNotEmpty) return found.first;
    }
    return _testRoleOptions.first;
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
    if (option.matches(user)) return;

    final service = FirestoreService();
    // AuthProvider에 캐시된 user는 다른 화면(예: 회원 관리에서 관리자가 본인
    // 계정에 직접 부여한 배너 관리 권한 공유)에서 바뀐 최신 값을 반영하지
    // 못할 수 있으므로, 역할 전환 시 최신 레코드를 다시 조회해 그 값을 기반으로 덮어씀
    final latest = await service.getUser(user.uid) ?? user;
    final updated = latest.copyWith(
      role: option.role,
      department: option.department,
      ministryTeam: option.ministryTeam,
      isMinistryLead: option.isMinistryLead,
      executiveTitle: option.executiveTitle,
      // 콘텐츠팀 팀원 상태를 벗어나면 위임받았던 배너 관리 권한도 함께 초기화
      bannerAccessGranted:
          option.ministryTeam == AppTeams.contentTeam && !option.isMinistryLead ? latest.bannerAccessGranted : false,
    );
    await service.updateUser(updated, previousDepartment: latest.department, notify: false);
    if (!context.mounted) return;
    context.read<AuthProvider>().setCurrentUser(updated);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('역할을 ${option.label}(으)로 전환했습니다.'), backgroundColor: AppColors.success),
    );
  }
}
