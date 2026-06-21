// lib/features/home/widgets/fav_badge.dart
// ── Избранный санагычы бар жүрөкчө иконасы ──

import 'package:flutter/material.dart';
import '../../../config/theme/app_colors.dart';

class FavBadge extends StatelessWidget {
  final int count;
  final bool active;

  const FavBadge({super.key, required this.count, required this.active});

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        // ── Жүрөкчө иконасы ──
        Icon(
          active ? Icons.favorite_rounded : Icons.favorite_border_rounded,
          color: active ? AppColors.primary : AppColors.grey400,
          size: 26,
        ),

        // ── Badge — 0 болсо жашырылат ──
        if (count > 0)
          Positioned(
            top: -5,
            right: -6,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: const BoxDecoration(
                color: AppColors.error,
                shape: BoxShape.circle,
              ),
              child: Text(
                count > 99 ? '99+' : '$count',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  height: 1.2,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }
}
