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
import '../../featured/roulette/screens/roulette_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppEndDrawer extends StatefulWidget {
  const AppEndDrawer({super.key});

  @override
  State<AppEndDrawer> createState() => _AppEndDrawerState();
}

class _AppEndDrawerState extends State<AppEndDrawer> {
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
    Navigator.of(context).pop();
    await Future.delayed(const Duration(milliseconds: 200));
    if (!mounted) return;

    await Navigator.push<List<StoryModel>>(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => StoryViewerScreen(
          stories:      _stories,
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

  @override
  Widget build(BuildContext context) {
    final loc          = AppLocalizations.of(context);
    final isDark       = Theme.of(context).brightness == Brightness.dark;
    final bgColor      = isDark ? const Color(0xFF1E1E1E) : AppColors.white;
    final dividerColor = isDark ? const Color(0xFF2C2C2C) : const Color(0xFFEEEEEE);

    return Drawer(
      width: MediaQuery.of(context).size.width * 0.90,
      backgroundColor: bgColor,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 20, 16, 12),
              child: Text('DD Online', style: AppTextStyles.headingLarge),
            ),
            Divider(height: 1, color: dividerColor),
            const SizedBox(height: 16),

            // ── Жаңылыктар (Stories) ──
            Padding(
              padding: const EdgeInsets.only(left: 16, bottom: 10),
              child: Text(
                loc.get('drawer_stories_title'),
                style: AppTextStyles.labelLarge,
              ),
            ),

            SizedBox(
              height: 100,
              child: _loading
                  ? const Center(
                      child: SizedBox(
                        width: 24, height: 24,
                        child: CircularProgressIndicator(
                            color: AppColors.primary, strokeWidth: 2),
                      ),
                    )
                  : _stories.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Text(
                            loc.get('story_empty'),
                            style: AppTextStyles.bodySmall
                                .copyWith(color: AppColors.grey400),
                          ),
                        )
                      : ListView.separated(
                          scrollDirection: Axis.horizontal,
                          physics: const BouncingScrollPhysics(),
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _stories.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(width: 12),
                          itemBuilder: (_, i) => StoryCircleButton(
                            story: _stories[i],
                            onTap: () => _openStory(i),
                          ),
                        ),
            ),

            const SizedBox(height: 16),
            Divider(height: 1, color: dividerColor),
            const SizedBox(height: 20),

            // ── 🎁 Акциялар Card ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: GestureDetector(
                onTap: () async {
                  Navigator.of(context).pop();
                  await Future.delayed(const Duration(milliseconds: 150));
                  if (context.mounted) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const PromotionScreen()),
                    );
                  }
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFD97706), Color(0xFFF59E0B)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 4))
                    ],
                  ),
                  child: Row(
                    children: [
                      const Text('🎁', style: TextStyle(fontSize: 32)),
                      const SizedBox(width: 14),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(loc.get('drawer_promo_title'),
                              style: AppTextStyles.headingSmall
                                  .copyWith(color: Colors.white)),
                          const SizedBox(height: 2),
                          Text(loc.get('drawer_promo_subtitle'),
                              style: AppTextStyles.bodySmall
                                  .copyWith(color: Colors.white70)),
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

            // ── ⚡ Flash Sale Card ──
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: GestureDetector(
                onTap: () async {
                  Navigator.of(context).pop();
                  await Future.delayed(const Duration(milliseconds: 150));
                  if (context.mounted) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const FlashSaleScreen()),
                    );
                  }
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFDC2626), Color(0xFFEF4444)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.red.withValues(alpha: 0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 4))
                    ],
                  ),
                  child: Row(
                    children: [
                      const Text('⚡', style: TextStyle(fontSize: 32)),
                      const SizedBox(width: 14),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            loc.get('drawer_flash_title'),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            loc.get('drawer_flash_subtitle'),
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
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

            // ── ⭐ Өзгөчө товарлар Card ──
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: GestureDetector(
                onTap: () async {
                  Navigator.of(context).pop();
                  await Future.delayed(const Duration(milliseconds: 150));
                  if (context.mounted) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const FeaturedScreen()),
                    );
                  }
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF7C3AED), Color(0xFF9F67FA)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                          color: const Color(0xFF7C3AED).withValues(alpha: 0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 4))
                    ],
                  ),
                  child: Row(
                    children: [
                      const Text('⭐', style: TextStyle(fontSize: 32)),
                      const SizedBox(width: 14),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            loc.get('drawer_featured_title'),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            loc.get('drawer_featured_subtitle'),
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
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

            // ── 🎰 Күнүмдүк Рулетка Card ──
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: GestureDetector(
                onTap: () async {
                  Navigator.of(context).pop();
                  await Future.delayed(const Duration(milliseconds: 150));
                  if (context.mounted) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const RouletteScreen()),
                    );
                  }
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF0EA5E9), Color(0xFF38BDF8)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                          color: const Color(0xFF0EA5E9).withValues(alpha: 0.35),
                          blurRadius: 12,
                          offset: const Offset(0, 4))
                    ],
                  ),
                  child: Row(
                    children: [
                      const Text('🎰', style: TextStyle(fontSize: 32)),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              loc.get('drawer_roulette_title'),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              loc.get('drawer_roulette_subtitle'),
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // ── "ЖАҢЫ" badge ──
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          'ЖАҢЫ',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.arrow_forward_ios_rounded,
                          color: Colors.white, size: 20),
                    ],
                  ),
                ),
              ),
            ),

            const Spacer(),

            // ── Footer ──
            Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                loc.get('drawer_footer'),
                style: AppTextStyles.labelSmall.copyWith(
                  color: isDark ? AppColors.grey500 : null,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}