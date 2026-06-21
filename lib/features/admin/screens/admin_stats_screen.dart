import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../config/theme/app_colors.dart';
import '../../../config/theme/app_text_styles.dart';
import '../../../core/supabase_client.dart';

/// Жалпы катталган колдонуучулар, онлайн (last_active_at боюнча
/// болжолдуу) жана сатуучулар статистикасын көрсөтүүчү экран.
class AdminStatsScreen extends StatefulWidget {
  const AdminStatsScreen({super.key});

  @override
  State<AdminStatsScreen> createState() => _AdminStatsScreenState();
}

class _AdminStatsScreenState extends State<AdminStatsScreen> {
  static const _onlineThreshold = Duration(minutes: 5);

  int _totalUsers = 0;
  int _onlineUsers = 0;
  int _totalSellers = 0;
  int _approvedSellers = 0;
  int _pendingSellers = 0;
  bool _isLoading = true;

  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _loadStats();
    // Онлайн саны автоматтык жаныртылып турсун.
    _refreshTimer =
        Timer.periodic(const Duration(seconds: 30), (_) => _loadStats());
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  /// `count(CountOption.exact)` SDK версиясына жараша өзгөрүп турат,
  /// ошондуктан ишенимдүү жол — бардык катарларды (`id` гана) алып,
  /// тизмеси узундугун эсептөө.
  Future<int> _countRows(PostgrestFilterBuilder query) async {
    final rows = await query;
    return (rows as List).length;
  }

  Future<void> _loadStats() async {
    try {
      final cutoff = DateTime.now()
          .toUtc()
          .subtract(_onlineThreshold)
          .toIso8601String();

      // Жалпы катталгандар (бардык роль).
      final total = await _countRows(
        supabase.from('profiles').select('id'),
      );

      // Соңку 5 мүнөттө активдүү болгондор.
      final online = await _countRows(
        supabase.from('profiles').select('id').gte('last_active_at', cutoff),
      );

      // Сатуучулар (seller_status толтурулган).
      final sellers = await _countRows(
        supabase
            .from('profiles')
            .select('id')
            .not('seller_status', 'is', null)
            .neq('seller_status', ''),
      );

      final approved = await _countRows(
        supabase
            .from('profiles')
            .select('id')
            .eq('seller_status', 'approved'),
      );

      final pending = await _countRows(
        supabase
            .from('profiles')
            .select('id')
            .eq('seller_status', 'pending'),
      );

      if (!mounted) return;
      setState(() {
        _totalUsers = total;
        _onlineUsers = online;
        _totalSellers = sellers;
        _approvedSellers = approved;
        _pendingSellers = pending;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('❌ AdminStatsScreen _loadStats: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F5F7),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: const Icon(Icons.arrow_back, color: AppColors.black),
        ),
        title: const Text('📊 Статистика', style: AppTextStyles.headingMedium),
        actions: [
          IconButton(
            onPressed: _loadStats,
            icon: const Icon(Icons.refresh, color: AppColors.grey600),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary))
          : RefreshIndicator(
              onRefresh: _loadStats,
              color: AppColors.primary,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // ── Онлайн (реалтайм болжолдуу) ──
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF22C55E), Color(0xFF16A34A)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 10,
                              height: 10,
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Text('Учурда онлайн',
                                style: TextStyle(
                                    color: Colors.white70, fontSize: 13)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text('$_onlineUsers',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 40,
                                fontWeight: FontWeight.w900)),
                        const SizedBox(height: 4),
                        const Text(
                          'Соңку 5 мүнөттө активдүү колдонуучулар',
                          style: TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // ── Жалпы катталгандар ──
                  Row(
                    children: [
                      Expanded(
                        child: _statCard(
                          icon: '👥',
                          label: 'Бардык катталгандар',
                          value: '$_totalUsers',
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _statCard(
                          icon: '🏪',
                          label: 'Сатуучулар',
                          value: '$_totalSellers',
                          color: const Color(0xFF7C3AED),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  Row(
                    children: [
                      Expanded(
                        child: _statCard(
                          icon: '✅',
                          label: 'Активдүү сатуучулар',
                          value: '$_approvedSellers',
                          color: AppColors.success,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _statCard(
                          icon: '⏳',
                          label: 'Күтүүдөгү өтүнүчтөр',
                          value: '$_pendingSellers',
                          color: AppColors.error,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF8F0),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.25)),
                    ),
                    child: const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('ℹ️', style: TextStyle(fontSize: 16)),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Онлайн саны 30 секунд сайын автоматтык жаныртылат. '
                            'Колдонуучу "онлайн" деп, тиркемени соңку 5 мүнөттө '
                            'колдонгон болсо эсептелет.',
                            style: AppTextStyles.bodySmall,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _statCard({
    required String icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(icon, style: const TextStyle(fontSize: 24)),
          const SizedBox(height: 8),
          Text(value,
              style: TextStyle(
                  fontSize: 26, fontWeight: FontWeight.w900, color: color)),
          const SizedBox(height: 2),
          Text(label,
              style: AppTextStyles.labelSmall
                  .copyWith(color: AppColors.grey500)),
        ],
      ),
    );
  }
}