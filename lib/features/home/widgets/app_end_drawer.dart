import 'package:flutter/material.dart';
import '../../promotions/screens/promotion_screen.dart';
import '../../stories/models/story_model.dart';
import '../../stories/services/story_service.dart';
import '../../stories/widgets/story_circle_button.dart';
import '../../stories/screens/story_viewer_screen.dart';
import '../../../config/theme/app_colors.dart';
import '../../../config/theme/app_text_styles.dart';
import '../../../core/app_localizations.dart';

class AppEndDrawer extends StatefulWidget {
  const AppEndDrawer({super.key});

  @override
  State<AppEndDrawer> createState() => _AppEndDrawerState();
}

class _AppEndDrawerState extends State<AppEndDrawer> {
  List<StoryModel> _stories = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadStories();
  }

  Future<void> _loadStories() async {
    final list = await StoryService.instance.fetchActiveStories();
    if (mounted) {
      setState(() {
        _stories = list;
        _loading = false;
      });
    }
  }

  Future<void> _openStory(int index) async {
    // Drawer жабылат
    Navigator.of(context).pop();
    await Future.delayed(const Duration(milliseconds: 200));
    if (!mounted) return;

    final result = await Navigator.push<List<StoryModel>>(
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

    // Лайктар өзгөргөн болсо жаңыртуу
    if (result != null && mounted) {
      setState(() => _stories = result);
    }
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

            // ── Жаңылыктар (чыныгы Stories) ──
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
                  // Жүктөлүп жатканда — жука spinner
                  ? const Center(
                      child: SizedBox(
                        width: 24, height: 24,
                        child: CircularProgressIndicator(
                          color: AppColors.primary, strokeWidth: 2),
                      ),
                    )
                  : _stories.isEmpty
                      // Жаңылык жок болсо — бош жазуу
                      ? Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Text(
                            loc.get('story_empty'),
                            style: AppTextStyles.bodySmall
                                .copyWith(color: AppColors.grey400),
                          ),
                        )
                      // Чыныгы тегерек кнопкалар
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

            // ── Акциялар Card ──
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

            const Spacer(),

            // ── Footer ──
            Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                'Дордой Базары',
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
