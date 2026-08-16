import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:excel/excel.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../services/firestore_service.dart';
import '../../models/user_model.dart';
import '../../models/attendance_model.dart';
import '../../models/new_family_rotation_model.dart';
import '../../providers/auth_provider.dart';
import '../../utils/constants.dart';

class MemberManagementScreen extends StatefulWidget {
  // true이면 사역팀(콘텐츠팀 등) 팀장이 본인 팀원 명단을 조회만 할 수 있는 모드.
  // 이메일/소속팀 변경 등 관리자 수준의 회원 정보 수정은 할 수 없고, 조회만 가능
  final bool readOnly;

  const MemberManagementScreen({super.key, this.readOnly = false});

  @override
  State<MemberManagementScreen> createState() => _MemberManagementScreenState();
}

class _MemberManagementScreenState extends State<MemberManagementScreen> {
  final _service = FirestoreService();

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final currentUser = authProvider.currentUser!;

    // 새가족팀 리더는 팀 전체 명단(팀장/다른 리더 포함)이 아니라, 본인이
    // 배정된 주차에 해당하는 새가족만 확인하면 되므로 화면을 대체
    if (currentUser.role == UserRole.smallLeader && currentUser.department == AppTeams.newFamilyTeam) {
      return _LeaderAssignedFamilyView(service: _service, currentUser: currentUser);
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.readOnly ? '회원 조회' : '회원 관리'),
        actions: widget.readOnly
            ? null
            : [
                IconButton(
                  icon: const Icon(Icons.help_outline),
                  tooltip: '파일 형식 안내',
                  onPressed: _showFormatGuide,
                ),
                IconButton(
                  icon: const Icon(Icons.upload_file),
                  tooltip: '엑셀/CSV 가져오기',
                  onPressed: _importFile,
                ),
              ],
      ),
      body: StreamBuilder<List<UserModel>>(
        stream: _service.streamAllMembers(),
        builder: (ctx, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          // 목사님은 회원 관리 대상에서 제외
          var members = (snap.data ?? []).where((m) => m.role != UserRole.pastor).toList();
          if (widget.readOnly) {
            // 사역팀장 조회 모드: 본인 사역팀 소속 인원만 조회
            members = members.where((m) => m.ministryTeam == currentUser.ministryTeam).toList();
          } else if (!authProvider.isExecutive) {
            // 역할에 따라 조회 범위 제한
            if (authProvider.isMidLeader) {
              members = members.where((m) => m.midTeam == currentUser.midTeam).toList();
            } else if (authProvider.isSmallLeader) {
              members = members.where((m) => m.department == currentUser.department).toList();
            }
          }
          if (members.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.people_outline, size: 64, color: Colors.grey),
                  const SizedBox(height: 12),
                  const Text('등록된 회원이 없습니다.'),
                  if (!widget.readOnly) ...[
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () => _showAddMemberDialog(context),
                      icon: const Icon(Icons.person_add),
                      label: const Text('회원 추가'),
                    ),
                  ],
                ],
              ),
            );
          }
          return StreamBuilder<List<AttendanceModel>>(
            stream: _service.streamAllAttendance(),
            builder: (ctx, attSnap) {
              final attendance = attSnap.data ?? [];
              return ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: members.length,
                itemBuilder: (ctx, i) => _MemberTile(
                  member: members[i],
                  service: _service,
                  readOnly: widget.readOnly,
                  onEdit: () => _showEditMemberDialog(context, members[i]),
                  // 사역팀장 본인은 관리자만 소속을 변경할 수 있으므로 제거 대상에서 제외
                  onRemoveFromMinistryTeam: widget.readOnly && !members[i].isMinistryLead
                      ? () => _confirmRemoveFromMinistryTeam(context, members[i])
                      : null,
                  newFamilyWeek: _newFamilyWeek(members[i], attendance),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: widget.readOnly
          ? null
          : FloatingActionButton(
              onPressed: () => _showAddMemberDialog(context),
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              child: const Icon(Icons.person_add),
            ),
    );
  }

  // 새가족팀 소속 일반 팀원(=새가족 본인, 리더/팀장 제외)의 출석 횟수 기준 진행 주차.
  // 새가족이 아니면 null을 반환해 일반 소속팀 라벨을 그대로 쓰도록 함
  int? _newFamilyWeek(UserModel member, List<AttendanceModel> attendance) {
    if (member.department != AppTeams.newFamilyTeam || member.role != UserRole.member) return null;
    final count = attendance.where((a) => a.userId == member.uid && a.isPresent).length;
    return count > AppTeams.newFamilyMaxWeeks ? AppTeams.newFamilyMaxWeeks : count;
  }

  // 사역팀(콘텐츠팀 등) 팀장이 본인 팀에서 팀원을 제거함. 이메일/소속팀(department)
  // 등 다른 회원 정보는 건드리지 않고 사역팀 소속(ministryTeam)만 해제함
  Future<void> _confirmRemoveFromMinistryTeam(BuildContext context, UserModel member) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('콘텐츠팀에서 제거'),
        content: Text('${member.name}님을 콘텐츠팀에서 제거하시겠습니까?\n소속팀 등 다른 정보는 유지되고 콘텐츠팀 소속만 해제됩니다.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('취소')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('제거'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    await _service.updateUser(member.copyWith(
      ministryTeam: '',
      isMinistryLead: false,
      bannerAccessGranted: false,
    ));
  }

  void _showFormatGuide() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('파일 형식 안내'),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('지원 형식: .xlsx, .xls, .csv', style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 12),
              Text('열 순서 (첫 번째 행은 헤더):'),
              SizedBox(height: 6),
              Text('A열: 이름 (필수)'),
              Text('B열: 팀/부서 (필수)'),
              Text('C열: 전화번호'),
              Text('D열: 이메일'),
              SizedBox(height: 12),
              Text('예시:', style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 4),
              Text('이름  | 팀    | 전화번호       | 이메일'),
              Text('홍길동 | 1팀   | 010-1234-5678 | hong@gmail.com'),
              Text('김철수 | 2팀   | 010-9876-5432 |'),
              SizedBox(height: 12),
              Text('※ CSV 파일은 UTF-8 인코딩으로 저장해 주세요.',
                  style: TextStyle(fontSize: 12, color: Colors.grey)),
            ],
          ),
        ),
        actions: [
          ElevatedButton(onPressed: () => Navigator.pop(ctx), child: const Text('확인')),
        ],
      ),
    );
  }

  Future<void> _importFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx', 'xls', 'csv'],
      withData: true, // 웹 호환: bytes로 직접 읽기
    );
    if (result == null) return;

    final file = result.files.single;
    final bytes = file.bytes;
    if (bytes == null) return;

    try {
      final ext = file.extension?.toLowerCase();
      // String.fromCharCodes는 UTF-8을 디코딩하지 않고 바이트를 그대로 문자
      // 코드로 취급해 한글(3바이트 문자)이 깨지므로 반드시 utf8.decode 사용
      final members = ext == 'csv'
          ? _parseCsv(utf8.decode(bytes, allowMalformed: true))
          : _parseExcel(bytes);

      if (members.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('불러올 데이터가 없습니다. 파일 형식을 확인해 주세요.'), backgroundColor: AppColors.warning),
          );
        }
        return;
      }

      if (!mounted) return;
      final confirm = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('회원 가져오기'),
          content: Text('${members.length}명의 회원 정보를 가져옵니다.\n기존 목록에 추가됩니다.\n계속하시겠습니까?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('취소')),
            ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('가져오기')),
          ],
        ),
      );

      if (confirm != true) return;
      await _service.importMembers(members);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${members.length}명의 회원 정보를 가져왔습니다.'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('파일 읽기 오류: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  List<UserModel> _parseExcel(Uint8List bytes) {
    final excel = Excel.decodeBytes(bytes);
    final sheet = excel.tables.values.first;
    final members = <UserModel>[];

    // 컬럼: A=이름, B=팀/부서, C=전화번호, D=이메일
    for (var i = 1; i < sheet.rows.length; i++) {
      final row = sheet.rows[i];
      if (row.isEmpty || row[0]?.value == null) continue;

      final name = row[0]?.value?.toString().trim() ?? '';
      final dept = row.length > 1 ? (row[1]?.value?.toString().trim() ?? '') : '';
      final phone = row.length > 2 ? (row[2]?.value?.toString().trim() ?? '') : '';
      final email = row.length > 3 ? (row[3]?.value?.toString().trim() ?? '') : '';

      if (name.isEmpty) continue;

      members.add(UserModel(
        uid: const Uuid().v4(),
        name: name,
        email: email,
        phone: phone,
        role: 'member',
        department: dept,
        joinDate: DateTime.now(),
      ));
    }
    return members;
  }

  List<UserModel> _parseCsv(String content) {
    // BOM 제거
    final cleaned = content.startsWith('﻿') ? content.substring(1) : content;
    final lines = cleaned.split(RegExp(r'\r?\n'));
    final members = <UserModel>[];

    // 컬럼: 이름, 팀/부서, 전화번호, 이메일
    for (var i = 1; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;

      final cells = _splitCsvLine(line);
      final name = cells.isNotEmpty ? cells[0].trim() : '';
      final dept = cells.length > 1 ? cells[1].trim() : '';
      final phone = cells.length > 2 ? cells[2].trim() : '';
      final email = cells.length > 3 ? cells[3].trim() : '';

      if (name.isEmpty) continue;

      members.add(UserModel(
        uid: const Uuid().v4(),
        name: name,
        email: email,
        phone: phone,
        role: 'member',
        department: dept,
        joinDate: DateTime.now(),
      ));
    }
    return members;
  }

  List<String> _splitCsvLine(String line) {
    final cells = <String>[];
    final buffer = StringBuffer();
    var inQuotes = false;

    for (var i = 0; i < line.length; i++) {
      final ch = line[i];
      if (ch == '"') {
        inQuotes = !inQuotes;
      } else if (ch == ',' && !inQuotes) {
        cells.add(buffer.toString());
        buffer.clear();
      } else {
        buffer.write(ch);
      }
    }
    cells.add(buffer.toString());
    return cells;
  }

  void _showAddMemberDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => _MemberFormDialog(service: _service),
    );
  }

  void _showEditMemberDialog(BuildContext context, UserModel member) {
    showDialog(
      context: context,
      builder: (_) => _MemberFormDialog(service: _service, member: member),
    );
  }
}

// 새가족팀 리더 전용 뷰: 팀 전체 명단 대신, 본인이 배정된 주차(1~3주차)에
// 해당하는 새가족만 읽기 전용으로 보여줌
class _LeaderAssignedFamilyView extends StatelessWidget {
  final FirestoreService service;
  final UserModel currentUser;

  const _LeaderAssignedFamilyView({required this.service, required this.currentUser});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('회원 관리')),
      body: StreamBuilder<List<UserModel>>(
        stream: service.streamAllMembers(),
        builder: (ctx, memberSnap) {
          return StreamBuilder<List<AttendanceModel>>(
            stream: service.streamAllAttendance(),
            builder: (ctx, attSnap) {
              return StreamBuilder<List<NewFamilyRotationModel>>(
                stream: service.streamNewFamilyRotations(),
                builder: (ctx, rotSnap) {
                  if (memberSnap.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final members = memberSnap.data ?? [];
                  final attendance = attSnap.data ?? [];
                  final rotations = rotSnap.data ?? [];

                  final myWeeks = rotations
                      .where((r) => r.leaderId == currentUser.uid)
                      .map((r) => r.weekNumber)
                      .toList()
                    ..sort();

                  if (myWeeks.isEmpty) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text('아직 배정된 담당 주차가 없습니다.', style: TextStyle(color: AppColors.textSecondary)),
                      ),
                    );
                  }

                  // 새가족(일반 회원)의 현재 주차를 출석 횟수 기준으로 계산
                  final newFamilyMembers = members
                      .where((m) => m.department == AppTeams.newFamilyTeam && m.role == UserRole.member)
                      .toList();
                  final weekOf = <String, int>{};
                  for (final m in newFamilyMembers) {
                    final count = attendance.where((a) => a.userId == m.uid && a.isPresent).length;
                    if (count >= 1 && count <= AppTeams.newFamilyMaxWeeks) {
                      weekOf[m.uid] = count;
                    }
                  }

                  return ListView(
                    padding: const EdgeInsets.all(12),
                    children: [
                      for (final week in myWeeks)
                        Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('$week주차 담당', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                const SizedBox(height: 8),
                                const Text('현재 이 주차에 해당하는 새가족', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                                const SizedBox(height: 4),
                                Builder(builder: (ctx) {
                                  final names = [
                                    for (final m in newFamilyMembers)
                                      if (weekOf[m.uid] == week) m.name,
                                  ];
                                  if (names.isEmpty) {
                                    return const Text('현재 이 주차에 해당하는 새가족이 없습니다.',
                                        style: TextStyle(fontSize: 12, color: AppColors.textSecondary));
                                  }
                                  return Wrap(
                                    spacing: 6,
                                    runSpacing: 6,
                                    children: names
                                        .map((name) => Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                              decoration: BoxDecoration(
                                                color: AppColors.primary.withValues(alpha: 0.1),
                                                borderRadius: BorderRadius.circular(10),
                                              ),
                                              child: Text(name,
                                                  style: const TextStyle(
                                                      color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w600)),
                                            ))
                                        .toList(),
                                  );
                                }),
                              ],
                            ),
                          ),
                        ),
                    ],
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

class _MemberTile extends StatelessWidget {
  final UserModel member;
  final FirestoreService service;
  final VoidCallback onEdit;
  final bool readOnly;
  // 조회 전용(readOnly) 화면에서만 사용되는, 사역팀에서 팀원을 제거하는 액션
  final VoidCallback? onRemoveFromMinistryTeam;
  // null이 아니면 새가족(새가족팀 소속 일반 팀원)이라는 뜻이며, 소속팀 라벨 대신
  // "새가족 n주차"를 표시하는 데 사용됨
  final int? newFamilyWeek;

  const _MemberTile({
    required this.member,
    required this.service,
    required this.onEdit,
    this.readOnly = false,
    this.onRemoveFromMinistryTeam,
    this.newFamilyWeek,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: member.isAdmin ? AppColors.accent : AppColors.primary,
          child: Text(
            member.name.isNotEmpty ? member.name[0] : '?',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
        title: Row(
          children: [
            Text(member.name),
            if (member.isAdmin) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(UserRole.label(member.role), style: const TextStyle(color: AppColors.accent, fontSize: 10)),
              ),
            ],
          ],
        ),
        subtitle: Text(
          '${newFamilyWeek != null ? '새가족 $newFamilyWeek주차' : AppTeams.deptLabel(member.department)} · ${member.email}',
        ),
        trailing: readOnly
            ? (onRemoveFromMinistryTeam == null
                ? null
                : TextButton(
                    onPressed: onRemoveFromMinistryTeam,
                    style: TextButton.styleFrom(foregroundColor: AppColors.error),
                    child: const Text('제거'),
                  ))
            : PopupMenuButton<String>(
                onSelected: (v) {
                  if (v == 'edit') onEdit();
                  if (v == 'delete') _confirmDelete(context);
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'edit', child: Text('수정')),
                  const PopupMenuItem(value: 'delete', child: Text('삭제', style: TextStyle(color: Colors.red))),
                ],
              ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('회원 삭제'),
        content: Text('${member.name}님을 삭제하시겠습니까?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('취소')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await service.deleteUser(member.uid);
    }
  }
}

class _MemberFormDialog extends StatefulWidget {
  final FirestoreService service;
  final UserModel? member;

  const _MemberFormDialog({required this.service, this.member});

  @override
  State<_MemberFormDialog> createState() => _MemberFormDialogState();
}

class _MemberFormDialogState extends State<_MemberFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _phoneCtrl;
  late String _dept;
  late String _role;
  late String _ministryTeam;
  late bool _isMinistryLead;
  late bool _bannerAccessGranted;
  late final TextEditingController _cohortCtrl;
  DateTime? _birthDate;
  bool _isLoading = false;

  bool get isEditing => widget.member != null;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.member?.name);
    _emailCtrl = TextEditingController(text: widget.member?.email);
    _phoneCtrl = TextEditingController(text: widget.member?.phone);
    _dept = widget.member?.department ?? AppTeams.smallTeams.first;
    // allDepts에 없는 값이면 기본값으로 fallback
    if (!AppTeams.allDepts.contains(_dept)) _dept = AppTeams.smallTeams.first;
    _role = widget.member?.role ?? UserRole.member;
    _ministryTeam = widget.member?.ministryTeam ?? '';
    _isMinistryLead = widget.member?.isMinistryLead ?? false;
    _bannerAccessGranted = widget.member?.bannerAccessGranted ?? false;
    _cohortCtrl = TextEditingController(text: widget.member?.cohort?.toString());
    _birthDate = widget.member?.birthDate;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _cohortCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickBirthDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthDate ?? DateTime(2000, 1, 1),
      firstDate: DateTime(1950),
      lastDate: DateTime.now(),
      locale: const Locale('ko'),
    );
    if (picked != null) setState(() => _birthDate = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    // 임원팀/중팀장 이상 역할은 사역팀에 소속될 수 없으므로 방어적으로 초기화
    final canJoinMinistry = AppTeams.canJoinMinistryTeam(_role);
    final effectiveMinistryTeam = canJoinMinistry ? _ministryTeam : '';
    final effectiveIsMinistryLead = canJoinMinistry ? _isMinistryLead : false;
    // 배너 관리 권한 공유는 콘텐츠팀 팀장이 아닌 콘텐츠팀 팀원에게만 의미가 있음
    // (팀장은 이미 고유 권한으로 보유)
    final effectiveBannerAccessGranted =
        effectiveMinistryTeam == AppTeams.contentTeam && !effectiveIsMinistryLead ? _bannerAccessGranted : false;
    final cohortText = _cohortCtrl.text.trim();
    final cohort = cohortText.isEmpty ? null : int.tryParse(cohortText);

    try {
      if (isEditing) {
        final updated = widget.member!.copyWith(
          name: _nameCtrl.text.trim(),
          email: _emailCtrl.text.trim(),
          phone: _phoneCtrl.text.trim(),
          department: _dept,
          role: _role,
          ministryTeam: effectiveMinistryTeam,
          isMinistryLead: effectiveIsMinistryLead,
          bannerAccessGranted: effectiveBannerAccessGranted,
          birthDate: _birthDate,
          cohort: cohort,
        );
        await widget.service.updateUser(updated);
        // 본인 계정을 수정한 경우, 방금 저장한 값이 현재 세션의 AuthProvider
        // 캐시에도 즉시 반영되도록 함 (그렇지 않으면 재로그인 전까지 배너 관리
        // 권한 공유 등 변경 사항이 화면에 반영되지 않음)
        if (mounted && context.read<AuthProvider>().currentUser?.uid == updated.uid) {
          context.read<AuthProvider>().setCurrentUser(updated);
        }
      } else {
        final user = UserModel(
          uid: const Uuid().v4(),
          name: _nameCtrl.text.trim(),
          email: _emailCtrl.text.trim(),
          phone: _phoneCtrl.text.trim(),
          role: _role,
          department: _dept,
          joinDate: DateTime.now(),
          ministryTeam: effectiveMinistryTeam,
          isMinistryLead: effectiveIsMinistryLead,
          bannerAccessGranted: effectiveBannerAccessGranted,
          birthDate: _birthDate,
          cohort: cohort,
        );
        await widget.service.importMembers([user]);
      }
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    // 사역팀장 지정(콘텐츠팀 등 사역팀의 고유 권한 보유자 지정)은 관리자만 가능
    final canEditMinistryLead = auth.isAdmin;
    // 배너 관리 권한 공유(위임)는 관리자 또는 해당 사역팀 팀장만 가능
    final canShareBannerAccess = auth.canShareBannerAccess;

    return AlertDialog(
      title: Text(isEditing ? '회원 수정' : '회원 추가'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(labelText: '이름 *'),
                validator: (v) => (v == null || v.isEmpty) ? '이름을 입력해 주세요.' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _emailCtrl,
                decoration: const InputDecoration(labelText: '이메일 *'),
                keyboardType: TextInputType.emailAddress,
                validator: (v) => (v == null || v.isEmpty) ? '이메일을 입력해 주세요.' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _phoneCtrl,
                decoration: const InputDecoration(labelText: '전화번호'),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 12),
              InkWell(
                onTap: _pickBirthDate,
                child: InputDecorator(
                  decoration: const InputDecoration(labelText: '생년월일', prefixIcon: Icon(Icons.cake_outlined)),
                  child: Text(
                    _birthDate != null ? DateFormat('yyyy년 MM월 dd일').format(_birthDate!) : '선택 안 함',
                    style: TextStyle(color: _birthDate != null ? null : Theme.of(context).hintColor),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _cohortCtrl,
                decoration: const InputDecoration(labelText: '기수', prefixIcon: Icon(Icons.groups_2_outlined)),
                keyboardType: TextInputType.number,
                validator: (v) => (v != null && v.trim().isNotEmpty && int.tryParse(v.trim()) == null)
                    ? '숫자를 입력해 주세요.'
                    : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: AppTeams.allDepts.contains(_dept) ? _dept : AppTeams.smallTeams.first,
                decoration: const InputDecoration(labelText: '소속팀'),
                items: AppTeams.allDepts.map((t) => DropdownMenuItem(
                  value: t,
                  child: Text(AppTeams.deptLabel(t)),
                )).toList(),
                onChanged: (v) => setState(() => _dept = v!),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: UserRole.labels.containsKey(_role) ? _role : UserRole.member,
                decoration: const InputDecoration(labelText: '역할'),
                items: UserRole.labels.entries
                    .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
                    .toList(),
                onChanged: (v) => setState(() {
                  _role = v!;
                  // 임원팀/중팀장 이상은 사역팀에 소속될 수 없으므로 선택을 초기화
                  if (!AppTeams.canJoinMinistryTeam(_role)) {
                    _ministryTeam = '';
                    _isMinistryLead = false;
                  }
                }),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: AppTeams.canJoinMinistryTeam(_role) ? _ministryTeam : '',
                decoration: const InputDecoration(labelText: '사역팀 (선택)'),
                items: [
                  const DropdownMenuItem(value: '', child: Text('없음')),
                  ...AppTeams.ministryTeams.map((t) => DropdownMenuItem(value: t, child: Text(t))),
                ],
                onChanged: !AppTeams.canJoinMinistryTeam(_role)
                    ? null
                    : (v) => setState(() {
                          _ministryTeam = v ?? '';
                          if (_ministryTeam.isEmpty) _isMinistryLead = false;
                        }),
              ),
              if (AppTeams.canJoinMinistryTeam(_role) && _ministryTeam.isNotEmpty)
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  title: const Text('사역팀장'),
                  subtitle: canEditMinistryLead ? null : const Text('사역팀장 지정은 관리자만 변경할 수 있습니다.'),
                  value: _isMinistryLead,
                  onChanged: canEditMinistryLead ? (v) => setState(() => _isMinistryLead = v ?? false) : null,
                ),
              if (AppTeams.canJoinMinistryTeam(_role) &&
                  _ministryTeam == AppTeams.contentTeam &&
                  !_isMinistryLead)
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  title: const Text('배너 관리 권한 공유'),
                  subtitle: canShareBannerAccess
                      ? const Text('콘텐츠팀 팀장이 지정한 팀원만 배너 관리 권한을 공유받을 수 있습니다.')
                      : const Text('배너 관리 권한 공유는 관리자 또는 콘텐츠팀 팀장만 설정할 수 있습니다.'),
                  value: _bannerAccessGranted,
                  onChanged: canShareBannerAccess ? (v) => setState(() => _bannerAccessGranted = v ?? false) : null,
                ),
            ],
          ),
        ),
      ),
      actions: [
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
