import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import '../../../config/theme/app_colors.dart';
import '../../../config/theme/app_text_styles.dart';
import '../../../core/app_localizations.dart';

class CacheMenuItem extends StatefulWidget {
  const CacheMenuItem({super.key});

  @override
  State<CacheMenuItem> createState() => _CacheMenuItemState();
}

class _CacheMenuItemState extends State<CacheMenuItem> {
  static const String _appVersion = 'v1.0.0';
  bool _isClearing = false;

  Future<void> _onTap(BuildContext context) async {
    if (_isClearing) return;
    setState(() => _isClearing = true);
    final loc = AppLocalizations.of(context);
    try {
      await DefaultCacheManager().emptyCache();
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(loc.get('cache_cleared')),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(12))),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${loc.get('cache_error')}: $e'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(12))),
        ),
      );
    } finally {
      if (mounted) setState(() => _isClearing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    return InkWell(
      onTap: () => _onTap(context),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          children: [
            const Icon(Icons.cleaning_services_outlined,
                color: AppColors.primary, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(loc.get('cache'), style: AppTextStyles.bodyMedium),
            ),
            if (_isClearing)
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
              )
            else
              Text(_appVersion,
                  style: AppTextStyles.labelSmall.copyWith(color: AppColors.grey400)),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right, color: AppColors.grey300, size: 20),
          ],
        ),
      ),
    );
  }
}
