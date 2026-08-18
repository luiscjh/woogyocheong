import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/firestore_service.dart';
import '../../models/banner_model.dart';
import '../../models/attendance_model.dart';
import '../../models/new_family_rotation_model.dart';
import '../../models/user_model.dart';
import '../../utils/constants.dart';
import '../../widgets/banner_slider.dart';
import '../attendance/attendance_screen.dart';
import '../fee/fee_screen.dart';
import '../visit/visit_screen.dart';
import '../admin/admin_dashboard.dart';
import '../profile/profile_screen.dart';
import '../notifications/notification_screen.dart';
import '../../models/notification_model.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  final _firestoreService = FirestoreService();

  void _navigateTo(int index) => setState(() => _selectedIndex = index);

  @override
  Widget build(BuildContext context) {
    // watch를 사용해야 역할 전환 등으로 권한이 바뀔 때 관리 탭 노출 여부가
    // 즉시 갱신됨 (read를 쓰면 이미 그려진 화면은 다음 setState 전까지 갱신되지 않음)
    final authProvider = context.watch<AuthProvider>();
    final canManage = authProvider.canAccessAdminTab;
    // 목사님은 소팀 소속 회원이 아니므로 개인 출석 체크/회비 납부 탭이 필요 없음
    final isPastor = authProvider.isPastor;

    final pages = [
      _HomeTab(firestoreService: _firestoreService, onNavigate: _navigateTo, isPastor: isPastor),
      if (!isPastor) const AttendanceScreen(),
      if (!isPastor) const FeeScreen(),
      const VisitScreen(),
      if (canManage) const AdminDashboard(),
    ];

    final destinations = [
      const NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: '홈'),
      if (!isPastor)
        const NavigationDestination(icon: Icon(Icons.check_circle_outline), selectedIcon: Icon(Icons.check_circle), label: '출석'),
      if (!isPastor)
        const NavigationDestination(icon: Icon(Icons.payments_outlined), selectedIcon: Icon(Icons.payments), label: '회비'),
      const NavigationDestination(icon: Icon(Icons.favorite_border), selectedIcon: Icon(Icons.favorite), label: '심방'),
      if (canManage)
        const NavigationDestination(icon: Icon(Icons.admin_panel_settings_outlined), selectedIcon: Icon(Icons.admin_panel_settings), label: '관리'),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.appName),
        actions: [
          StreamBuilder<List<NotificationModel>>(
            stream: _firestoreService.streamUserNotifications(authProvider.currentUser?.uid ?? ''),
            builder: (ctx, snap) {
              final unreadCount = (snap.data ?? []).where((n) => !n.isRead).length;
              return IconButton(
                icon: Badge(
                  isLabelVisible: unreadCount > 0,
                  label: Text('$unreadCount'),
                  child: const Icon(Icons.notifications_outlined),
                ),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const NotificationScreen()),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.person_outline),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ProfileScreen()),
            ),
          ),
        ],
      ),
      body: IndexedStack(index: _effectiveIndex(pages.length), children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _effectiveIndex(pages.length),
        onDestinationSelected: (i) => setState(() => _selectedIndex = i),
        destinations: destinations,
      ),
    );
  }

  // 관리 탭이 사라져 canManage가 false가 되는 등 탭 개수가 줄어든 경우,
  // 이전에 선택돼 있던 인덱스가 범위를 벗어나지 않도록 방어
  int _effectiveIndex(int tabCount) => _selectedIndex < tabCount ? _selectedIndex : 0;
}

class _HomeTab extends StatelessWidget {
  final FirestoreService firestoreService;
  final void Function(int) onNavigate;
  final bool isPastor;

  const _HomeTab({required this.firestoreService, required this.onNavigate, required this.isPastor});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser;
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 배너 슬라이더
          StreamBuilder<List<BannerModel>>(
            stream: firestoreService.streamActiveBanners(),
            builder: (ctx, snap) => BannerSlider(banners: snap.data ?? []),
          ),
          const SizedBox(height: 20),

          // 인사말
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '안녕하세요, ${user?.name ?? ''}님! 👋',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    // 새가족팀장/리더(운영진)는 제외하고, 3주간 팀모임을 진행해야 하는 신규 새가족(일반 회원)에게만 표시
                    if (user != null && user.department == AppTeams.newFamilyTeam && user.role == UserRole.member)
                      _NewFamilyWeekBadge(firestoreService: firestoreService, userId: user.uid),
                    // 새가족팀 리더에게는 새가족팀장이 설정한 로테이션 기준, 이번 주가 본인 담당 주차일 때만 표시
                    if (user != null && user.department == AppTeams.newFamilyTeam && user.role == UserRole.smallLeader)
                      _NewFamilyLeaderRotationBadge(firestoreService: firestoreService, userId: user.uid),
                  ],
                ),
                Text(
                  user?.department ?? '',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // 주요 기능 그리드
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.3,
              children: [
                if (!isPastor) ...[
                  _FeatureCard(
                    icon: Icons.check_circle_outline,
                    label: '출석체크',
                    color: Colors.blue,
                    onTap: () => onNavigate(1),
                  ),
                  _FeatureCard(
                    icon: Icons.payments_outlined,
                    label: '회비납부',
                    color: Colors.green,
                    onTap: () => onNavigate(2),
                  ),
                ],
                _FeatureCard(
                  icon: Icons.favorite_border,
                  // 목사님은 심방을 신청하는 입장이 아니라 확인/확정하는 입장이므로 라벨을 구분
                  label: isPastor ? '심방 현황' : '심방신청',
                  // 목사님은 출석/회비 탭이 없어 심방 탭의 실제 인덱스가 앞당겨짐
                  color: Colors.red,
                  onTap: () => onNavigate(isPastor ? 1 : 3),
                ),
                _FeatureCard(
                  icon: Icons.person_outline,
                  label: '내 정보',
                  color: Colors.purple,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ProfileScreen()),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _FeatureCard({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 32),
            ),
            const SizedBox(height: 8),
            Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

// 새가족팀 배정 후 실제 소팀에 배정받기 전까지, 본인 출석 횟수 기준 'n주차'를 표시
class _NewFamilyWeekBadge extends StatelessWidget {
  final FirestoreService firestoreService;
  final String userId;

  const _NewFamilyWeekBadge({required this.firestoreService, required this.userId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<AttendanceModel>>(
      stream: firestoreService.streamUserAttendance(userId),
      builder: (ctx, snap) {
        final weekCount = (snap.data ?? []).where((a) => a.isPresent).length;
        // 새가족 출석은 정해진 주차까지만 표시 (그 이후는 소팀 배정 대상)
        final displayWeek = weekCount > AppTeams.newFamilyMaxWeeks ? AppTeams.newFamilyMaxWeeks : weekCount;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.accent.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            '$displayWeek주차',
            style: const TextStyle(color: AppColors.accent, fontWeight: FontWeight.w600, fontSize: 13),
          ),
        );
      },
    );
  }
}

// 새가족팀장이 1~3주차별로 고정 배정한 담당 리더 중, 본인이 배정된 주차에
// '현재' 해당하는 새가족(출석 횟수 기준)이 있을 때만 'N주차 담당' 표시
class _NewFamilyLeaderRotationBadge extends StatelessWidget {
  final FirestoreService firestoreService;
  final String userId;

  const _NewFamilyLeaderRotationBadge({required this.firestoreService, required this.userId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<NewFamilyRotationModel>>(
      stream: firestoreService.streamNewFamilyRotations(),
      builder: (ctx, rotSnap) {
        final myWeeks = (rotSnap.data ?? []).where((r) => r.leaderId == userId).map((r) => r.weekNumber).toSet();
        if (myWeeks.isEmpty) return const SizedBox.shrink();

        return StreamBuilder<List<UserModel>>(
          stream: firestoreService.streamAllMembers(),
          builder: (ctx, memberSnap) {
            return StreamBuilder<List<AttendanceModel>>(
              stream: firestoreService.streamAllAttendance(),
              builder: (ctx, attSnap) {
                final members = memberSnap.data ?? [];
                final attendance = attSnap.data ?? [];
                final newFamilyMembers =
                    members.where((m) => m.department == AppTeams.newFamilyTeam && m.role == UserRole.member);

                final matchedWeeks = <int>{};
                for (final m in newFamilyMembers) {
                  final count = attendance.where((a) => a.userId == m.uid && a.isPresent).length;
                  if (myWeeks.contains(count) && count >= 1 && count <= AppTeams.newFamilyMaxWeeks) {
                    matchedWeeks.add(count);
                  }
                }
                if (matchedWeeks.isEmpty) return const SizedBox.shrink();

                final sortedWeeks = matchedWeeks.toList()..sort();
                final label = sortedWeeks.map((w) => '$w주차').join('·');
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '$label 담당',
                    style: const TextStyle(color: AppColors.accent, fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}
