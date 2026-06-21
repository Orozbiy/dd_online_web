import 'package:flutter/material.dart';
import '../../../config/theme/app_colors.dart';
import '../../../config/theme/app_text_styles.dart';
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

  @override
  void initState() {
    super.initState();
    _loadMyRating();
  }

  Future<void> _loadMyRating() async {
    final r = await _manager.getUserRating(widget.productId);
    if (mounted) {
      setState(() {
        _myRating  = r ?? 0;
        _isLoading = false;
      });
    }
  }

  Future<void> _onStarTap(int star) async {
    final loc  = AppLocalizations.of(context);
    final user = supabase.auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(loc.get('review_login_required')),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    setState(() { _myRating = star; _isSaving = true; });
    await _manager.submitRating(productId: widget.productId, rating: star);

    if (mounted) {
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_starLabel(loc, star)),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
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
    final bgColor     = isDark ? const Color(0xFF2D2040) : Colors.white;
    final borderColor = isDark ? const Color(0xFF3D3060) : AppColors.grey100;
    final dividerColor = isDark ? const Color(0xFF3D3060) : AppColors.grey100;
    final textColor   = isDark ? Colors.white : AppColors.black;
    final subTextColor = isDark ? AppColors.grey400 : AppColors.grey500;
    final emptyStarColor = isDark ? AppColors.grey600 : AppColors.grey300;

    return StreamBuilder<Map<String, dynamic>>(
      stream: _manager.getRatingStream(widget.productId),
      builder: (context, snapshot) {
        final data  = snapshot.data ?? {'avg': 0.0, 'count': 0};
        final avg   = (data['avg'] as double?) ?? 0.0;
        final count = (data['count'] as int?) ?? 0;

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Жалпы рейтинг ──
              Row(
                children: [
                  Text(
                    avg > 0 ? avg.toStringAsFixed(1) : '—',
                    style: const TextStyle(
                      fontSize: 48, fontWeight: FontWeight.w900,
                      color: Colors.amber, height: 1,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: List.generate(5, (i) {
                          final filled = (i + 1) <= avg.round();
                          return Icon(
                            filled ? Icons.star_rounded : Icons.star_outline_rounded,
                            color: Colors.amber, size: 20,
                          );
                        }),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        count > 0
                            ? '$count ${loc.get('review_count')}'
                            : loc.get('review_no_ratings'),
                        style: AppTextStyles.bodySmall.copyWith(color: subTextColor),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 20),
              Divider(height: 1, color: dividerColor),
              const SizedBox(height: 20),

              // ── Колдонуучунун баасы ──
              Text(loc.get('your_rating'),
                  style: AppTextStyles.headingSmall.copyWith(color: textColor)),
              const SizedBox(height: 12),

              if (_isLoading)
                const Center(child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2))
              else
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(5, (i) {
                    final star   = i + 1;
                    final filled = star <= _myRating;
                    return GestureDetector(
                      onTap: _isSaving ? null : () => _onStarTap(star),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                        child: Icon(
                          filled ? Icons.star_rounded : Icons.star_outline_rounded,
                          color: filled ? Colors.amber : emptyStarColor,
                          size: 40,
                        ),
                      ),
                    );
                  }),
                ),

              if (_myRating > 0) ...[
                const SizedBox(height: 8),
                Center(
                  child: Text(
                    _starLabel(loc, _myRating),
                    style: AppTextStyles.labelMedium.copyWith(color: Colors.amber),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}