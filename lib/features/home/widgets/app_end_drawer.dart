import 'package:flutter/material.dart';
import '../../promotions/screens/promotion_screen.dart';
import '../../stories/models/story_model.dart';
import '../../stories/services/story_service.dart';
import '../../stories/widgets/story_circle_button.dart';
import '../../stories/screens/story_viewer_screen.dart';
import '../../../config/theme/app_colors.dart';
import '../../../config/theme/app_text_styles.dart';
import '../../../core/app_localizations.dart';
import '../screens/flash_sale_screen.dart';
import '../../featured/screens/featured_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ══════════════════════════════════════════════════════
// openSidePanel — Overlay менен navbar үстүндө ачылат
// ══════════════════════════════════════════════════════
void openSidePanel(BuildContext context) {
  final overlay = Overlay.of(context);
  late OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => _SidePanelOverlay(
      onClose: () => entry.remove(),
    ),
  );
  overlay.insert(entry);
}

// ── Эски Drawer — бош ──
class AppEndDrawer extends StatelessWidget {
  const AppEndDrawer({super.key});
  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

// ══════════════════════════════════════════════════════
// МЕНЮ БАСКЫЧЫ — AppBar actions ичине коюлат
// Мандарин градиент, басканда openSidePanel чакырат
// ══════════════════════════════════════════════════════
class MenuOpenButton extends StatefulWidget {
  final VoidCallback onTap;
  const MenuOpenButton({super.key, required this.onTap});

  @override
  State<MenuOpenButton> createState() => _MenuOpenButtonState();
}

class _MenuOpenButtonState extends State<MenuOpenButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.88 : 1.0,
        duration: const Duration(milliseconds: 80),
        child: Container(
          margin: const EdgeInsets.only(right: 10),
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFD97706), Color(0xFFEF4444)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFD97706).withOpacity(0.4),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: const Icon(
            Icons.menu_rounded,
            color: Colors.white,
            size: 20,
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════
// OVERLAY — navbar үстүндө, жылмакай слайд, 90% кеңдик
// ══════════════════════════════════════════════════════
class _SidePanelOverlay extends StatefulWidget {
  final VoidCallback onClose;
  const _SidePanelOverlay({required this.onClose});

  @override
  State<_SidePanelOverlay> createState() => _SidePanelOverlayState();
}

class _SidePanelOverlayState extends State<_SidePanelOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  bool _isDragging = false;

  // Панелдин кеңдиги — экрандын 90%
  static const double _panelRatio = 0.90;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    )..addListener(() => setState(() {}));
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _close() async {
    await _ctrl.animateTo(
      0.0,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInCubic,
    );
    widget.onClose();
  }

  void _onDragUpdate(DragUpdateDetails details) {
    if (details.delta.dx > 0) {
      _isDragging = true;
      _ctrl.stop();
      final sw = MediaQuery.of(context).size.width * _panelRatio;
      final newVal = (_ctrl.value - details.delta.dx / sw).clamp(0.0, 1.0);
      _ctrl.value = newVal;
    }
  }

  void _onDragEnd(DragEndDetails details) {
    if (!_isDragging) return;
    _isDragging = false;
    final velocity = details.primaryVelocity ?? 0;
    if (_ctrl.value < 0.6 || velocity > 500) {
      _close();
    } else {
      _ctrl.animateTo(
        1.0,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    const navbarHeight = 64.0;
    final totalBottom = navbarHeight + bottomPadding;
    final sw = MediaQuery.of(context).size.width;
    final panelWidth = sw * _panelRatio;

    // Панел оң тараптан сыртта турат, _ctrl.value = 1 болгондо толук кирет
    final offsetX = panelWidth * (1.0 - _ctrl.value);

    return Stack(
      children: [
        // ── Кара фон (сол тарап) — басканда жабылат ──
        Positioned.fill(
          child: GestureDetector(
            onTap: _close,
            child: AnimatedOpacity(
              opacity: _ctrl.value * 0.45,
              duration: Duration.zero,
              child: const ColoredBox(color: Colors.black),
            ),
          ),
        ),

        // ── Панел — оң тараптан кирет, 90% кеңдик ──
        Positioned(
          top: 0,
          right: 0,
          bottom: totalBottom,
          width: panelWidth,
          child: Transform.translate(
            offset: Offset(offsetX, 0),
            child: GestureDetector(
              onHorizontalDragUpdate: _onDragUpdate,
              onHorizontalDragEnd: _onDragEnd,
              behavior: HitTestBehavior.opaque,
              child: _SidePanelScreen(onClose: _close),
            ),
          ),
        ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════
// ПАНЕЛ ЭКРАН
// ══════════════════════════════════════════════════════
class _SidePanelScreen extends StatefulWidget {
  final VoidCallback? onClose;
  const _SidePanelScreen({this.onClose});

  @override
  State<_SidePanelScreen> createState() => _SidePanelScreenState();
}

class _SidePanelScreenState extends State<_SidePanelScreen> {
  List<StoryModel> _stories = [];
  bool _loading = true;
  Set<String> _viewedIds = {};

  @override
  void initState() {
    super.initState();
    _loadStories();
  }

  Future<void> _loadStories() async {
    final prefs = await SharedPreferences.getInstance();
    final ids = prefs.getStringList('viewed_story_ids') ?? [];
    final list = await StoryService.instance.fetchActiveStories();
    if (mounted) {
      setState(() {
        _viewedIds = ids.toSet();
        _stories = list
            .map((s) => s.copyWith(isViewed: _viewedIds.contains(s.id)))
            .toList();
        _loading = false;
      });
    }
  }

  Future<void> _openStory(int index) async {
    final stories = List<StoryModel>.from(_stories);
    final nav = Navigator.of(context, rootNavigator: true);

    // Панелди жап
    widget.onClose?.call();
    await Future.delayed(const Duration(milliseconds: 350));

    // Navigator сакталган болгондуктан ачса болот
    await nav.push<void>(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => StoryViewerScreen(
          stories: stories,
          initialIndex: index,
        ),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
        transitionDuration: const Duration(milliseconds: 200),
      ),
    );
    if (!mounted) return;
    final prefs = await SharedPreferences.getInstance();
    final ids = prefs.getStringList('viewed_story_ids') ?? [];
    setState(() {
      _viewedIds = ids.toSet();
      _stories = _stories
          .map((s) => s.copyWith(isViewed: _viewedIds.contains(s.id)))
          .toList();
    });
  }

  void _goTo(Widget screen) {
    final nav = Navigator.of(context, rootNavigator: true);
    widget.onClose?.call();
    Future.delayed(const Duration(milliseconds: 320), () {
      nav.push(MaterialPageRoute(builder: (_) => screen));
    });
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
    final dividerColor =
        isDark ? const Color(0xFF2C2C2C) : const Color(0xFFEEEEEE);
    final footerColor = isDark ? AppColors.grey500 : AppColors.grey400;

    return Material(
      color: bgColor,
      child: DefaultTextStyle.merge(
        style: TextStyle(
          decoration: TextDecoration.none,
          color: textColor,
        ),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header ──
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
                child: Row(
                  children: [
                    ShaderMask(
                      shaderCallback: (bounds) => const LinearGradient(
                        colors: [Color(0xFFD97706), Color(0xFFEF4444)],
                      ).createShader(bounds),
                      child: Text(
                        'DD Online',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          decoration: TextDecoration.none,
                          color: textColor,
                        ),
                      ),
                    ),
                    const Spacer(),
                    // Жабуу баскычы
                    GestureDetector(
                      onTap: widget.onClose,
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.white.withOpacity(0.08)
                              : Colors.black.withOpacity(0.06),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.close_rounded,
                          size: 18,
                          color: textColor.withOpacity(0.7),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: dividerColor),
              const SizedBox(height: 16),

              // ── Мазмун ──
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Жаңылыктар ──
                      Padding(
                        padding: const EdgeInsets.only(left: 16, bottom: 10),
                        child: Text(
                          loc.get('drawer_stories_title'),
                          style: AppTextStyles.labelLarge.copyWith(
                            decoration: TextDecoration.none,
                            color: textColor,
                          ),
                        ),
                      ),
                      SizedBox(
                        height: 100,
                        child: _loading
                            ? const Center(
                                child: CircularProgressIndicator(
                                    color: AppColors.primary, strokeWidth: 2))
                            : _stories.isEmpty
                                ? Center(
                                    child: Text(
                                      loc.get('drawer_stories_empty'),
                                      style: TextStyle(
                                          color: footerColor, fontSize: 13),
                                    ),
                                  )
                                : ListView.builder(
                                    scrollDirection: Axis.horizontal,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12),
                                    itemCount: _stories.length,
                                    itemBuilder: (_, i) => Padding(
                                      padding: const EdgeInsets.only(right: 8),
                                      child: StoryCircleButton(
                                        story: _stories[i],
                                        onTap: () => _openStory(i),
                                      ),
                                    ),
                                  ),
                      ),
                      const SizedBox(height: 16),
                      Divider(height: 1, color: dividerColor),
                      const SizedBox(height: 16),

                      // ── 🎟 Акциялар ──
                      Padding(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 16),
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => _goTo(const PromotionScreen()),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [
                                  Color(0xFF6C47FF),
                                  Color(0xFF4A90D9)
                                ],
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                              ),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Row(
                              children: [
                                const Text('🎟',
                                    style: TextStyle(fontSize: 32)),
                                const SizedBox(width: 14),
                                Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(loc.get('drawer_promo_title'),
                                        style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w600,
                                            fontSize: 15,
                                            decoration:
                                                TextDecoration.none)),
                                    const SizedBox(height: 2),
                                    Text(
                                        loc.get('drawer_promo_subtitle'),
                                        style: const TextStyle(
                                            color: Colors.white70,
                                            fontSize: 12,
                                            decoration:
                                                TextDecoration.none)),
                                  ],
                                ),
                                const Spacer(),
                                const Icon(Icons.arrow_forward_ios_rounded,
                                    color: Colors.white, size: 20),
                              ],
                            ),
                          ),
                        ),
                      ),

                      // ── ⚡ Flash Sale ──
                      const SizedBox(height: 12),
                      Padding(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 16),
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => _goTo(const FlashSaleScreen()),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE05A1A),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Row(
                              children: [
                                const Text('⚡',
                                    style: TextStyle(fontSize: 32)),
                                const SizedBox(width: 14),
                                Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(loc.get('drawer_flash_title'),
                                        style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 15,
                                            decoration:
                                                TextDecoration.none)),
                                    const SizedBox(height: 2),
                                    Text(
                                        loc.get('drawer_flash_subtitle'),
                                        style: const TextStyle(
                                            color: Colors.white70,
                                            fontSize: 12,
                                            decoration:
                                                TextDecoration.none)),
                                  ],
                                ),
                                const Spacer(),
                                const Icon(Icons.arrow_forward_ios_rounded,
                                    color: Colors.white, size: 20),
                              ],
                            ),
                          ),
                        ),
                      ),

                      // ── ⭐ Өзгөчө товарлар ──
                      const SizedBox(height: 12),
                      Padding(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 16),
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => _goTo(const FeaturedScreen()),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [
                                  Color(0xFF1A7A4A),
                                  Color(0xFF2ECC71)
                                ],
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                              ),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Row(
                              children: [
                                const Text('⭐',
                                    style: TextStyle(fontSize: 32)),
                                const SizedBox(width: 14),
                                Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                        loc.get('drawer_featured_title'),
                                        style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 15,
                                            decoration:
                                                TextDecoration.none)),
                                    const SizedBox(height: 2),
                                    Text(
                                        loc.get(
                                            'drawer_featured_subtitle'),
                                        style: const TextStyle(
                                            color: Colors.white70,
                                            fontSize: 12,
                                            decoration:
                                                TextDecoration.none)),
                                  ],
                                ),
                                const Spacer(),
                                const Icon(Icons.arrow_forward_ios_rounded,
                                    color: Colors.white, size: 20),
                              ],
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),

              // ── Footer ──
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Text(
                  loc.get('drawer_footer'),
                  style: TextStyle(
                    fontSize: 12,
                    color: footerColor,
                    decoration: TextDecoration.none,
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