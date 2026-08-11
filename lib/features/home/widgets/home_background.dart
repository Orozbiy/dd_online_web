import 'package:flutter/material.dart';
import '../constants/home_colors.dart';

// ══════════════════════════════════════════════════════
// HomeBackground
// Мурда: home_screen.dart build() ичиндеги:
//   - Positioned.fill gradient фон
//   - Декоративдик тегеректер (dark × 3, light × 4)
// Эми: lib/features/home/widgets/home_background.dart
//
// Колдонуу (home_screen.dart Stack ичинде):
//
//   HomeBackground(isDark: isDark),
// ══════════════════════════════════════════════════════
class HomeBackground extends StatelessWidget {
  final bool isDark;

  const HomeBackground({super.key, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // ── Градиент фон ──
        Positioned.fill(
          child: isDark
              ? const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        HomeColors.bgGrad1,
                        HomeColors.bgGrad2,
                        HomeColors.bgGrad3,
                      ],
                      stops: [0.0, 0.5, 1.0],
                    ),
                  ),
                )
              : const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFFDCEBFF),
                        Color(0xFFEEE0FF),
                        Color(0xFFFFE0F0),
                        Color(0xFFFFEDD5),
                      ],
                      stops: [0.0, 0.35, 0.7, 1.0],
                    ),
                  ),
                ),
        ),

        // ── Декоративдик тегеректер — Dark mode ──
        if (isDark) ...[
          Positioned(
            top: -120,
            right: -80,
            child: _GlowCircle(
              size: 300,
              color: HomeColors.glow1.withOpacity(0.25),
            ),
          ),
          Positioned(
            top: 300,
            left: -100,
            child: _GlowCircle(
              size: 250,
              color: HomeColors.glow1.withOpacity(0.20),
            ),
          ),
          Positioned(
            bottom: 200,
            right: -60,
            child: _GlowCircle(
              size: 200,
              color: HomeColors.glow3.withOpacity(0.18),
            ),
          ),
        ],

        // ── Декоративдик тегеректер — Light mode ──
        if (!isDark) ...[
          Positioned(
            top: -120,
            left: -80,
            child: _GlowCircle(
              size: 350,
              color: const Color(0xFFADD0FF).withOpacity(0.45),
            ),
          ),
          Positioned(
            top: 80,
            right: -100,
            child: _GlowCircle(
              size: 280,
              color: const Color(0xFFCEB4FF).withOpacity(0.38),
            ),
          ),
          Positioned(
            top: 420,
            left: -60,
            child: _GlowCircle(
              size: 220,
              color: const Color(0xFFFFB3D9).withOpacity(0.32),
            ),
          ),
          Positioned(
            bottom: 250,
            right: -50,
            child: _GlowCircle(
              size: 200,
              color: const Color(0xFFFFD4A8).withOpacity(0.35),
            ),
          ),
        ],
      ],
    );
  }
}

// ── Жардамчы виджет: тегерек glow ──
class _GlowCircle extends StatelessWidget {
  final double size;
  final Color color;

  const _GlowCircle({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
      ),
    );
  }
}
