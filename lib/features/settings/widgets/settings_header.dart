import 'package:flutter/material.dart';

/// "DD Online" эмблема + аты — Жөндөөлөр экранынын башы.
class SettingsHeader extends StatelessWidget {
  const SettingsHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFD97706), Color(0xFFEF4444)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(22),
              ),
              child: const Icon(
                Icons.storefront_rounded,
                color: Colors.white,
                size: 38,
              ),
            ),
            Positioned(
              bottom: -8,
              right: -8,
              child: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: const Color.fromARGB(255, 221, 142, 7),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: const Color(0xFFD97706),
                    width: 2,
                  ),
                ),
                child: const Icon(
                  Icons.navigation_rounded,
                  color: Color(0xFFD97706),
                  size: 13,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        const Text(
          'DD Online',
          style: TextStyle(
            color: Color.fromARGB(255, 239, 96, 12),
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
