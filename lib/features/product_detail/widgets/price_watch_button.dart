// ═══════════════════════════════════════════════════════════════
// lib/features/product_detail/widgets/price_watch_button.dart
// ProductDetailScreen'дин баа бөлүмүнө кошулат
// ═══════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import '../../../config/theme/app_colors.dart';
import '../../../config/theme/app_text_styles.dart';
import '../../../core/supabase_client.dart';

class PriceWatchButton extends StatefulWidget {
  final String productId;
  final String productName;

  const PriceWatchButton({
    super.key,
    required this.productId,
    required this.productName,
  });

  @override
  State<PriceWatchButton> createState() => _PriceWatchButtonState();
}

class _PriceWatchButtonState extends State<PriceWatchButton>
    with SingleTickerProviderStateMixin {
  bool _isWatching = false;
  bool _loading    = true;
  late AnimationController _animCtrl;
  late Animation<double>   _scaleAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _scaleAnim = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut),
    );
    _checkWatchStatus();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  Future<void> _checkWatchStatus() async {
    final user = supabase.auth.currentUser;
    if (user == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    try {
      final row = await supabase
          .from('price_watch')
          .select('id')
          .eq('user_id', user.id)
          .eq('product_id', widget.productId)
          .maybeSingle();

      if (mounted) {
        setState(() {
          _isWatching = row != null;
          _loading    = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _toggle() async {
    final user = supabase.auth.currentUser;
    if (user == null) {
      // Кирүү суралат
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('🔔 Кабарлама алуу үчүн кирүү керек'),
          backgroundColor: AppColors.primary,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    // Анимация
    _animCtrl.forward().then((_) => _animCtrl.reverse());

    final wasWatching = _isWatching;
    setState(() => _isWatching = !_isWatching);

    try {
      if (wasWatching) {
        // Алып салуу
        await supabase
            .from('price_watch')
            .delete()
            .eq('user_id', user.id)
            .eq('product_id', widget.productId);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('🔕 Кабарлама өчүрүлдү'),
              backgroundColor: AppColors.grey500,
              duration: const Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );
        }
      } else {
        // Кошуу
        await supabase.from('price_watch').insert({
          'user_id':    user.id,
          'product_id': widget.productId,
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(children: [
                const Text('🔔 ', style: TextStyle(fontSize: 18)),
                Expanded(
                  child: Text(
                    'Баа түшсө кабарлайбыз!',
                    style: AppTextStyles.labelMedium.copyWith(color: Colors.white),
                  ),
                ),
              ]),
              backgroundColor: AppColors.primary,
              duration: const Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );
        }
      }
    } catch (e) {
      // Ката болсо — кайтарабыз
      if (mounted) setState(() => _isWatching = wasWatching);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_loading) {
      return const SizedBox(
        width: 40, height: 40,
        child: Center(
          child: SizedBox(
            width: 18, height: 18,
            child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
          ),
        ),
      );
    }

    return ScaleTransition(
      scale: _scaleAnim,
      child: GestureDetector(
        onTap: _toggle,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: _isWatching
                ? AppColors.primary.withValues(alpha: 0.12)
                : (isDark ? const Color(0xFF2C2C2C) : AppColors.grey100),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _isWatching
                  ? AppColors.primary.withValues(alpha: 0.5)
                  : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _isWatching ? Icons.notifications_active : Icons.notifications_none_outlined,
                color: _isWatching ? AppColors.primary : AppColors.grey500,
                size: 18,
              ),
              const SizedBox(width: 6),
              Text(
                _isWatching ? 'Кабар күтүүдө' : 'Баа түшсө кабарла',
                style: AppTextStyles.labelSmall.copyWith(
                  color: _isWatching ? AppColors.primary : AppColors.grey500,
                  fontWeight: _isWatching ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
