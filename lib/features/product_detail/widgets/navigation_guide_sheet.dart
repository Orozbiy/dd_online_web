// ══════════════════════════════════════════════════════
// 2ГИС НАВИГАЦИЯ BOTTOM SHEET
// product_detail_screen.dart файлынан бөлүнүп чыгарылды.
// ══════════════════════════════════════════════════════
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../config/theme/app_colors.dart';
import '../../../config/theme/app_text_styles.dart';
import '../../../core/app_localizations.dart';

class NavigationGuideSheet extends StatefulWidget {
  final String shopName;
  final String containerNumber;
  final double sellerLat;
  final double sellerLng;

  const NavigationGuideSheet({
    super.key,
    required this.shopName,
    required this.containerNumber,
    required this.sellerLat,
    required this.sellerLng,
  });

  @override
  State<NavigationGuideSheet> createState() => _NavigationGuideSheetState();
}

class _NavigationGuideSheetState extends State<NavigationGuideSheet> {
  Future<void> _open2GIS() async {
    final loc = AppLocalizations.of(context);
    final appUri = Uri.parse(
        'dgis://2gis.ru/routeSearch/rsType/pedestrian/to/${widget.sellerLng},${widget.sellerLat}');
    final playStoreUri = Uri.parse(
        'https://play.google.com/store/apps/details?id=ru.dublgis.dgismobile');
    final appStoreUri = Uri.parse('https://apps.apple.com/app/id481627348');

    if (await canLaunchUrl(appUri)) {
      await launchUrl(appUri);
    } else {
      if (!mounted) return;
      final isIOS = Theme.of(context).platform == TargetPlatform.iOS;
      final storeUri = isIOS ? appStoreUri : playStoreUri;
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(loc.get('2gis_not_installed')),
          content: Text(loc.get('2gis_download_hint')),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(loc.get('no'))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                elevation: 0,
              ),
              onPressed: () async {
                Navigator.pop(ctx);
                if (await canLaunchUrl(storeUri)) {
                  await launchUrl(storeUri,
                      mode: LaunchMode.externalApplication);
                }
              },
              child: Text(loc.get('download'),
                  style: const TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sheetBg = isDark ? const Color(0xFF122A4D) : const Color(0xFFEFF5FF);
    final stepBg = isDark ? const Color(0xFF1B3A66) : Colors.white;
    final stepBorder = isDark
        ? Colors.white.withValues(alpha: 0.10)
        : const Color(0xFFBFDBFE);
    final handleColor =
        isDark ? Colors.white.withValues(alpha: 0.24) : const Color(0xFF93C5FD);

    return Container(
      decoration: BoxDecoration(
        color: sheetBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.black.withValues(alpha: 0.05),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: handleColor,
                    borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 20),
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle),
              child: const Icon(Icons.navigation_rounded,
                  color: AppColors.primary, size: 32),
            ),
            const SizedBox(height: 16),
            Text(widget.shopName.isNotEmpty ? widget.shopName : loc.get('shop'),
                style: AppTextStyles.headingSmall, textAlign: TextAlign.center),
            if (widget.containerNumber.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text('📍 ${widget.containerNumber}',
                  style: AppTextStyles.labelSmall
                      .copyWith(color: AppColors.primary)),
            ],
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                  color: stepBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: stepBorder)),
              child: Column(children: [
                _step('1', loc.get('nav_step1')),
                const SizedBox(height: 10),
                _step('2', loc.get('nav_step2')),
                const SizedBox(height: 10),
                _step('3', loc.get('nav_step3')),
              ]),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _open2GIS,
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    elevation: 0),
                icon: const Icon(Icons.map_rounded, color: Colors.white),
                label: Text(loc.get('open_2gis'),
                    style: AppTextStyles.headingSmall
                        .copyWith(color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _step(String num, String text) {
    return Row(children: [
      Container(
          width: 24,
          height: 24,
          decoration: const BoxDecoration(
              color: AppColors.primary, shape: BoxShape.circle),
          alignment: Alignment.center,
          child: Text(num,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold))),
      const SizedBox(width: 12),
      Expanded(child: Text(text, style: AppTextStyles.bodyMedium)),
    ]);
  }
}