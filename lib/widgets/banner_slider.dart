import 'package:flutter/material.dart';
import 'package:carousel_slider/carousel_slider.dart';
import '../models/banner_model.dart';
import 'app_image.dart';

class BannerSlider extends StatefulWidget {
  final List<BannerModel> banners;

  const BannerSlider({super.key, required this.banners});

  @override
  State<BannerSlider> createState() => _BannerSliderState();
}

class _BannerSliderState extends State<BannerSlider> {
  int _current = 0;

  @override
  Widget build(BuildContext context) {
    if (widget.banners.isEmpty) {
      return _EmptyBanner();
    }
    return Column(
      children: [
        CarouselSlider.builder(
          itemCount: widget.banners.length,
          itemBuilder: (ctx, i, _) => _BannerItem(banner: widget.banners[i]),
          options: CarouselOptions(
            height: 200,
            autoPlay: true,
            autoPlayInterval: const Duration(seconds: 4),
            enlargeCenterPage: false,
            viewportFraction: 1.0,
            onPageChanged: (i, _) => setState(() => _current = i),
          ),
        ),
        if (widget.banners.length > 1) ...[
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              widget.banners.length,
              (i) => AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: _current == i ? 20 : 8,
                height: 8,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  color: _current == i
                      ? Theme.of(context).colorScheme.primary
                      : Colors.grey[300],
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _BannerItem extends StatelessWidget {
  final BannerModel banner;

  const _BannerItem({required this.banner});

  @override
  Widget build(BuildContext context) {
    // 배너 제목은 관리자가 배너를 식별하기 위한 용도로만 쓰이고, 실제 배너 화면에는 노출하지 않음
    final hasDescription = banner.description != null && banner.description!.isNotEmpty;
    return Stack(
      fit: StackFit.expand,
      children: [
        AppImage(imageUrl: banner.imageUrl, fit: BoxFit.cover),
        if (hasDescription)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [Colors.black.withValues(alpha: 0.6), Colors.transparent],
                ),
              ),
              child: Text(
                banner.description!,
                style: const TextStyle(color: Colors.white70, fontSize: 12),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
      ],
    );
  }
}

class _EmptyBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 200,
      color: Colors.grey[200],
      child: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.image, size: 48, color: Colors.grey),
            SizedBox(height: 8),
            Text('등록된 배너가 없습니다', style: TextStyle(color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}
