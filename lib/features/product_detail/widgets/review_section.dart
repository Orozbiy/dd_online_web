import 'package:flutter/material.dart';
import '../../../config/theme/app_colors.dart';

import '../../../core/app_localizations.dart';
import '../../../core/utils/review_manager.dart';
import '../../../core/supabase_client.dart';

class ReviewSection extends StatefulWidget {
  final String productId;
  const ReviewSection({super.key, required this.productId});

  @override
  State<ReviewSection> createState() => _ReviewSectionState();
}

class _ReviewSectionState extends State<ReviewSection> {
  final _manager = ReviewManager.instance;
  int  _myRating  = 0;
  bool _isLoading = true;
  bool _isSaving  = false;
  Map<String, dynamic>? _localOverride;

  @override
  void initState() {
    super.initState();
    _loadMyRating();
  }

  Future<void> _loadMyRating() async {
    final r = await _manager.getUserRating(widget.productId);
    if (mounted) {
      setState(() { _myRating = r ?? 0; _isLoading = false; });
    }
  }

  Future<void> _onStarTap(int star) async {
    final loc  = AppLocalizations.of(context);
    final user = supabase.auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(loc.get('review_login_required')),
        backgroundColor: AppColors.warning,
      ));
      return;
    }
    setState(() { _myRating = star; _isSaving = true; });
    await _manager.submitRating(productId: widget.productId, rating: star);
    if (mounted) {
      final fresh = await _manager.fetchRatingData(widget.productId);
      setState(() { _isSaving = false; _localOverride = fresh; });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(_starLabel(loc, star)),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
    }
  }

  String _starLabel(AppLocalizations loc, int star) {
    switch (star) {
      case 1: return loc.get('star_1');
      case 2: return loc.get('star_2');
      case 3: return loc.get('star_3');
      case 4: return loc.get('star_4');
      case 5: return loc.get('star_5');
      default: return loc.get('review_submitted');
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc    = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final cardBg      = isDark ? const Color(0xFF1C1C2E) : Colors.white;
    final borderColor = isDark ? const Color(0xFF2E2E45) : const Color(0xFFF0F0F0);
    final subColor    = isDark ? const Color(0xFF8888AA) : const Color(0xFFAAAAAA);
    final emptyColor  = isDark ? const Color(0xFF444466) : const Color(0xFFDDDDDD);
    final labelColor  = isDark ? Colors.white : const Color(0xFF1A1A2E);

    return StreamBuilder<Map<String, dynamic>>(
      stream: _manager.getRatingStream(widget.productId),
      builder: (context, snapshot) {
        final data  = _localOverride ?? snapshot.data ?? {'avg': 0.0, 'count': 0};
        final avg   = (data['avg'] as double?) ?? 0.0;
        final count = (data['count'] as int?) ?? 0;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: borderColor),
            boxShadow: isDark ? [] : [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 12, offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              // ── Жогорку сап: рейтинг + жылдыздар + саны ──
              Row(
                children: [
                  // Чоң сан
                  Column(
                    children: [
                      if (avg > 0) ...[
                        Text(
                          avg.toStringAsFixed(1),
                          style: TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.w900,
                            color: Colors.amber,
                            height: 1,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$count ${loc.get('review_count')}',
                          style: TextStyle(fontSize: 11, color: subColor),
                        ),
                      ] else ...[
                        Icon(Icons.star_outline_rounded,
                            size: 36, color: subColor),
                        const SizedBox(height: 4),
                        Text(
                          loc.get('review_no_ratings'),
                          style: TextStyle(fontSize: 11, color: subColor),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(width: 16),
                  // Вертикал сызык
                  Container(width: 1, height: 44, color: borderColor),
                  const SizedBox(width: 16),
                  // Жылдыздар + "Баа бер" текст
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Орточо рейтинг жылдыздары (кичи)
                        Row(
                          children: List.generate(5, (i) => Icon(
                            (i + 1) <= avg.round()
                                ? Icons.star_rounded
                                : Icons.star_outline_rounded,
                            color: Colors.amber,
                            size: 16,
                          )),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          loc.get('your_rating'),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: labelColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 14),

              // ── Колдонуучунун жылдыздары ──
              if (_isLoading)
                const SizedBox(
                  height: 36,
                  child: Center(child: CircularProgressIndicator(
                    color: AppColors.primary, strokeWidth: 2,
                  )),
                )
              else
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(5, (i) {
                    final star   = i + 1;
                    final filled = star <= _myRating;
                    return GestureDetector(
                      onTap: _isSaving ? null : () => _onStarTap(star),
                      child: AnimatedScale(
                        scale: filled ? 1.15 : 1.0,
                        duration: const Duration(milliseconds: 180),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 5),
                          child: Icon(
                            filled ? Icons.star_rounded : Icons.star_outline_rounded,
                            color: filled ? Colors.amber : emptyColor,
                            size: 34,
                          ),
                        ),
                      ),
                    );
                  }),
                ),

              // ── Тандалган баанын аты ──
              AnimatedSize(
                duration: const Duration(milliseconds: 200),
                child: _myRating > 0
                    ? Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                          decoration: BoxDecoration(
                            color: Colors.amber.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            _starLabel(loc, _myRating),
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.amber,
                            ),
                          ),
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        );
      },
    );
  }
}