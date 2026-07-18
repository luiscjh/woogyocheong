import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../utils/constants.dart';
import 'member_management.dart';
import 'banner_management.dart';
import 'pastor_request_management.dart';
import 'new_family_management.dart';
import 'new_family_rotation_management.dart';
import 'small_leader_status_screen.dart';
import '../visit/visit_slot_management.dart';

class AdminDashboard extends StatelessWidget {
  const AdminDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.currentUser!;
    final roleLabel = UserRole.label(user.role);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('관리 메뉴', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(roleLabel, style: const TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _AdminMenuCard(
            icon: Icons.people_outline,
            title: '회원 관리',
            subtitle: user.department == AppTeams.newFamilyTeam
                ? (user.role == UserRole.smallLeader ? '내 담당 주차 새가족 확인' : '새가족팀 회원 관리')
                : auth.isExecutive
                    ? '전체 회원 관리'
                    : auth.isMidLeader
                        ? '${user.midTeam}중팀 회원 관리'
                        : '${user.department}팀 회원 관리',
            color: AppColors.primary,
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MemberManagementScreen())),
          ),
          if (auth.isMidLeader) ...[
            const SizedBox(height: 12),
            _AdminMenuCard(
              icon: Icons.badge_outlined,
              title: '소팀장 현황',
              subtitle: auth.isExecutive
                  ? '전체 소팀장 현황'
                  : user.department == AppTeams.newFamilyTeam
                      ? '새가족팀 리더 현황'
                      : '${user.midTeam}중팀 소팀장 현황',
              color: Colors.deepPurple,
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SmallLeaderStatusScreen())),
            ),
          ],
          if (auth.isExecutive || (user.department == AppTeams.newFamilyTeam && auth.isMidLeader)) ...[
            const SizedBox(height: 12),
            _AdminMenuCard(
              icon: Icons.diversity_3_outlined,
              title: '새가족 관리',
              subtitle: '소팀 미배정 · 장기 결석(1년 이상) 대상자 확인 및 소팀 배정',
              color: Colors.purple,
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NewFamilyManagementScreen())),
            ),
          ],
          if (auth.isAdmin || (user.department == AppTeams.newFamilyTeam && auth.isMidLeader)) ...[
            const SizedBox(height: 12),
            _AdminMenuCard(
              icon: Icons.event_repeat_outlined,
              title: '새가족 로테이션 관리',
              subtitle: '1~3주차별 새가족팀 리더 고정 배정 및 새가족 매칭',
              color: Colors.indigo,
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NewFamilyRotationManagementScreen())),
            ),
          ],
          if (auth.canManageBanners) ...[
            const SizedBox(height: 12),
            _AdminMenuCard(
              icon: Icons.image_outlined,
              title: '배너 관리',
              subtitle: '홈 화면 배너 이미지 업로드 및 관리',
              color: Colors.orange,
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BannerManagementScreen())),
            ),
            const SizedBox(height: 12),
            _AdminMenuCard(
              icon: Icons.schedule_outlined,
              title: '심방 시간 관리',
              subtitle: '심방 신청 시 선택 가능한 시간대 등록 및 관리',
              color: Colors.teal,
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const VisitSlotManagementScreen())),
            ),
          ],
          if (auth.isAdmin) ...[
            const SizedBox(height: 12),
            _AdminMenuCard(
              icon: Icons.church_outlined,
              title: '목사 권한 신청 관리',
              subtitle: '회원의 목사 권한 신청 승인/거절',
              color: Colors.brown,
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PastorRequestManagementScreen())),
            ),
          ],
        ],
      ),
    );
  }
}

class _AdminMenuCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _AdminMenuCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: color.withValues(alpha: 0.1), shape: BoxShape.circle),
          child: Icon(icon, color: color, size: 28),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
