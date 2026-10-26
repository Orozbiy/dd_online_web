// lib/features/home/widgets/fav_badge.dart
// ── Избранный санагычы бар жүрөкчө иконасы (Figma стили) ──

import 'package:flutter/material.dart';
import '../../../config/theme/dd_design.dart';

class FavBadge extends StatelessWidget {
  final int count;
  final bool active;

  const FavBadge({super.key, required this.count, required this.active});

  @override
  Widget build(BuildContext context) {
    final p = DDPalette.of(context);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        // ── Жүрөкчө иконасы: активдүү болсо ак (кызгылт сары пилюля
        // фонунун үстүндө), болбосо палитранын субтексти ──
        Icon(
          active ? Icons.favorite_rounded : Icons.favorite_border_rounded,
          color: active ? Colors.white : p.subText,
          size: 23,
        ),

        // ── Badge — 0 болсо жашырылат ──
        if (count > 0)
          Positioned(
            top: -6,
            right: -8,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: active ? Colors.white : DD.accent,
                shape: BoxShape.circle,
                border: Border.all(
                  color: p.isDark ? const Color(0xFF15120F) : Colors.white,
                  width: 1.5,
                ),
              ),
              child: Text(
                count > 99 ? '99+' : '$count',
                style: TextStyle(
                  color: active ? DD.accent : Colors.white,
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