// lib/services/in_app_notification_banner.dart
import 'dart:ui';
import 'package:flutter/material.dart';

/// Foreground пуш уведомлениялары үчүн айнек стилиндеги banner.
/// navigatorKey.currentContext аркылуу Overlay'ге кошулат.
class InAppNotificationBanner {
  static OverlayEntry? _current;

  static void show({
    required BuildContext context,
    required String title,
    required String body,
    String? avatarText,
    VoidCallback? onTap,
    Duration duration = const Duration(seconds: 4),
  }) {
    // Эски banner болсо алып салабыз
    _current?.remove();
    _current = null;

    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _BannerWidget(
        title: title,
        body: body,
        avatarText: avatarText,
        onTap: () {
          entry.remove();
          _current = null;
          onTap?.call();
        },
        onDismiss: () {
          entry.remove();
          _current = null;
        },
        duration: duration,
      ),
    );

    _current = entry;
    Overlay.of(context, rootOverlay: true).insert(entry);
  }
}

class _BannerWidget extends StatefulWidget {
  final String title;
  final String body;
  final String? avatarText;
  final VoidCallback onTap;
  final VoidCallback onDismiss;
  final Duration duration;

  const _BannerWidget({
    required this.title,
    required this.body,
    required this.onTap,
    required this.onDismiss,
    required this.duration,
    this.avatarText,
  });

  @override
  State<_BannerWidget> createState() => _BannerWidgetState();
}

class _BannerWidgetState extends State<_BannerWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<Offset> _slide;
  late Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );

    _slide = Tween<Offset>(
      begin: const Offset(0, -1.2),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack));

    _fade = Tween<double>(begin: 0, end: 1)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));

    _ctrl.forward();

    // Авто жашыруу
    Future.delayed(widget.duration, () {
      if (mounted) _dismiss();
    });
  }

  Future<void> _dismiss() async {
    await _ctrl.reverse();
    widget.onDismiss();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;

    return Positioned(
      top: topPadding + 12,
      left: 16,
      right: 16,
      child: SlideTransition(
        position: _slide,
        child: FadeTransition(
          opacity: _fade,
          child: GestureDetector(
            onTap: widget.onTap,
            onVerticalDragEnd: (d) {
              if (d.primaryVelocity != null && d.primaryVelocity! < 0) {
                _dismiss();
              }
            },
            child: _GlassBanner(
              title: widget.title,
              body: widget.body,
              avatarText: widget.avatarText,
              onClose: _dismiss,
            ),
          ),
        ),
      ),
    );
  }
}

class _GlassBanner extends StatelessWidget {
  final String title;
  final String body;
  final String? avatarText;
  final VoidCallback onClose;

  const _GlassBanner({
    required this.title,
    required this.body,
    required this.onClose,
    this.avatarText,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
        child: Container(
          decoration: BoxDecoration(
            // ── Жарык күндүн нурундай градиент ──
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withOpacity(0.82),
                Colors.white.withOpacity(0.60),
                const Color(0xFFFFF8E7).withOpacity(0.55),
              ],
              stops: const [0.0, 0.5, 1.0],
            ),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: Colors.white.withOpacity(0.90),
              width: 1.2,
            ),
            boxShadow: [
              // ── Жылтырак жарык үстүнкү жарты ──
              BoxShadow(
                color: Colors.white.withOpacity(0.70),
                blurRadius: 0,
                spreadRadius: 0,
                offset: const Offset(0, 0),
              ),
              // ── Негизги жумшак көлөкө ──
              BoxShadow(
                color: const Color(0xFFFFD580).withOpacity(0.25),
                blurRadius: 24,
                spreadRadius: 2,
                offset: const Offset(0, 8),
              ),
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 20,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Stack(
            children: [
              // ── Жогорку жарык чийме (shimmer эффект) ──
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Container(
                  height: 1.5,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.transparent,
                        Colors.white.withOpacity(0.95),
                        Colors.white.withOpacity(0.60),
                        Colors.transparent,
                      ],
                      stops: const [0.0, 0.3, 0.7, 1.0],
                    ),
                    borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(22)),
                  ),
                ),
              ),

              // ── Контент ──
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 44, 14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Аватар
                    _Avatar(text: avatarText ?? title),
                    const SizedBox(width: 12),

                    // Текст
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF1A1A2E),
                              letterSpacing: -0.2,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 3),
                          Text(
                            body,
                            style: TextStyle(
                              fontSize: 13,
                              color: const Color(0xFF1A1A2E).withOpacity(0.70),
                              height: 1.35,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // ── Жабуу баскычы ──
              Positioned(
                top: 10,
                right: 10,
                child: GestureDetector(
                  onTap: onClose,
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.08),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.close_rounded,
                      size: 14,
                      color: Colors.black.withOpacity(0.50),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  final String text;
  const _Avatar({required this.text});

  @override
  Widget build(BuildContext context) {
    final letter = text.isNotEmpty ? text[0].toUpperCase() : '?';
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFFFD580), // жарык алтын
            Color(0xFFFF8C42), // жылуу кызгылт
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFFD580).withOpacity(0.45),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Center(
        child: Text(
          letter,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
