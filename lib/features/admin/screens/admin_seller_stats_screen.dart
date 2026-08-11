// ═══════════════════════════════════════════════════════════════
// lib/features/admin/screens/admin_seller_stats_screen.dart
//
// Admin панелинен чакыруу:
//   Navigator.push(context, MaterialPageRoute(
//     builder: (_) => const AdminSellerStatsScreen()));
// ═══════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import '../../../config/theme/app_colors.dart';
import '../../../config/theme/app_text_styles.dart';
import '../../../core/supabase_client.dart';

class AdminSellerStatsScreen extends StatefulWidget {
  const AdminSellerStatsScreen({super.key});

  @override
  State<AdminSellerStatsScreen> createState() => _AdminSellerStatsScreenState();
}

class _AdminSellerStatsScreenState extends State<AdminSellerStatsScreen> {
  List<Map<String, dynamic>> _sellers = [];
  bool _loading = true;
  String _sort = 'views'; // views | chats | nav | name

  @override
  void initState() {
    super.initState();
    _load();
  }

  // ── Маалымат жүктөө ─────────────────────────────────
  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final rows = await supabase
          .from('admin_seller_stats')
          .select();
      final list = (rows as List).cast<Map<String, dynamic>>();
      _applySort(list);
      if (mounted) setState(() { _sellers = list; _loading = false; });
    } catch (e) {
      debugPrint('❌ admin_seller_stats: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  void _applySort(List<Map<String, dynamic>> list) {
    list.sort((a, b) {
      switch (_sort) {
        case 'chats':
          return _int(b, 'total_chats').compareTo(_int(a, 'total_chats'));
        case 'nav':
          return _int(b, 'total_navigations').compareTo(_int(a, 'total_navigations'));
        case 'name':
          return (_str(a, 'store_name')).compareTo(_str(b, 'store_name'));
        case 'views':
        default:
          return _int(b, 'total_views').compareTo(_int(a, 'total_views'));
      }
    });
  }

  int    _int(Map m, String k) => (m[k] as num?)?.toInt() ?? 0;
  String _str(Map m, String k) => (m[k] as String?) ?? '';

  // ── Жалпы жыйынды ───────────────────────────────────
  int get _totalViews    => _sellers.fold(0, (s, e) => s + _int(e, 'total_views'));
  int get _totalChats    => _sellers.fold(0, (s, e) => s + _int(e, 'total_chats'));
  int get _totalNavs     => _sellers.fold(0, (s, e) => s + _int(e, 'total_navigations'));
  int get _paidCount     => _sellers.where((e) => e['current_month_paid'] == true).length;
  int get _unpaidCount   => _sellers.length - _paidCount;

  // ── Төлөдү белгилөө ─────────────────────────────────
  Future<void> _markPaid(Map<String, dynamic> seller) async {
    final uid = seller['seller_id'] as String;
    final now = DateTime.now();
    final month = '${now.year}-${now.month.toString().padLeft(2, '0')}';

    // Учурдагы payments массивин ал
    final profileRow = await supabase
        .from('profiles')
        .select('payments')
        .eq('id', uid)
        .single();

    final payments = List<dynamic>.from(profileRow['payments'] ?? []);

    // Бул айдын жазуусун издеп тап же жаңы кош
    final idx = payments.indexWhere((p) => p['month'] == month);
    final entry = {
      'month': month,
      'paid': true,
      'paidAt': DateTime.now().toIso8601String(),
      'amount': 2000,
      'method': 'manual',
    };

    if (idx >= 0) {
      payments[idx] = entry;
    } else {
      payments.add(entry);
    }

    await supabase.from('profiles').update({
      'payments': payments,
    }).eq('id', uid);

    _showSnack('✅ ${seller['store_name']} — төлөм белгиленди!');
    _load(); // экранды жаңырт
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: AppColors.success),
    );
  }

  // ════════════════════════════════════════════════════
  // BUILD
  // ════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg     = isDark ? const Color(0xFF121212) : const Color(0xFFF4F5F7);
    final cardBg = isDark ? const Color(0xFF1E1E1E) : Colors.white;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: cardBg,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back,
              color: isDark ? Colors.white : AppColors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('📊 Сатуучулар статистикасы',
            style: AppTextStyles.headingMedium),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: AppColors.grey600),
            onPressed: _load,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : RefreshIndicator(
              onRefresh: _load,
              color: AppColors.primary,
              child: CustomScrollView(
                slivers: [
                  // ── Жалпы статистика ──
                  SliverToBoxAdapter(
                    child: _buildSummary(cardBg, isDark),
                  ),

                  // ── Сорттоо ──
                  SliverToBoxAdapter(
                    child: _buildSortBar(cardBg),
                  ),

                  // ── Сатуучулар тизмеси ──
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (ctx, i) => _SellerCard(
                        seller: _sellers[i],
                        rank: i + 1,
                        cardBg: cardBg,
                        isDark: isDark,
                        onMarkPaid: () => _markPaid(_sellers[i]),
                      ),
                      childCount: _sellers.length,
                    ),
                  ),

                  const SliverToBoxAdapter(child: SizedBox(height: 24)),
                ],
              ),
            ),
    );
  }

  // ── Жалпы жыйынды карточкасы ────────────────────────
  Widget _buildSummary(Color cardBg, bool isDark) {
    return Container(
      margin: const EdgeInsets.all(14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E40AF), Color(0xFF7C3AED)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Text('📊', style: TextStyle(fontSize: 20)),
            const SizedBox(width: 8),
            Text(
              'Бардык сатуучулар: ${_sellers.length}',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600),
            ),
          ]),
          const SizedBox(height: 14),
          Row(children: [
            _summaryChip('👁 $_totalViews', 'Жалпы көрүү'),
            const SizedBox(width: 8),
            _summaryChip('💬 $_totalChats', 'Жалпы чат'),
            const SizedBox(width: 8),
            _summaryChip('🗺 $_totalNavs', 'Навигация'),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            _summaryChip('✅ $_paidCount', 'Төлөдү', color: Colors.green.shade300),
            const SizedBox(width: 8),
            _summaryChip('❌ $_unpaidCount', 'Төлөбөдү', color: Colors.red.shade300),
          ]),
        ],
      ),
    );
  }

  Widget _summaryChip(String value, String label, {Color? color}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Text(value,
                style: TextStyle(
                    color: color ?? Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 2),
            Text(label,
                style:
                    const TextStyle(color: Colors.white60, fontSize: 10)),
          ],
        ),
      ),
    );
  }

  // ── Сорттоо тилкеси ─────────────────────────────────
  Widget _buildSortBar(Color cardBg) {
    return Container(
      color: cardBg,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            const Text('Сорттоо: ',
                style: TextStyle(
                    fontSize: 13,
                    color: AppColors.grey500)),
            const SizedBox(width: 8),
            _sortChip('👁 Көрүүлөр', 'views'),
            const SizedBox(width: 6),
            _sortChip('💬 Чаттар', 'chats'),
            const SizedBox(width: 6),
            _sortChip('🗺 Навигация', 'nav'),
            const SizedBox(width: 6),
            _sortChip('🔤 Аты', 'name'),
          ],
        ),
      ),
    );
  }

  Widget _sortChip(String label, String value) {
    final selected = _sort == value;
    return GestureDetector(
      onTap: () {
        setState(() => _sort = value);
        _applySort(_sellers);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary
              : AppColors.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : AppColors.primary,
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// SELLER CARD WIDGET
// ═══════════════════════════════════════════════════════════════

class _SellerCard extends StatelessWidget {
  final Map<String, dynamic> seller;
  final int rank;
  final Color cardBg;
  final bool isDark;
  final VoidCallback onMarkPaid;

  const _SellerCard({
    required this.seller,
    required this.rank,
    required this.cardBg,
    required this.isDark,
    required this.onMarkPaid,
  });

  int    _int(String k) => (seller[k] as num?)?.toInt() ?? 0;
  String _str(String k) => (seller[k] as String?) ?? '';
  bool   _paid()        => seller['current_month_paid'] == true;

  // Аты → Дүкөн аты → Толук аты → Телефон — биринчи бош эмесин кайтарат
  String _displayName() {
    final shopName   = _str('store_name').trim();
    final fullName   = _str('seller_name').trim();
    final phone      = _str('phone').trim();
    final displayName = _str('display_name').trim();
    if (displayName.isNotEmpty) return displayName;
    if (shopName.isNotEmpty)    return shopName;
    if (fullName.isNotEmpty)    return fullName;
    if (phone.isNotEmpty)       return phone;
    return 'Белгисиз';
  }

  @override
  Widget build(BuildContext context) {
    final paid = _paid();

    return Container(
      margin: const EdgeInsets.fromLTRB(14, 0, 14, 10),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: paid
              ? AppColors.success.withValues(alpha: 0.4)
              : AppColors.error.withValues(alpha: 0.2),
          width: 0.8,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // ── Жогорку катар: дүкөн аты + төлөм статусу ──
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
            child: Row(
              children: [
                // Рейтинг номери
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: rank <= 3
                        ? AppColors.primary.withValues(alpha: 0.15)
                        : AppColors.grey200,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Text(
                      rank <= 3 ? ['🥇', '🥈', '🥉'][rank - 1] : '#$rank',
                      style: TextStyle(
                          fontSize: rank <= 3 ? 16 : 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.grey600),
                    ),
                  ),
                ),
                const SizedBox(width: 10),

                // Дүкөн аты + сатуучу аты + телефон
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Негизги аталыш: display_name (аты жок болсо телефон)
                      Text(
                        _displayName(),
                        style: AppTextStyles.labelLarge,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      // Телефон дайыма көрүнөт
                      Row(
                        children: [
                          const Icon(Icons.phone, size: 11, color: AppColors.grey400),
                          const SizedBox(width: 3),
                          Text(
                            _str('phone').isNotEmpty ? _str('phone') : '—',
                            style: AppTextStyles.labelSmall
                                .copyWith(color: AppColors.grey500),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Төлөм статусу
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: paid
                        ? AppColors.success.withValues(alpha: 0.12)
                        : AppColors.error.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    paid ? '✅ Төлөдү' : '❌ Төлөбөдү',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: paid ? AppColors.success : AppColors.error,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Статистика тилкеси ──
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
            child: Row(
              children: [
                _statItem('👁', '${_int('total_views')}', 'Көрүүлөр'),
                _divider(),
                _statItem('💬', '${_int('total_chats')}', 'Чаттар'),
                _divider(),
                _statItem('🗺', '${_int('total_navigations')}', 'Навигация'),
                _divider(),
                _statItem('📦', '${_int('products_count')}', 'Товар'),
              ],
            ),
          ),

          // ── Төлөдү баскычы (төлөбөгөн болсо гана) ──
          if (!paid)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
              child: GestureDetector(
                onTap: onMarkPaid,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.success,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Center(
                    child: Text(
                      '💰  Төлөдү деп белгилөө',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _statItem(String icon, String value, String label) {
    return Expanded(
      child: Column(
        children: [
          Text(icon, style: const TextStyle(fontSize: 16)),
          const SizedBox(height: 2),
          Text(value,
              style: const TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w700)),
          Text(label,
              style: const TextStyle(
                  fontSize: 10, color: AppColors.grey500)),
        ],
      ),
    );
  }

  Widget _divider() => Container(
        width: 0.5,
        height: 40,
        color: AppColors.grey200,
        margin: const EdgeInsets.symmetric(horizontal: 4),
      );
}
