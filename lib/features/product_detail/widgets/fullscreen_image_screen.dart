// ══════════════════════════════════════════════════════
// FULLSCREEN IMAGE
// product_detail_screen.dart файлынан бөлүнүп чыгарылды.
// ══════════════════════════════════════════════════════
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

class FullscreenImageScreen extends StatefulWidget {
  final List<String> images;
  final int initialIndex;
  final String heroTag;
  const FullscreenImageScreen({
    super.key,
    required this.images,
    required this.initialIndex,
    required this.heroTag,
  });

  @override
  State<FullscreenImageScreen> createState() => _FullscreenImageScreenState();
}

class _FullscreenImageScreenState extends State<FullscreenImageScreen> {
  late PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(children: [
        PageView.builder(
          controller: _pageController,
          itemCount: widget.images.length,
          onPageChanged: (i) => setState(() => _currentIndex = i),
          itemBuilder: (context, index) {
            final url = widget.images[index];
            return InteractiveViewer(
              minScale: 0.8,
              maxScale: 5.0,
              child: index == widget.initialIndex
                  ? Hero(
                      tag: widget.heroTag,
                      child: CachedNetworkImage(
                        imageUrl: url,
                        width: screenSize.width,
                        height: screenSize.height,
                        fit: BoxFit.contain,
                        placeholder: (_, __) => const Center(
                            child:
                                CircularProgressIndicator(color: Colors.white)),
                        errorWidget: (_, __, ___) => const Center(
                            child: Icon(Icons.image_not_supported_outlined,
                                color: Colors.white54, size: 64)),
                      ),
                    )
                  : CachedNetworkImage(
                      imageUrl: url,
                      width: screenSize.width,
                      height: screenSize.height,
                      fit: BoxFit.contain,
                      placeholder: (_, __) => const Center(
                          child:
                              CircularProgressIndicator(color: Colors.white)),
                      errorWidget: (_, __, ___) => const Center(
                          child: Icon(Icons.image_not_supported_outlined,
                              color: Colors.white54, size: 64)),
                    ),
            );
          },
        ),

        // ── Жабуу баскычы ──
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(20)),
                child: const Icon(Icons.close, color: Colors.white, size: 24),
              ),
            ),
          ),
        ),

        // ── Индикатор (бир нече сүрөт болгондо) ──
        if (widget.images.length > 1)
          Positioned(
            bottom: 24,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(widget.images.length, (i) {
                final active = i == _currentIndex;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: active ? 20 : 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: active ? Colors.white : Colors.white38,
                    borderRadius: BorderRadius.circular(4),
                  ),
                );
              }),
            ),
          ),
      ]),
    );
  }
}
