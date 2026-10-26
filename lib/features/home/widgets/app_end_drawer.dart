import 'package:flutter/material.dart';
import '../../promotions/screens/promotion_screen.dart';
import '../../stories/models/story_model.dart';
import '../../stories/services/story_service.dart';
import '../../stories/widgets/story_circle_button.dart';
import '../../stories/screens/story_viewer_screen.dart';
import '../../../config/theme/app_colors.dart';
import '../../../config/theme/app_text_styles.dart';
import '../../../config/theme/dd_design.dart';
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
            gradient: DD.accentGradient,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: DD.accent.withOpacity(0.4),
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
    // ignore: unused_local_variable
    final totalBottom = navbarHeight + bottomPadding;
    final sw = MediaQuery.of(context).size.width;
    final panelWidth = sw * _panelRatio;
    final offsetX = panelWidth * (1.0 - _ctrl.value);

    return Stack(
      children: [
        // ── Арткы кара фон — 30% азайтылган (0.45 → 0.15) ──
        Positioned.fill(
          child: GestureDetector(
            onTap: _close,
            child: AnimatedOpacity(
              opacity: _ctrl.value * 0.6,
              duration: Duration.zero,
              child: const ColoredBox(color: Colors.black),
            ),
          ),
        ),

        // ── Панел — оң тараптан кирет, 90% кеңдик, төмөнгө чейин ──
        Positioned(
          top: 0,
          right: 0,
          bottom: 0,
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
    widget.onClose?.call();
    await Future.delayed(const Duration(milliseconds: 350));
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
    final textColor = isDark ? Colors.white : DD.ink;
    final subColor = isDark ? Colors.white54 : DD.inkSoft.withOpacity(0.6);
    final dividerColor = isDark
        ? Colors.white.withOpacity(0.08)
        : const Color(0xFFEDEDF0);
    final footerColor = isDark ? Colors.white38 : AppColors.grey400;

    return ClipRRect(
      borderRadius: const BorderRadius.horizontal(left: Radius.circular(28)),
      child: Material(
        color: isDark ? DD.bgDark : DD.bgLight,
        child: Stack(
          children: [
            // ── Figma фон: кара/ак + кызгылт сары жарыктар ──
            Positioned.fill(child: _PanelGlow(isDark: isDark)),

            DefaultTextStyle.merge(
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
                      padding: const EdgeInsets.fromLTRB(20, 20, 16, 14),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              gradient: DD.accentGradient,
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: [
                                BoxShadow(
                                  color: DD.accent.withOpacity(0.4),
                                  blurRadius: 14,
                                  offset: const Offset(0, 5),
                                ),
                              ],
                            ),
                            child: const Icon(Icons.storefront_rounded,
                                color: Colors.white, size: 22),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'DD Online',
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -0.8,
                                    decoration: TextDecoration.none,
                                    color: textColor,
                                  ),
                                ),
                                Text(
                                  'Дордой базары',
                                  style: TextStyle(
                                    fontSize: 12,
                                    decoration: TextDecoration.none,
                                    color: subColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          GestureDetector(
                            onTap: widget.onClose,
                            child: Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: isDark
                                    ? Colors.white.withOpacity(0.08)
                                    : Colors.white,
                                shape: BoxShape.circle,
                                border: Border.all(color: dividerColor),
                              ),
                              child: Icon(
                                Icons.close_rounded,
                                size: 20,
                                color: textColor.withOpacity(0.8),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // ── Мазмун ──
                    Expanded(
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // ── Жаңылыктар (stories) ──
                            _SectionTitle(
                              text: loc.get('drawer_stories_title'),
                              color: textColor,
                            ),
                            SizedBox(
                              height: 100,
                              child: _loading
                                  ? const Center(
                                      child: CircularProgressIndicator(
                                          color: DD.accent, strokeWidth: 2))
                                  : _stories.isEmpty
                                      ? Center(
                                          child: Text(
                                            loc.get('drawer_stories_empty'),
                                            style: TextStyle(
                                                color: footerColor,
                                                fontSize: 13),
                                          ),
                                        )
                                      : ListView.builder(
                                          scrollDirection: Axis.horizontal,
                                          physics:
                                              const BouncingScrollPhysics(),
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 16),
                                          itemCount: _stories.length,
                                          itemBuilder: (_, i) => Padding(
                                            padding:
                                                const EdgeInsets.only(right: 10),
                                            child: StoryCircleButton(
                                              story: _stories[i],
                                              onTap: () => _openStory(i),
                                            ),
                                          ),
                                        ),
                            ),
                            const SizedBox(height: 22),

                            // ── Бөлүмдөр ──
                            _SectionTitle(text: 'Бөлүмдөр', color: textColor),

                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 16),
                              child: _MenuImageCard(
                                assetPath: 'assets/images/drawer/akcii.jpg',
                                overlayColor: DD.accent,
                                icon: Icons.local_offer_rounded,
                                title: loc.get('drawer_promo_title'),
                                subtitle: loc.get('drawer_promo_subtitle'),
                                isDark: isDark,
                                onTap: () => _goTo(const PromotionScreen()),
                              ),
                            ),
                            const SizedBox(height: 14),
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 16),
                              child: _MenuImageCard(
                                assetPath: 'assets/images/drawer/flash_sale.jpg',
                                overlayColor: DD.accent2,
                                icon: Icons.bolt_rounded,
                                title: loc.get('drawer_flash_title'),
                                subtitle: loc.get('drawer_flash_subtitle'),
                                isDark: isDark,
                                onTap: () => _goTo(FlashSaleScreen()),
                              ),
                            ),
                            const SizedBox(height: 14),
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 16),
                              child: _MenuImageCard(
                                assetPath: 'assets/images/drawer/special.jpg',
                                overlayColor: const Color(0xFF10B981),
                                icon: Icons.auto_awesome_rounded,
                                title: loc.get('drawer_featured_title'),
                                subtitle: loc.get('drawer_featured_subtitle'),
                                isDark: isDark,
                                onTap: () => _goTo(const FeaturedScreen()),
                              ),
                            ),

                            const SizedBox(height: 24),
                          ],
                        ),
                      ),
                    ),

                    // ── Footer ──
                    Divider(height: 1, color: dividerColor),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
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
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  final Color color;
  const _SectionTitle({required this.text, required this.color});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 16, 12),
        child: Row(
          children: [
            Container(
              width: 4,
              height: 16,
              decoration: BoxDecoration(
                gradient: DD.accentGradient,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              text,
              style: AppTextStyles.labelLarge.copyWith(
                decoration: TextDecoration.none,
                color: color,
                fontWeight: FontWeight.w800,
                fontSize: 16,
                letterSpacing: -0.3,
              ),
            ),
          ],
        ),
      );
}

// ── Фон: кызгылт сары жарык тактары (Figma "blur gradient") ──
class _PanelGlow extends StatelessWidget {
  final bool isDark;
  const _PanelGlow({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(painter: _PanelGlowPainter(isDark)),
    );
  }
}

class _PanelGlowPainter extends CustomPainter {
  final bool isDark;
  _PanelGlowPainter(this.isDark);

  void _blob(Canvas c, Offset o, double r, Color color) {
    c.drawCircle(
      o,
      r,
      Paint()
        ..shader = RadialGradient(
          colors: [color, color.withOpacity(0)],
        ).createShader(Rect.fromCircle(center: o, radius: r)),
    );
  }

  @override
  void paint(Canvas canvas, Size s) {
    if (isDark) {
      _blob(canvas, Offset(s.width * 0.15, s.height * 0.05), s.width * 0.9,
          DD.accent2.withOpacity(0.32));
      _blob(canvas, Offset(s.width * 0.95, s.height * 0.95), s.width * 0.95,
          DD.accent.withOpacity(0.26));
    } else {
      _blob(canvas, Offset(s.width * 0.25, s.height * 0.06), s.width * 0.7,
          DD.accent2.withOpacity(0.16));
      _blob(canvas, Offset(s.width * 0.95, s.height * 0.02), s.width * 0.5,
          DD.accent.withOpacity(0.12));
    }
  }

  @override
  bool shouldRepaint(_PanelGlowPainter o) => o.isDark != isDark;
}

// ══════════════════════════════════════════════════════
// МЕНЮ КАРТОЧКАСЫ — сүрөт фон + айнек + пилюля жебе
// ══════════════════════════════════════════════════════
class _MenuImageCard extends StatefulWidget {
  final String assetPath;
  final Color overlayColor;
  final IconData icon;
  final String title;
  final String subtitle;
  final bool isDark;
  final VoidCallback onTap;

  const _MenuImageCard({
    required this.assetPath,
    required this.overlayColor,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.isDark,
    required this.onTap,
  });

  @override
  State<_MenuImageCard> createState() => _MenuImageCardState();
}

class _MenuImageCardState extends State<_MenuImageCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final c = widget.overlayColor;
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      behavior: HitTestBehavior.opaque,
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: Container(
          height: 104,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(DD.rCard),
            boxShadow: [
              BoxShadow(
                color: c.withOpacity(widget.isDark ? 0.28 : 0.30),
                blurRadius: 20,
                offset: const Offset(0, 8),
                spreadRadius: -6,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(DD.rCard),
            child: Stack(
              fit: StackFit.expand,
              children: [
                // ── Фон сүрөт ──
                Image.asset(
                  widget.assetPath,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(color: c),
                ),
                // ── Кара → түстүү overlay ──
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.black.withOpacity(0.78),
                        c.withOpacity(0.55),
                      ],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                  ),
                ),
                // ── Ак чек (айнек) ──
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(DD.rCard),
                    border: Border.all(
                        color: Colors.white.withOpacity(0.22), width: 1),
                  ),
                ),
                // ── Контент ──
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.16),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                              color: Colors.white.withOpacity(0.35)),
                        ),
                        child:
                            Icon(widget.icon, color: Colors.white, size: 26),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(widget.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 16,
                                  letterSpacing: -0.3,
                                  decoration: TextDecoration.none,
                                )),
                            const SizedBox(height: 4),
                            Text(widget.subtitle,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                  height: 1.3,
                                  decoration: TextDecoration.none,
                                )),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Container(
                        width: 34,
                        height: 34,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.arrow_forward_rounded,
                            color: DD.accent, size: 20),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}