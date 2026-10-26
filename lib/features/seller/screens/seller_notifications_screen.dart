// lib/features/seller/screens/seller_notifications_screen.dart
//
// Сатуучуларга арналган — Админ билдирүүлөрү

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../config/theme/app_colors.dart';
import '../../../config/theme/app_text_styles.dart';
import '../../../core/supabase_client.dart';

class SellerNotificationsScreen extends StatefulWidget {
  final String sellerUid;
  const SellerNotificationsScreen({super.key, required this.sellerUid});

  @override
  State<SellerNotificationsScreen> createState() =>
      _SellerNotificationsScreenState();
}

class _SellerNotificationsScreenState
    extends State<SellerNotificationsScreen> {
  List<Map<String, dynamic>> _notifications = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      // Жалпы (seller_id жок) + ушул сатуучуга жазылган билдирүүлөр
      final rows = await supabase
          .from('admin_notifications')
          .select()
          .or('seller_id.is.null,seller_id.eq.${widget.sellerUid}')
          .order('created_at', ascending: false);
      if (mounted) {
        setState(() {
          _notifications = (rows as List).cast<Map<String, dynamic>>();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _timeAgo(String? createdAt) {
    if (createdAt == null) return '';
    final dt = DateTime.tryParse(createdAt)?.toLocal();
    if (dt == null) return '';
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Азыр';
    if (diff.inHours < 1) return '${diff.inMinutes} мүн. мурун';
    if (diff.inDays < 1) return '${diff.inHours} саат мурун';
    if (diff.inDays < 7) return '${diff.inDays} күн мурун';
    return '${dt.day}.${dt.month}.${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor   = isDark ? const Color(0xFF121212) : Colors.white;
    final cardColor = isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF7F8FA);
    final textColor = isDark ? Colors.white : AppColors.black;
    final subColor  = isDark ? Colors.white60 : AppColors.grey500;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            const Text('🔔', style: TextStyle(fontSize: 20)),
            const SizedBox(width: 8),
            Text(
              'Админден билдирүүлөр',
              style: AppTextStyles.headingMedium.copyWith(color: textColor),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh_rounded, color: subColor),
            onPressed: _load,
            tooltip: 'Жаңылоо',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary))
          : _notifications.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.notifications_none_rounded,
                        size: 72,
                        color: isDark ? Colors.white24 : Colors.grey[300],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Азырынча билдирүү жок',
                        style: AppTextStyles.bodyMedium
                            .copyWith(color: subColor),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  color: AppColors.primary,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _notifications.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (_, i) {
                      final n = _notifications[i];
                      final title = n['title'] as String? ?? '';
                      final body = n['body'] as String? ?? '';
                      final imageUrl = n['image_url'] as String?;

                      return Container(
                        decoration: BoxDecoration(
                          color: cardColor,
                          borderRadius: BorderRadius.circular(16),
                          border: isDark
                              ? null
                              : Border.all(
                                  color: const Color(0xFFE8EAED),
                                  width: 1,
                                ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black
                                  .withValues(alpha: isDark ? 0.3 : 0.04),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Иконка
                                  Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        colors: [
                                          Color(0xFFD97706),
                                          Color(0xFFEF4444),
                                        ],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Icon(
                                      Icons.campaign_rounded,
                                      color: Colors.white,
                                      size: 22,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  // Текст
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          title,
                                          style: AppTextStyles.labelLarge
                                              .copyWith(
                                            color: textColor,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          body,
                                          style: AppTextStyles.bodySmall
                                              .copyWith(
                                                  color: subColor,
                                                  height: 1.4),
                                        ),
                                        const SizedBox(height: 8),
                                        Row(
                                          children: [
                                            Icon(
                                              Icons.access_time_rounded,
                                              size: 13,
                                              color: AppColors.primary,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              _timeAgo(n['created_at']
                                                  as String?),
                                              style: AppTextStyles.labelSmall
                                                  .copyWith(
                                                      color:
                                                          AppColors.primary),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // Сүрөт (болсо)
                            if (imageUrl != null && imageUrl.isNotEmpty)
                              ClipRRect(
                                borderRadius: const BorderRadius.only(
                                  bottomLeft: Radius.circular(16),
                                  bottomRight: Radius.circular(16),
                                ),
                                child: CachedNetworkImage(
                                  imageUrl: imageUrl,
                                  width: double.infinity,
                                  height: 200,
                                  fit: BoxFit.cover,
                                  placeholder: (_, __) => Container(
                                    height: 200,
                                    color: isDark
                                        ? const Color(0xFF2A2560)
                                        : const Color(0xFFEEEEEE),
                                    child: const Center(
                                      child: CircularProgressIndicator(
                                          color: AppColors.primary,
                                          strokeWidth: 2),
                                    ),
                                  ),
                                  errorWidget: (_, __, ___) => const SizedBox(),
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