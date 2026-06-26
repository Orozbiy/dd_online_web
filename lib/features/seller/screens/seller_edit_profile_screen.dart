import 'package:flutter/material.dart';
import '../../../config/theme/app_colors.dart';
import '../../../config/theme/app_text_styles.dart';
import '../../../core/supabase_client.dart';

class SellerEditProfileScreen extends StatefulWidget {
  final String currentName;
  final String currentShopName;
  final String currentContainer;

  const SellerEditProfileScreen({
    super.key,
    required this.currentName,
    required this.currentShopName,
    required this.currentContainer,
  });

  @override
  State<SellerEditProfileScreen> createState() => _SellerEditProfileScreenState();
}

class _SellerEditProfileScreenState extends State<SellerEditProfileScreen> {
  String  _storeType  = 'market';
  String? _marketName = 'Дордой базары';
  bool    _isLoading  = false;
  bool    _initLoading = true;

  static const List<String> _markets = [
    'Дордой базары',
    'Ош базары',
    'Азиз базары',
    'Мадина базары',
    'Орто-Сай базары',
    'Аламүдүн базары',
    'Кара-Суу базары',
    'Птичий рынок',
  ];

  late final TextEditingController _nameCtrl;
  late final TextEditingController _shopCtrl;
  late final TextEditingController _containerCtrl;

  @override
  void initState() {
    super.initState();
    _nameCtrl      = TextEditingController(text: widget.currentName);
    _shopCtrl      = TextEditingController(text: widget.currentShopName);
    _containerCtrl = TextEditingController(text: widget.currentContainer);
    _loadCurrentData();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _shopCtrl.dispose();
    _containerCtrl.dispose();
    super.dispose();
  }

  // ── Учурдагы store_type жана market_name жүктөө ──────────────────────────
  Future<void> _loadCurrentData() async {
    try {
      final uid = supabase.auth.currentUser?.id;
      if (uid == null) return;

      final profile = await supabase
          .from('profiles')
          .select('store_type, market_name')
          .eq('id', uid)
          .maybeSingle();

      if (profile != null && mounted) {
        final st = profile['store_type'] as String? ?? 'market';
        final mn = profile['market_name'] as String?;
        setState(() {
          _storeType  = st;
          _marketName = mn ?? 'Дордой базары';
        });
      }
    } catch (e) {
      debugPrint('_loadCurrentData: $e');
    } finally {
      if (mounted) setState(() => _initLoading = false);
    }
  }

  // ── Сактоо ────────────────────────────────────────────────────────────────
  Future<void> _save() async {
    setState(() => _isLoading = true);
    try {
      final uid = supabase.auth.currentUser?.id;
      if (uid == null) return;

      // 1) profiles таблицасы — аты, дүкөн түрү, рынок аты
      await supabase.from('profiles').update({
        'full_name':   _nameCtrl.text.trim(),
        'store_type':  _storeType,
        'market_name': _storeType == 'market' ? _marketName : null,
      }).eq('id', uid);

      // 2) stores таблицасы — магазин аты, контейнер
      //    eq('owner_id', uid) — RLS policy "Seller can update own store" болушу керек
      final storeExists = await supabase
          .from('stores')
          .select('id')
          .eq('owner_id', uid)
          .maybeSingle();

      if (storeExists != null) {
        await supabase.from('stores').update({
          'store_name':       _shopCtrl.text.trim(),
          'container_number': _containerCtrl.text.trim(),
        }).eq('owner_id', uid);
      }

      // 3) profiles'тагы shop_name талаасын дагы жаңырт (SellerModel ошол жерден алат)
      await supabase.from('profiles').update({
        'shop_name': _shopCtrl.text.trim(),
      }).eq('id', uid);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Сакталды!'),
            backgroundColor: Color(0xFF16A34A),
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Ката: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── UI ────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final isDark   = Theme.of(context).brightness == Brightness.dark;
    final bgColor  = isDark ? const Color(0xFF121212) : const Color(0xFFF4F5F7);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back,
              color: isDark ? Colors.white : AppColors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Профилди өзгөртүү',
            style: AppTextStyles.headingMedium.copyWith(
                color: isDark ? Colors.white : AppColors.black)),
      ),
      body: _initLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFD97706)))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildField('Сатуучунун аты', _nameCtrl, isDark),
                  const SizedBox(height: 14),
                  _buildField('Магазиндин аты', _shopCtrl, isDark),
                  const SizedBox(height: 14),
                  _buildField('Контейнер / Жер номери', _containerCtrl, isDark),
                  const SizedBox(height: 24),
                  _buildStoreTypeSelector(isDark),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFD97706),
                        disabledBackgroundColor:
                            const Color(0xFFD97706).withValues(alpha: 0.5),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2.5))
                          : const Text('Сактоо',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }

  Widget _buildStoreTypeSelector(bool isDark) {
    final labelColor = isDark ? Colors.white70 : AppColors.grey600;
    final cardBg     = isDark ? const Color(0xFF1E1E1E) : Colors.white;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Дүкөн түрү',
            style: AppTextStyles.labelMedium.copyWith(color: labelColor)),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: _typeCard('🏪', 'Рынок',      'market',  cardBg, isDark)),
          const SizedBox(width: 12),
          Expanded(child: _typeCard('🏬', 'Жеке дүкөн', 'private', cardBg, isDark)),
        ]),
        if (_storeType == 'market') ...[
          const SizedBox(height: 16),
          Text('Рынок тандаңыз',
              style: AppTextStyles.labelMedium.copyWith(color: labelColor)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.grey300),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _markets.contains(_marketName) ? _marketName : _markets.first,
                isExpanded: true,
                dropdownColor: cardBg,
                items: _markets
                    .map((m) => DropdownMenuItem(
                          value: m,
                          child: Text(m,
                              style: TextStyle(
                                  color: isDark ? Colors.white : AppColors.black)),
                        ))
                    .toList(),
                onChanged: (v) => setState(() => _marketName = v),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _typeCard(
      String icon, String label, String value, Color cardBg, bool isDark) {
    final isSelected = _storeType == value;
    return GestureDetector(
      onTap: () => setState(() => _storeType = value),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFFD97706).withValues(alpha: 0.1)
              : cardBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? const Color(0xFFD97706) : AppColors.grey300,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(icon, style: const TextStyle(fontSize: 26)),
          const SizedBox(height: 6),
          Text(label,
              style: TextStyle(
                fontSize: 13,
                fontWeight:
                    isSelected ? FontWeight.w700 : FontWeight.normal,
                color: isSelected
                    ? const Color(0xFFD97706)
                    : (isDark ? Colors.white70 : AppColors.grey600),
              )),
        ]),
      ),
    );
  }

  Widget _buildField(
      String label, TextEditingController ctrl, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: AppTextStyles.labelMedium.copyWith(
                color: isDark ? Colors.white70 : AppColors.grey600)),
        const SizedBox(height: 6),
        TextField(
          controller: ctrl,
          style:
              TextStyle(color: isDark ? Colors.white : AppColors.black),
          decoration: InputDecoration(
            filled: true,
            fillColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 14),
          ),
        ),
      ],
    );
  }
}