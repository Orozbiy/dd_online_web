import 'package:flutter/material.dart';
import '../../../config/theme/app_colors.dart';
import '../../../config/theme/app_text_styles.dart';
import '../../../core/supabase_client.dart';

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
    try {
      final userId = supabase.auth.currentUser?.id;

      // Билдирүүлөрдү жүктө
      final rows = await supabase
          .from('admin_notifications')
          .select()
          .order('created_at', ascending: false);

      // Окулгандарды жүктө
      Set<String> readIds = {};
      if (userId != null) {
        final reads = await supabase
            .from('notification_reads')
            .select('notification_id')
            .eq('user_id', userId);
        readIds = (reads as List)
            .map((r) => r['notification_id'] as String)
            .toSet();
      }

      if (mounted) {
        setState(() {
          _notifications = (rows as List).cast<Map<String, dynamic>>();
          _readIds = readIds;
          _isLoading = false;
        });

        // Экранга киргенде баарын окулган деп белгиле
        if (userId != null) {
          _markAllAsRead(userId);
        }
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _markAllAsRead(String userId) async {
    try {
      final unread = _notifications
          .where((n) => !_readIds.contains(n['id'] as String))
          .toList();

      if (unread.isEmpty) return;

      // Баарын бир учурда жаз
      final rows = unread.map((n) => {
            'user_id': userId,
            'notification_id': n['id'] as String,
          }).toList();

      await supabase
          .from('notification_reads')
          .upsert(rows, onConflict: 'user_id,notification_id');

      if (mounted) {
        setState(() {
          _readIds = _notifications.map((n) => n['id'] as String).toSet();
        });
      }
    } catch (_) {}
  }

  String _timeAgo(String? createdAt) {
    if (createdAt == null) return '';
    final dt = DateTime.tryParse(createdAt)?.toLocal();
    if (dt == null) return '';
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Азыр';
    if (diff.inHours < 1) return '${diff.inMinutes} мүн. мурун';
    if (diff.inDays < 1) return '${diff.inHours} саат мурун';
    if (diff.inDays < 30) return '${diff.inDays} күн мурун';
    return '${dt.day}.${dt.month}.${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    final isDark      = Theme.of(context).brightness == Brightness.dark;
    final bgColor     = isDark ? const Color(0xFF0D0F1A) : const Color(0xFFF4F5F7);
    final cardColor   = isDark ? const Color(0xFF14162A) : Colors.white;
    final unreadColor = isDark ? const Color(0xFF1C1E38) : const Color(0xFFFFF8F0);
    final textColor   = isDark ? Colors.white : AppColors.black;
    final subColor    = isDark ? const Color(0xFFAAAAAA) : AppColors.grey500;
    final borderColor = isDark ? const Color(0xFF2A2560) : Colors.transparent;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF14162A) : Colors.white,
        foregroundColor: textColor,
        elevation: 0,
        centerTitle: true,
        title: Text(
          'Билдирүүлөр',
          style: AppTextStyles.headingSmall.copyWith(color: textColor),
        ),
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Icon(Icons.arrow_back, color: textColor),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary))
          : _notifications.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.notifications_none_rounded,
                          size: 72,
                          color: isDark ? Colors.white24 : Colors.grey[300]),
                      const SizedBox(height: 16),
                      Text('Билдирүүлөр жок',
                          style:
                              AppTextStyles.bodyMedium.copyWith(color: subColor)),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  color: AppColors.primary,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _notifications.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, i) {
                      final n       = _notifications[i];
                      final id      = n['id'] as String;
                      final title   = n['title'] as String? ?? '';
                      final body    = n['body'] as String? ?? '';
                      final isRead  = _readIds.contains(id);

                      return Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isRead ? cardColor : unreadColor,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isRead
                                ? borderColor
                                : AppColors.primary.withValues(alpha: 0.3),
                            width: isRead ? 0.8 : 1.2,
                          ),
                          boxShadow: isDark
                              ? [
                                  BoxShadow(
                                    color: const Color(0xFF3D2080)
                                        .withValues(alpha: 0.12),
                                    blurRadius: 10,
                                    offset: const Offset(0, 3),
                                  ),
                                ]
                              : [
                                  BoxShadow(
                                    color:
                                        Colors.black.withValues(alpha: 0.06),
                                    blurRadius: 10,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Иконка
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFFD97706), Color(0xFFEF4444)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.campaign_rounded,
                                  color: Colors.white, size: 22),
                            ),
                            const SizedBox(width: 12),

                            // Текст
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          title,
                                          style: AppTextStyles.labelLarge
                                              .copyWith(
                                            color: textColor,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                      // Окулбаган — кызыл dot
                                      if (!isRead)
                                        Container(
                                          width: 8,
                                          height: 8,
                                          margin: const EdgeInsets.only(left: 8, top: 2),
                                          decoration: const BoxDecoration(
                                            color: AppColors.error,
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(body,
                                      style: AppTextStyles.bodyMedium
                                          .copyWith(color: subColor)),
                                  const SizedBox(height: 8),
                                  Text(
                                    _timeAgo(n['created_at'] as String?),
                                    style: AppTextStyles.bodySmall.copyWith(
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}