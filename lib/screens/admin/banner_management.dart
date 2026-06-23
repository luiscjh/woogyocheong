import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../services/firestore_service.dart';
import '../../services/storage_service.dart';
import '../../models/banner_model.dart';
import '../../utils/constants.dart';

class BannerManagementScreen extends StatefulWidget {
  const BannerManagementScreen({super.key});

  @override
  State<BannerManagementScreen> createState() => _BannerManagementScreenState();
}

class _BannerManagementScreenState extends State<BannerManagementScreen> {
  final _firestore = FirestoreService();
  final _storage = StorageService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('배너 관리')),
      body: StreamBuilder<List<BannerModel>>(
        stream: _firestore.streamAllBanners(),
        builder: (ctx, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final banners = snap.data ?? [];
          if (banners.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.image_outlined, size: 64, color: Colors.grey),
                  const SizedBox(height: 12),
                  const Text('등록된 배너가 없습니다.'),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () => _showAddBannerDialog(context),
                    icon: const Icon(Icons.add_photo_alternate),
                    label: const Text('배너 추가'),
                  ),
                ],
              ),
            );
          }
          return ReorderableListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: banners.length,
            onReorderItem: (oldIndex, newIndex) => _reorder(banners, oldIndex, newIndex),
            itemBuilder: (ctx, i) => _BannerTile(
              key: ValueKey(banners[i].id),
              banner: banners[i],
              onEdit: () => _showAddBannerDialog(context, banner: banners[i]),
              onDelete: () => _deleteBanner(banners[i]),
              onToggle: () => _toggleActive(banners[i]),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddBannerDialog(context),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add_photo_alternate),
      ),
    );
  }

  Future<void> _reorder(List<BannerModel> banners, int oldIndex, int newIndex) async {
    if (oldIndex < newIndex) newIndex--;
    final item = banners.removeAt(oldIndex);
    banners.insert(newIndex, item);
    for (var i = 0; i < banners.length; i++) {
      await _firestore.updateBanner(BannerModel(
        id: banners[i].id,
        title: banners[i].title,
        description: banners[i].description,
        imageUrl: banners[i].imageUrl,
        order: i,
        isActive: banners[i].isActive,
        createdAt: banners[i].createdAt,
      ));
    }
  }

  Future<void> _deleteBanner(BannerModel banner) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('배너 삭제'),
        content: Text('"${banner.title}" 배너를 삭제하시겠습니까?'),
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
    if (confirm != true) return;
    await _firestore.deleteBanner(banner.id);
    await _storage.deleteFile(banner.imageUrl);
  }

  Future<void> _toggleActive(BannerModel banner) async {
    await _firestore.updateBanner(BannerModel(
      id: banner.id,
      title: banner.title,
      description: banner.description,
      imageUrl: banner.imageUrl,
      order: banner.order,
      isActive: !banner.isActive,
      createdAt: banner.createdAt,
    ));
  }

  void _showAddBannerDialog(BuildContext context, {BannerModel? banner}) {
    showDialog(
      context: context,
      builder: (_) => _BannerFormDialog(
        firestore: _firestore,
        storage: _storage,
        banner: banner,
        nextOrder: 999,
      ),
    );
  }
}

class _BannerTile extends StatelessWidget {
  final BannerModel banner;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onToggle;

  const _BannerTile({
    super.key,
    required this.banner,
    required this.onEdit,
    required this.onDelete,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: CachedNetworkImage(
            imageUrl: banner.imageUrl,
            width: 60,
            height: 60,
            fit: BoxFit.cover,
            errorWidget: (_, __, ___) => Container(
              width: 60,
              height: 60,
              color: Colors.grey[200],
              child: const Icon(Icons.image),
            ),
          ),
        ),
        title: Text(banner.title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(banner.description ?? '', maxLines: 1, overflow: TextOverflow.ellipsis),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Switch(value: banner.isActive, onChanged: (_) => onToggle()),
            PopupMenuButton<String>(
              onSelected: (v) {
                if (v == 'edit') onEdit();
                if (v == 'delete') onDelete();
              },
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'edit', child: Text('수정')),
                const PopupMenuItem(value: 'delete', child: Text('삭제', style: TextStyle(color: Colors.red))),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _BannerFormDialog extends StatefulWidget {
  final FirestoreService firestore;
  final StorageService storage;
  final BannerModel? banner;
  final int nextOrder;

  const _BannerFormDialog({
    required this.firestore,
    required this.storage,
    this.banner,
    required this.nextOrder,
  });

  @override
  State<_BannerFormDialog> createState() => _BannerFormDialogState();
}

class _BannerFormDialogState extends State<_BannerFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleCtrl;
  late final TextEditingController _descCtrl;
  File? _imageFile;
  bool _isLoading = false;

  bool get isEditing => widget.banner != null;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.banner?.title);
    _descCtrl = TextEditingController(text: widget.banner?.description);
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final file = await widget.storage.pickImageFromGallery();
    if (file != null) setState(() => _imageFile = file);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (!isEditing && _imageFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('이미지를 선택해 주세요.'), backgroundColor: AppColors.warning),
      );
      return;
    }
    setState(() => _isLoading = true);
    try {
      String imageUrl = widget.banner?.imageUrl ?? '';
      if (_imageFile != null) {
        imageUrl = await widget.storage.uploadBannerImage(_imageFile!);
      }

      if (isEditing) {
        await widget.firestore.updateBanner(BannerModel(
          id: widget.banner!.id,
          title: _titleCtrl.text.trim(),
          description: _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
          imageUrl: imageUrl,
          order: widget.banner!.order,
          isActive: widget.banner!.isActive,
          createdAt: widget.banner!.createdAt,
        ));
      } else {
        await widget.firestore.addBanner(BannerModel(
          id: '',
          title: _titleCtrl.text.trim(),
          description: _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
          imageUrl: imageUrl,
          order: widget.nextOrder,
          isActive: true,
          createdAt: DateTime.now(),
        ));
      }
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(isEditing ? '배너 수정' : '배너 추가'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              GestureDetector(
                onTap: _pickImage,
                child: Container(
                  height: 150,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: _imageFile != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.file(_imageFile!, fit: BoxFit.cover),
                        )
                      : widget.banner?.imageUrl != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: CachedNetworkImage(
                                imageUrl: widget.banner!.imageUrl,
                                fit: BoxFit.cover,
                              ),
                            )
                          : const Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.add_photo_alternate, size: 48, color: Colors.grey),
                                Text('이미지 선택', style: TextStyle(color: Colors.grey)),
                              ],
                            ),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _titleCtrl,
                decoration: const InputDecoration(labelText: '제목 *'),
                validator: (v) => (v == null || v.isEmpty) ? '제목을 입력해 주세요.' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _descCtrl,
                decoration: const InputDecoration(labelText: '설명 (선택사항)'),
                maxLines: 2,
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
