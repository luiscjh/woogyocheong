import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/demo_data.dart';

/// CachedNetworkImage 대체 위젯.
/// 데모 모드에서 업로드한 이미지(mem://)는 메모리에서 직접 렌더링.
class AppImage extends StatelessWidget {
  final String imageUrl;
  final BoxFit fit;
  final Widget Function(BuildContext, String)? placeholder;
  final Widget Function(BuildContext, String, Object)? errorWidget;

  const AppImage({
    super.key,
    required this.imageUrl,
    this.fit = BoxFit.cover,
    this.placeholder,
    this.errorWidget,
  });

  @override
  Widget build(BuildContext context) {
    if (imageUrl.startsWith('mem://')) {
      final bytes = DemoData.instance.getImageBytes(imageUrl);
      if (bytes != null) {
        return Image.memory(bytes, fit: fit);
      }
      return _error(context);
    }

    return CachedNetworkImage(
      imageUrl: imageUrl,
      fit: fit,
      placeholder: placeholder ?? (ctx, url) => Container(
        color: Colors.grey[200],
        child: const Center(child: CircularProgressIndicator()),
      ),
      errorWidget: errorWidget ?? (ctx, url, err) => _error(context),
    );
  }

  Widget _error(BuildContext context) => Container(
    color: Colors.grey[200],
    child: const Icon(Icons.image_not_supported, size: 48, color: Colors.grey),
  );
}
