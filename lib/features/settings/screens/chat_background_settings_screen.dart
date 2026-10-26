import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../config/theme/app_colors.dart';
import '../../../config/theme/app_text_styles.dart';
import '../../../core/app_localizations.dart';
import '../../../core/chat_background_provider.dart';

class ChatBackgroundSettingsScreen extends StatefulWidget {
  final ChatBackgroundProvider provider;
  const ChatBackgroundSettingsScreen({super.key, required this.provider});

  @override
  State<ChatBackgroundSettingsScreen> createState() =>
      _ChatBackgroundSettingsScreenState();
}

class _ChatBackgroundSettingsScreenState
    extends State<ChatBackgroundSettingsScreen> {
  late ChatBgTheme _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.provider.theme;
  }

  @override
  Widget build(BuildContext context) {
    final isDark    = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : AppColors.black;
    final loc       = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF4F5F7),
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              color: isDark
                  ? Colors.black.withValues(alpha: 0.30)
                  : Colors.white.withValues(alpha: 0.40),
            ),
          ),
        ),
        foregroundColor: textColor,
        title: Text(
          loc.get('bg_screen_title'),
          style: AppTextStyles.headingSmall.copyWith(color: textColor),
        ),
      ),
      body: Column(
        children: [
          // ── Чоң превью ──
          SizedBox(
            height: 220,
            width: double.infinity,
            child: Stack(
              children: [
                Positioned.fill(child: _selected.buildBackground(isDark)),
                // Үлгү билдирүүлөр
                Positioned(
                  bottom: 16,
                  left: 16,
                  right: 16,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: ClipRRect(
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(14),
                            topRight: Radius.circular(14),
                            bottomRight: Radius.circular(14),
                            bottomLeft: Radius.circular(4),
                          ),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? Colors.white.withValues(alpha: 0.12)
                                    : Colors.white.withValues(alpha: 0.65),
                                border: Border.all(
                                  color: isDark
                                      ? Colors.white.withValues(alpha: 0.15)
                                      : Colors.white.withValues(alpha: 0.80),
                                ),
                                borderRadius: const BorderRadius.only(
                                  topLeft: Radius.circular(14),
                                  topRight: Radius.circular(14),
                                  bottomRight: Radius.circular(14),
                                  bottomLeft: Radius.circular(4),
                                ),
                              ),
                              child: Text(
                                loc.get('bg_msg_hello'),
                                style: TextStyle(
                                  fontSize: 13,
                                  color: isDark ? Colors.white : Colors.black87,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(14),
                              topRight: Radius.circular(14),
                              bottomLeft: Radius.circular(14),
                              bottomRight: Radius.circular(4),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primary.withValues(alpha: 0.35),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Text(
                            loc.get('bg_msg_thanks'),
                            style: const TextStyle(fontSize: 13, color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // ── Тема тизмеси ──
          Expanded(
            child: ListView(
              padding: EdgeInsets.fromLTRB(
                16,
                8,
                16,
                MediaQuery.of(context).padding.bottom + 16,
              ),
              children: ChatBgTheme.values.map((t) {
                final isActive = t == _selected;
                return GestureDetector(
                  onTap: () async {
                    setState(() => _selected = t);
                    await widget.provider.setTheme(t);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.only(bottom: 10),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                        child: Container(
                          decoration: BoxDecoration(
                            color: isActive
                                ? AppColors.primary.withValues(alpha: isDark ? 0.18 : 0.10)
                                : (isDark
                                    ? Colors.white.withValues(alpha: 0.06)
                                    : Colors.white.withValues(alpha: 0.55)),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isActive
                                  ? AppColors.primary.withValues(alpha: 0.70)
                                  : (isDark
                                      ? Colors.white.withValues(alpha: 0.10)
                                      : Colors.white.withValues(alpha: 0.80)),
                              width: isActive ? 1.5 : 1.0,
                            ),
                          ),
                          child: Row(
                            children: [
                              // Мини превью
                              ClipRRect(
                                borderRadius: const BorderRadius.only(
                                  topLeft: Radius.circular(15),
                                  bottomLeft: Radius.circular(15),
                                ),
                                child: SizedBox(
                                  width: 72,
                                  height: 72,
                                  child: t.buildBackground(isDark),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Text(
                                  t.localizedLabel(context),
                                  style: AppTextStyles.bodyLarge.copyWith(
                                    color: isActive
                                        ? (isDark ? Colors.white : AppColors.primary)
                                        : textColor,
                                    fontWeight: isActive
                                        ? FontWeight.w600
                                        : FontWeight.normal,
                                  ),
                                ),
                              ),
                              // Белги
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                margin: const EdgeInsets.only(right: 14),
                                width: 24,
                                height: 24,
                                decoration: BoxDecoration(
                                  color: isActive
                                      ? AppColors.primary
                                      : Colors.transparent,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: isActive
                                        ? AppColors.primary
                                        : (isDark
                                            ? Colors.white.withValues(alpha: 0.25)
                                            : AppColors.grey300),
                                    width: 1.5,
                                  ),
                                ),
                                child: isActive
                                    ? const Icon(Icons.check,
                                        color: Colors.white, size: 14)
                                    : null,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}