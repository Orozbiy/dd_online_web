import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../../config/theme/app_colors.dart';
import '../../../config/theme/app_text_styles.dart';
import '../../../config/theme/dd_design.dart';
import '../../../core/app_localizations.dart';
import '../../../core/supabase_client.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<Map<String, dynamic>> _notifications = [];
  Set<String> _readIds = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final data = await supabase
          .from('admin_notifications')
          .select()
          .isFilter('seller_id', null)
          .order('created_at', ascending: false);

      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getStringList('read_notification_ids') ?? [];
      final loaded = List<Map<String, dynamic>>.from(data);
      if (mounted) {
        setState(() {
          _notifications = loaded;
          _readIds = saved.toSet();
        });
      }
      await _markAllReadInSupabase(loaded);
    } catch (_) {} finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _markAllReadInSupabase(
      List<Map<String, dynamic>> notifications) async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null || notifications.isEmpty) return;
    try {
      final existing = await supabase
          .from('notification_reads')
          .select('notification_id')
          .eq('user_id', userId);
      final existingIds = (existing as List)
          .map((r) => r['notification_id'] as String)
          .toSet();

      final toInsert = notifications
          .map((n) => n['id'] as String)
          .where((id) => !existingIds.contains(id))
          .map((id) => {'notification_id': id, 'user_id': userId})
          .toList();

      if (toInsert.isNotEmpty) {
        await supabase.from('notification_reads').insert(toInsert);
      }

      final prefs = await SharedPreferences.getInstance();
      final allIds = notifications.map((n) => n['id'] as String).toList();
      await prefs.setStringList('read_notification_ids', allIds);
      if (mounted) setState(() => _readIds = allIds.toSet());
    } catch (_) {}
  }

  Future<void> _markRead(String id) async {
    if (_readIds.contains(id)) return;
    setState(() => _readIds.add(id));
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('read_notification_ids', _readIds.toList());
    final userId = supabase.auth.currentUser?.id;
    if (userId != null) {
      try {
        await supabase.from('notification_reads').upsert({
          'notification_id': id,
          'user_id': userId,
        });
      } catch (_) {}
    }
  }

  String _timeAgo(String? createdAt, bool isKy) {
    if (createdAt == null) return '';
    final dt = DateTime.tryParse(createdAt)?.toLocal();
    if (dt == null) return '';
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return isKy ? 'Азыр' : 'Сейчас';
    if (diff.inHours < 1) {
      return isKy
          ? '${diff.inMinutes} мүн. мурун'
          : '${diff.inMinutes} мин. назад';
    }
    if (diff.inDays < 1) {
      return isKy
          ? '${diff.inHours} саат мурун'
          : '${diff.inHours} ч. назад';
    }
    if (diff.inDays < 30) {
      return isKy ? '${diff.inDays} күн мурун' : '${diff.inDays} д. назад';
    }
    return '${dt.day}.${dt.month}.${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final isKy = loc.locale.languageCode == 'ky';
    final p = DDPalette.of(context);
    final textColor = p.isDark ? Colors.white : AppColors.black;
    final subColor = p.subText;

    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          // ── Фигма-стилиндеги фон (ар бир режимде өзүнчө) ──
          const Positioned.fill(child: DDBackground(child: SizedBox.expand())),

          // ── Негизги мазмун ──
          _isLoading
              ? const Center(
                  child: CircularProgressIndicator(color: DD.accent))
              : _notifications.isEmpty
                  ? _EmptyState(isKy: isKy, palette: p, subColor: subColor)
                  : RefreshIndicator(
                      onRefresh: _load,
                      color: DD.accent,
                      backgroundColor: p.isDark ? DD.ink : Colors.white,
                      child: ListView.separated(
                        padding: EdgeInsets.fromLTRB(
                          16,
                          MediaQuery.of(context).padding.top +
                              kToolbarHeight +
                              16,
                          16,
                          32,
                        ),
                        itemCount: _notifications.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: 12),
                        itemBuilder: (context, i) {
                          final n = _notifications[i];
                          final id = n['id'] as String;
                          final title = n['title'] as String? ?? '';
                          final body = n['body'] as String? ?? '';
                          final imageUrl = n['image_url'] as String?;
                          final isRead = _readIds.contains(id);
                          return _NotificationCard(
                            title: title,
                            body: body,
                            imageUrl: imageUrl,
                            timeText:
                                _timeAgo(n['created_at'] as String?, isKy),
                            isRead: isRead,
                            palette: p,
                            textColor: textColor,
                            subColor: subColor,
                            onTap: () => _markRead(id),
                          );
                        },
                      ),
                    ),

          // ── Үстүңкү айнек AppBar ──
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: _GlassAppBar(
              isKy: isKy,
              palette: p,
              textColor: textColor,
              onBack: () => Navigator.pop(context),
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════
// Айнек AppBar (DD стили)
// ══════════════════════════════════════════════════════════════════
class _GlassAppBar extends StatelessWidget {
  final bool isKy;
  final DDPalette palette;
  final Color textColor;
  final VoidCallback onBack;

  const _GlassAppBar({
    required this.isKy,
    required this.palette,
    required this.textColor,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
        child: Container(
          padding: EdgeInsets.only(top: topPad),
          decoration: BoxDecoration(
            color: palette.isDark
                ? const Color(0xFF15120F).withValues(alpha: 0.60)
                : Colors.white.withValues(alpha: 0.70),
            border: Border(
              bottom: BorderSide(
                color: palette.isDark
                    ? DD.accent2.withValues(alpha: 0.18)
                    : Colors.white,
                width: 1.0,
              ),
            ),
          ),
          child: SizedBox(
            height: kToolbarHeight,
            child: Row(
              children: [
                const SizedBox(width: 8),
                // Артка
                _CircleBtn(
                  icon: Icons.arrow_back_rounded,
                  onTap: onBack,
                  palette: palette,
                ),
                const SizedBox(width: 8),
                // Иконка + аталышы
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    gradient: DD.accentGradient,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: DD.accent.withValues(alpha: 0.35),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                        spreadRadius: -3,
                      ),
                    ],
                  ),
                  child: const Icon(Icons.notifications_rounded,
                      color: Colors.white, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    isKy ? 'Билдирүүлөр' : 'Уведомления',
                    style: AppTextStyles.headingSmall.copyWith(
                      color: textColor,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════
// Айлана баскыч (артка)
// ══════════════════════════════════════════════════════════════════
class _CircleBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final DDPalette palette;

  const _CircleBtn({
    required this.icon,
    required this.onTap,
    required this.palette,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: palette.isDark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.black.withValues(alpha: 0.05),
          shape: BoxShape.circle,
          border: Border.all(
            color: palette.isDark
                ? Colors.white.withValues(alpha: 0.10)
                : Colors.black.withValues(alpha: 0.06),
          ),
        ),
        child: Icon(icon, color: palette.text, size: 20),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════
// Бош абал
// ══════════════════════════════════════════════════════════════════
class _EmptyState extends StatelessWidget {
  final bool isKy;
  final DDPalette palette;
  final Color subColor;

  const _EmptyState({
    required this.isKy,
    required this.palette,
    required this.subColor,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              gradient: DD.accentGradient,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: DD.accent.withValues(alpha: 0.30),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                  spreadRadius: -8,
                ),
              ],
            ),
            child: const Icon(Icons.notifications_none_rounded,
                size: 44, color: Colors.white),
          ),
          const SizedBox(height: 20),
          Text(
            isKy ? 'Билдирүүлөр жок' : 'Нет уведомлений',
            style: AppTextStyles.labelLarge.copyWith(
              color: palette.text,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            isKy
                ? 'Жаңы билдирүү келгенде бул жерде көрүнөт'
                : 'Новые уведомления появятся здесь',
            style: AppTextStyles.bodySmall.copyWith(color: subColor),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════
// Билдирүү карточкасы (Figma стили, 2 режим)
// ══════════════════════════════════════════════════════════════════
class _NotificationCard extends StatelessWidget {
  final String title;
  final String body;
  final String? imageUrl;
  final String timeText;
  final bool isRead;
  final DDPalette palette;
  final Color textColor;
  final Color subColor;
  final VoidCallback onTap;

  const _NotificationCard({
    required this.title,
    required this.body,
    required this.imageUrl,
    required this.timeText,
    required this.isRead,
    required this.palette,
    required this.textColor,
    required this.subColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = palette.isDark;

    // ── Фон ──
    final Color cardBg = isRead
        ? (isDark
            ? Colors.white.withValues(alpha: 0.05)
            : Colors.white.withValues(alpha: 0.80))
        : (isDark
            ? DD.accent.withValues(alpha: 0.12)
            : DD.accent.withValues(alpha: 0.08));

    final Color borderColor = isRead
        ? (isDark
            ? Colors.white.withValues(alpha: 0.08)
            : Colors.white)
        : DD.accent.withValues(alpha: 0.45);

    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(DD.rCard),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(DD.rCard),
              border: Border.all(
                color: borderColor,
                width: isRead ? 1.0 : 1.5,
              ),
              boxShadow: isRead
                  ? null
                  : [
                      BoxShadow(
                        color: DD.accent.withValues(alpha: 0.20),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                        spreadRadius: -8,
                      ),
                    ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Иконка + аталыш + badge ──
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        gradient: DD.accentGradient,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: DD.accent.withValues(alpha: 0.35),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                            spreadRadius: -4,
                          ),
                        ],
                      ),
                      child: const Icon(Icons.campaign_rounded,
                          color: Colors.white, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  title,
                                  style: AppTextStyles.labelLarge.copyWith(
                                    color: textColor,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              if (!isRead)
                                Container(
                                  margin: const EdgeInsets.only(left: 8, top: 4),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    gradient: DD.accentGradient,
                                    borderRadius:
                                        BorderRadius.circular(DD.rPill),
                                    boxShadow: [
                                      BoxShadow(
                                        color: DD.accent.withValues(alpha: 0.40),
                                        blurRadius: 6,
                                        offset: const Offset(0, 2),
                                        spreadRadius: -2,
                                      ),
                                    ],
                                  ),
                                  child: const Text(
                                    'ЖАҢЫ',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 9,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          if (body.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text(
                              body,
                              style: AppTextStyles.bodyMedium
                                  .copyWith(color: subColor, height: 1.35),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),

                // ── Сүрөт ──
                if (imageUrl != null && imageUrl!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: CachedNetworkImage(
                      imageUrl: imageUrl!,
                      width: double.infinity,
                      height: 200,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => Container(
                        height: 200,
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.06)
                            : Colors.black.withValues(alpha: 0.04),
                        child: const Center(
                          child: CircularProgressIndicator(
                              color: DD.accent, strokeWidth: 2),
                        ),
                      ),
                      errorWidget: (_, __, ___) => Container(
                        height: 60,
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.04)
                            : Colors.black.withValues(alpha: 0.03),
                        child: const Icon(Icons.broken_image_outlined,
                            color: AppColors.grey400),
                      ),
                    ),
                  ),
                ],

                // ── Убакыт пилюля ──
                const SizedBox(height: 12),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.06)
                            : Colors.black.withValues(alpha: 0.04),
                        borderRadius: BorderRadius.circular(DD.rPill),
                        border: Border.all(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.10)
                              : Colors.black.withValues(alpha: 0.06),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.access_time_rounded,
                              size: 12, color: subColor),
                          const SizedBox(width: 4),
                          Text(
                            timeText,
                            style: AppTextStyles.labelSmall.copyWith(
                              color: subColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}