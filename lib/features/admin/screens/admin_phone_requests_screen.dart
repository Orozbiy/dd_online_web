// lib/features/admin/screens/admin_phone_requests_screen.dart

import 'package:flutter/material.dart';
import '../../../config/theme/app_colors.dart';
import '../../../config/theme/app_text_styles.dart';
import '../../../core/supabase_client.dart';

class AdminPhoneRequestsScreen extends StatefulWidget {
  const AdminPhoneRequestsScreen({super.key});

  @override
  State<AdminPhoneRequestsScreen> createState() =>
      _AdminPhoneRequestsScreenState();
}

class _AdminPhoneRequestsScreenState
    extends State<AdminPhoneRequestsScreen>
    with SingleTickerProviderStateMixin {
  List<Map<String, dynamic>> _requests = [];
  bool _loading = true;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final rows = await supabase
          .from('phone_change_requests')
          .select()
          .order('created_at', ascending: false);
      if (mounted) {
        setState(() {
          _requests = (rows as List).cast<Map<String, dynamic>>();
          _loading  = false;
        });
      }
    } catch (e) {
      debugPrint('❌ phone_change_requests: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  List<Map<String, dynamic>> get _pending =>
      _requests.where((r) => r['status'] == 'pending').toList();

  List<Map<String, dynamic>> get _done =>
      _requests.where((r) => r['status'] != 'pending').toList();

  void _showSnack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      ),
    );
  }

  Future<void> _approve(Map<String, dynamic> r) async {
    final newPhone  = r['new_phone']  as String?;
    final sellerUid = r['seller_uid'] as String?;
    if (newPhone == null || sellerUid == null) return;

    try {
      // Профилдеги номерди өзгөртүү
      await supabase
          .from('profiles')
          .update({'phone': newPhone})
          .eq('id', sellerUid);

      // Өтүнүч статусун жаңыртуу
      await supabase
          .from('phone_change_requests')
          .update({'status': 'approved'})
          .eq('id', r['id'] as String);

      // Жергиликтүү тизмени дароо жаңыртуу
      if (mounted) {
        setState(() {
          final index =
              _requests.indexWhere((req) => req['id'] == r['id']);
          if (index != -1) {
            _requests[index] = {
              ..._requests[index],
              'status': 'approved',
            };
          }
        });
      }

      _showSnack('✅ Номер өзгөртүлдү: $newPhone', AppColors.success);
      await _load();
    } catch (e) {
      _showSnack('❌ Ката чыкты: $e', AppColors.error);
    }
  }

  Future<void> _reject(Map<String, dynamic> r) async {
    try {
      await supabase
          .from('phone_change_requests')
          .update({'status': 'rejected'})
          .eq('id', r['id'] as String);

      // Жергиликтүү тизмени дароо жаңыртуу
      if (mounted) {
        setState(() {
          final index =
              _requests.indexWhere((req) => req['id'] == r['id']);
          if (index != -1) {
            _requests[index] = {
              ..._requests[index],
              'status': 'rejected',
            };
          }
        });
      }

      _showSnack('❌ Өтүнүч четке кагылды', AppColors.error);
      await _load();
    } catch (e) {
      _showSnack('❌ Ката чыкты: $e', AppColors.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark     = Theme.of(context).brightness == Brightness.dark;
    final scaffoldBg =
        isDark ? const Color(0xFF121212) : const Color(0xFFF0F4FF);

    return Scaffold(
      backgroundColor: scaffoldBg,
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E40AF),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          '📞 Номер өзгөртүү өтүнүчтөрү',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white70),
            onPressed: _load,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          tabs: [
            Tab(text: '⏳ Күтүүдө (${_pending.length})'),
            Tab(text: '✅ Аяктагандар (${_done.length})'),
          ],
        ),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary))
          : TabBarView(
              controller: _tabController,
              children: [
                _buildList(_pending, isDark, showActions: true),
                _buildList(_done,    isDark, showActions: false),
              ],
            ),
    );
  }

  Widget _buildList(
    List<Map<String, dynamic>> list,
    bool isDark, {
    required bool showActions,
  }) {
    if (list.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('📭', style: TextStyle(fontSize: 48)),
            const SizedBox(height: 12),
            Text(
              showActions
                  ? 'Күтүүдөгү өтүнүч жок'
                  : 'Аяктаган өтүнүч жок',
              style: AppTextStyles.bodyMedium
                  .copyWith(color: AppColors.grey500),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      color: AppColors.primary,
      child: ListView.builder(
        padding: const EdgeInsets.all(14),
        itemCount: list.length,
        itemBuilder: (_, i) =>
            _buildCard(list[i], isDark, showActions: showActions),
      ),
    );
  }

  Widget _buildCard(
    Map<String, dynamic> r,
    bool isDark, {
    required bool showActions,
  }) {
    final cardBg     = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final status     = r['status'] as String? ?? 'pending';
    final isPending  = status == 'pending';
    final isApproved = status == 'approved';

    // Дата форматтоо
    final createdRaw = r['created_at'] as String?;
    String dateStr = '';
    if (createdRaw != null) {
      final dt = DateTime.tryParse(createdRaw);
      if (dt != null) {
        final local = dt.toLocal();
        dateStr =
            '${local.day.toString().padLeft(2, '0')}.'
            '${local.month.toString().padLeft(2, '0')}.'
            '${local.year}  '
            '${local.hour.toString().padLeft(2, '0')}:'
            '${local.minute.toString().padLeft(2, '0')}';
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isPending
              ? AppColors.primary.withValues(alpha: 0.4)
              : isApproved
                  ? AppColors.success.withValues(alpha: 0.3)
                  : AppColors.error.withValues(alpha: 0.3),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Баш катар ──
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E40AF).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Center(
                    child: Text('🏪', style: TextStyle(fontSize: 22)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        r['shop_name'] as String? ?? '—',
                        style: AppTextStyles.labelLarge.copyWith(
                            color: isDark ? Colors.white : AppColors.black),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        r['seller_name'] as String? ?? '—',
                        style: AppTextStyles.labelSmall
                            .copyWith(color: AppColors.grey500),
                      ),
                    ],
                  ),
                ),
                // Статус badge
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isPending
                        ? AppColors.primary.withValues(alpha: 0.1)
                        : isApproved
                            ? AppColors.success.withValues(alpha: 0.1)
                            : AppColors.error.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    isPending
                        ? '⏳ Күтүүдө'
                        : isApproved
                            ? '✅ Бекитилди'
                            : '❌ Четке',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isPending
                          ? AppColors.primary
                          : isApproved
                              ? AppColors.success
                              : AppColors.error,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 14),

            // ── Номерлер блогу ──
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF2C2C2C)
                    : const Color(0xFFF7F7F7),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Эски номер
                  Row(children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: AppColors.grey200,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.phone_outlined,
                          size: 14, color: AppColors.grey500),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Эски номер',
                            style: AppTextStyles.labelSmall.copyWith(
                                color: AppColors.grey400, fontSize: 10)),
                        Text(
                          r['old_phone'] as String? ?? '—',
                          style: AppTextStyles.bodyMedium.copyWith(
                              color: isDark
                                  ? Colors.white70
                                  : AppColors.grey600),
                        ),
                      ],
                    ),
                  ]),

                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(children: [
                      const SizedBox(width: 7),
                      Icon(Icons.arrow_downward,
                          size: 16, color: AppColors.grey400),
                    ]),
                  ),

                  // Жаңы номер
                  Row(children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color:
                            AppColors.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.phone_android,
                          size: 14, color: AppColors.primary),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Жаңы номер',
                            style: AppTextStyles.labelSmall.copyWith(
                                color: AppColors.primary
                                    .withValues(alpha: 0.7),
                                fontSize: 10)),
                        Text(
                          r['new_phone'] as String? ?? '—',
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ]),
                ],
              ),
            ),

            // ── Дата ──
            if (dateStr.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(children: [
                const Icon(Icons.access_time,
                    size: 12, color: AppColors.grey400),
                const SizedBox(width: 4),
                Text(dateStr,
                    style: AppTextStyles.labelSmall.copyWith(
                        color: AppColors.grey400, fontSize: 11)),
              ]),
            ],

            // ── Баскычтар ──
            if (showActions) ...[
              const SizedBox(height: 14),
              Row(children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => _reject(r),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF2C1010)
                            : const Color(0xFFFFEEEE),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color:
                                AppColors.error.withValues(alpha: 0.3)),
                      ),
                      child: Center(
                        child: Text('❌  Четке кагуу',
                            style: AppTextStyles.labelMedium
                                .copyWith(color: AppColors.error)),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: GestureDetector(
                    onTap: () => _approve(r),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF0A2C1A)
                            : const Color(0xFFEEFFF5),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: AppColors.success
                                .withValues(alpha: 0.3)),
                      ),
                      child: Center(
                        child: Text('✅  Бекитүү',
                            style: AppTextStyles.labelMedium
                                .copyWith(color: AppColors.success)),
                      ),
                    ),
                  ),
                ),
              ]),
            ],
          ],
        ),
      ),
    );
  }
}