import 'package:flutter/material.dart';
import '../../../config/theme/app_colors.dart';
import '../../../config/theme/app_text_styles.dart';
import '../../../core/supabase_client.dart';
import '../../seller/models/seller_model.dart';
import '../../seller/services/seller_service.dart';
import '../../seller/services/subscription_service.dart';
import '../../map/screens/admin_map_picker_screen.dart';
import 'admin_stats_screen.dart';
import 'admin_story_manager_screen.dart';

class AdminPanelScreen extends StatefulWidget {
  const AdminPanelScreen({super.key});

  @override
  State<AdminPanelScreen> createState() => _AdminPanelScreenState();
}

class _AdminPanelScreenState extends State<AdminPanelScreen>
    with SingleTickerProviderStateMixin {
  final _service = SellerService();
  final _subService = SubscriptionService();
  late TabController _tabController;

  List<SellerModel> _pendingSellers = [];
  List<SellerModel> _approvedSellers = [];
  List<SellerModel> _allSellers = [];
  bool _isLoading = true;

  // ── Издөө ──
  final _searchCtrl = TextEditingController();
  String _searchQuery = '';

  // ── Админдин өз картасы ──
  String? _adminCardMasked;
  // ignore: unused_field
  String? _adminCardToken;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _loadData();
    _loadAdminCard();
    _searchCtrl.addListener(() {
      setState(() => _searchQuery = _searchCtrl.text.toLowerCase().trim());
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  // ── Издөө фильтри ──
  List<SellerModel> get _filteredApproved {
    if (_searchQuery.isEmpty) return _approvedSellers;
    return _approvedSellers
        .where((s) =>
            s.shopName.toLowerCase().contains(_searchQuery) ||
            s.name.toLowerCase().contains(_searchQuery) ||
            s.phone.contains(_searchQuery) ||
            s.containerNumber.toLowerCase().contains(_searchQuery))
        .toList();
  }

  // ══════════════════════════════════════════════════════
  // МААЛЫМАТ ЖҮКТӨӨ
  // ══════════════════════════════════════════════════════

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final all = await _service.getAllSellers();
    setState(() {
      _allSellers = all;
      _pendingSellers =
          all.where((s) => s.status == SellerStatus.pending).toList();
      _approvedSellers = all
          .where((s) =>
              s.status == SellerStatus.approved ||
              s.status == SellerStatus.blocked)
          .toList();
      _isLoading = false;
    });
  }

  Future<void> _loadAdminCard() async {
    try {
      final row = await supabase
          .from('admin_settings')
          .select()
          .eq('key', 'payment')
          .maybeSingle();
      if (row != null) {
        setState(() {
          _adminCardMasked = row['card_masked'] as String?;
          _adminCardToken = row['card_token'] as String?;
        });
      }
    } catch (_) {}
  }

  // ══════════════════════════════════════════════════════
  // SELLER БАШКАРУУ
  // ══════════════════════════════════════════════════════

  Future<void> _approve(SellerModel seller) async {
    await _service.approveSeller(seller.uid);
    _showSnack('✅ ${seller.name} бекитилди!', AppColors.success);
    _loadData();
  }

  Future<void> _reject(SellerModel seller) async {
    await _service.rejectSeller(seller.uid);
    _showSnack('❌ ${seller.name} четке кагылды', AppColors.error);
    _loadData();
  }

  Future<void> _toggleBlock(SellerModel seller) async {
    if (seller.status == SellerStatus.blocked) {
      await _service.unblockSeller(seller.uid);
      _showSnack('🔓 ${seller.name} блоктон чыгарылды', AppColors.success);
    } else {
      await _service.blockSeller(seller.uid);
      _showSnack('🔒 ${seller.name} блоктолду', AppColors.error);
    }
    _loadData();
  }

  Future<void> _delete(SellerModel seller) async {
    final confirm = await _showConfirmDialog(
        '${seller.name} селлерди өчүрөсүзбү?\nБул кайтарылгыс!');
    if (confirm == true) {
      await _service.deleteSeller(seller.uid);
      _showSnack('🗑️ ${seller.name} өчүрүлдү', AppColors.error);
      _loadData();
    }
  }

  Future<void> _markPayment(SellerModel seller, bool paid) async {
    final now = DateTime.now();
    final month = '${now.year}-${now.month.toString().padLeft(2, '0')}';
    if (paid) {
      await _service.markAsPaid(uid: seller.uid, month: month, amount: 2000);
      _showSnack('💰 Төлөм белгиленди', AppColors.success);
    } else {
      await _service.markAsUnpaid(uid: seller.uid, month: month, amount: 2000);
      _showSnack('❌ Төлөм белгиси алынды', AppColors.error);
    }
    _loadData();
  }

  Future<void> _toggleSellerAutoPay(SellerModel seller) async {
    if (seller.autoPayEnabled) {
      final confirm = await _showConfirmDialog(
          '${seller.shopName} дүкөнүнүн авто төлөмүн токтотосузбу?');
      if (confirm != true) return;
      await _subService.cancelAutoPayment(seller.uid);
      _showSnack(
          '⛔ ${seller.shopName} авто төлөмү токтотулду', AppColors.error);
    } else {
      if (!seller.hasCard) {
        _showSnack('❗ Сатуучунун картасы байланган эмес', AppColors.error);
        return;
      }
      await _subService.enableAutoPayment(seller.uid);
      _showSnack(
          '✅ ${seller.shopName} авто төлөмү иштетилди', AppColors.success);
    }
    _loadData();
  }

  Future<void> _openMapPicker(SellerModel seller) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => AdminMapPickerScreen(seller: seller)),
    );
    if (result == true) _loadData();
  }

  Future<void> _editPhone(SellerModel seller) async {
    final ctrl = TextEditingController(text: seller.phone);
    final result = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title:
            const Text('📞 Номер өзгөртүү', style: AppTextStyles.headingSmall),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(hintText: '+996 XXX XXX XXX'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child:
                const Text('Жок', style: TextStyle(color: AppColors.grey500)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, ctrl.text.trim()),
            child: const Text('Сактоо',
                style: TextStyle(color: AppColors.primary)),
          ),
        ],
      ),
    );
    if (result != null && result.isNotEmpty) {
      await _service.updatePhone(seller.uid, result);
      _showSnack('📞 Номер жаңыланды', AppColors.success);
      _loadData();
    }
  }

  Future<void> _editContainer(SellerModel seller) async {
    final ctrl = TextEditingController(text: seller.containerNumber);
    final result = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('🏪 Контейнер №', style: AppTextStyles.headingSmall),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(hintText: 'A-123'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child:
                const Text('Жок', style: TextStyle(color: AppColors.grey500)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, ctrl.text.trim()),
            child: const Text('Сактоо',
                style: TextStyle(color: AppColors.primary)),
          ),
        ],
      ),
    );
    if (result != null) {
      await _service.updateContainer(seller.uid, result);
      _showSnack('🏪 Контейнер жаңыланды', AppColors.success);
      _loadData();
    }
  }

  Future<void> _resetPassword(SellerModel seller) async {
    final ctrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    bool showPass = false;

    final result = await showDialog<String>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setS) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('🔑 Пароль жаңылоо',
                  style: AppTextStyles.headingSmall),
              const SizedBox(height: 4),
              Text(seller.shopName,
                  style: AppTextStyles.labelSmall
                      .copyWith(color: AppColors.grey500)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: ctrl,
                obscureText: !showPass,
                decoration: InputDecoration(
                  hintText: 'Жаңы пароль',
                  filled: true,
                  fillColor: const Color.fromARGB(255, 58, 57, 57),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none),
                  suffixIcon: GestureDetector(
                    onTap: () => setS(() => showPass = !showPass),
                    child: Icon(
                        showPass ? Icons.visibility : Icons.visibility_off,
                        color: AppColors.grey400,
                        size: 20),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: confirmCtrl,
                obscureText: !showPass,
                decoration: InputDecoration(
                  hintText: 'Паролду тастыктаңыз',
                  filled: true,
                  fillColor: const Color.fromARGB(255, 45, 44, 44),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Жокко чыгаруу',
                  style: TextStyle(color: AppColors.grey500)),
            ),
            TextButton(
              onPressed: () {
                final pass = ctrl.text;
                final confirm = confirmCtrl.text;
                final error = SellerService.validatePassword(pass);
                if (error != null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text(error), backgroundColor: AppColors.error),
                  );
                  return;
                }
                if (pass != confirm) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Пароллдор дал келбейт!'),
                        backgroundColor: Colors.red),
                  );
                  return;
                }
                Navigator.pop(context, pass);
              },
              child: const Text('Жаңылоо',
                  style: TextStyle(color: AppColors.primary)),
            ),
          ],
        ),
      ),
    );

    if (result != null && result.isNotEmpty) {
      final success =
          await _service.resetPassword(uid: seller.uid, newPassword: result);
      if (success) {
        _showSnack(
            '🔑 ${seller.shopName} паролу жаңыланды!', AppColors.success);
      } else {
        _showSnack('Ката чыкты, кайра аракет кылыңыз', AppColors.error);
      }
    }
  }

  Future<void> _showSellerProducts(SellerModel s) async {
    final stores =
        await supabase.from('stores').select('id').eq('owner_id', s.uid);
    final storeIds = (stores as List).map((r) => r['id'] as String).toList();

    List<Map<String, dynamic>> products = [];
    if (storeIds.isNotEmpty) {
      final rows = await supabase
          .from('products')
          .select()
          .inFilter('store_id', storeIds);
      products = (rows as List)
          .map((r) => Map<String, dynamic>.from(r as Map))
          .toList();
    }
    final count = products.length;
    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (sheetContext, setSheetState) {
          // ── Издөө ──
          String searchQuery = '';
          // ── Select режими ──
          bool isSelectionMode = false;
          final Set<String> selectedIds = {};

          List<Map<String, dynamic>> filtered = products;

          return StatefulBuilder(
            builder: (ctx, setS) {
              filtered = searchQuery.isEmpty
                  ? products
                  : products
                      .where((p) => (p['title'] as String? ?? '')
                          .toLowerCase()
                          .contains(searchQuery.toLowerCase()))
                      .toList();

              Future<void> deleteSelected() async {
                final confirm = await showDialog<bool>(
                  context: ctx,
                  builder: (dctx) => AlertDialog(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20)),
                    title: const Text('Товарларды өчүрүү',
                        style: AppTextStyles.headingSmall),
                    content: Text(
                        '${selectedIds.length} товар толугу менен өчүрүлөт. Улантасызбы?',
                        style: AppTextStyles.bodyMedium),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(dctx, false),
                        child: const Text('Жок'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(dctx, true),
                        child: const Text('Ооба, өчүрүү',
                            style: TextStyle(color: AppColors.error)),
                      ),
                    ],
                  ),
                );
                if (confirm == true) {
                  await supabase
                      .from('products')
                      .delete()
                      .inFilter('id', selectedIds.toList());
                  setS(() {
                    products.removeWhere((p) => selectedIds.contains(p['id']));
                    selectedIds.clear();
                    isSelectionMode = false;
                  });
                }
              }

              return Container(
                height: MediaQuery.of(context).size.height * 0.75,
                decoration: const BoxDecoration(
                  color: Color.fromARGB(255, 66, 63, 63),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: Column(
                  children: [
                    // ── Башы ──
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                      child: Row(
                        children: [
                          const Text('🏪', style: TextStyle(fontSize: 28)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(s.shopName,
                                    style: AppTextStyles.headingSmall),
                                Text('Жалпы товар: $count шт',
                                    style: AppTextStyles.labelMedium
                                        .copyWith(color: AppColors.primary)),
                              ],
                            ),
                          ),
                          if (isSelectionMode)
                            IconButton(
                              icon: const Icon(Icons.close,
                                  color: AppColors.grey500),
                              onPressed: () => setS(() {
                                isSelectionMode = false;
                                selectedIds.clear();
                              }),
                            )
                          else
                            GestureDetector(
                              onTap: () => Navigator.pop(ctx),
                              child:
                                  const Icon(Icons.close, color: Colors.grey),
                            ),
                        ],
                      ),
                    ),

                    // ── Издөө ──
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: TextField(
                        onChanged: (v) => setS(() => searchQuery = v),
                        style: AppTextStyles.bodyMedium,
                        decoration: InputDecoration(
                          hintText: 'Товар издөө...',
                          hintStyle: AppTextStyles.bodyMedium
                              .copyWith(color: AppColors.grey400),
                          prefixIcon: const Icon(Icons.search,
                              color: AppColors.grey400),
                          filled: true,
                          fillColor: const Color.fromARGB(255, 83, 109, 162),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 10),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),

                    // ── Баарын белгилөө ──
                    if (filtered.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 4),
                        child: Row(
                          children: [
                            Checkbox(
                              value: isSelectionMode &&
                                  selectedIds.length == filtered.length,
                              activeColor: AppColors.primary,
                              onChanged: (_) {
                                setS(() {
                                  isSelectionMode = true;
                                  if (selectedIds.length == filtered.length) {
                                    selectedIds.clear();
                                    isSelectionMode = false;
                                  } else {
                                    selectedIds
                                      ..clear()
                                      ..addAll(filtered
                                          .map((p) => p['id'] as String));
                                  }
                                });
                              },
                            ),
                            const Text('Баарын белгилөө',
                                style: AppTextStyles.labelLarge),
                            const Spacer(),
                            if (isSelectionMode)
                              Text('${selectedIds.length} тандалды',
                                  style: AppTextStyles.labelSmall
                                      .copyWith(color: AppColors.grey500)),
                          ],
                        ),
                      ),

                    const Divider(height: 1),

                    // ── Товарлар тизмеси ──
                    Expanded(
                      child: filtered.isEmpty
                          ? const Center(
                              child: Text('Товар жок',
                                  style: AppTextStyles.bodyMedium))
                          : ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: filtered.length,
                              itemBuilder: (_, i) {
                                final d = filtered[i];
                                final id = d['id'] as String;
                                final isSelected = selectedIds.contains(id);

                                return GestureDetector(
                                  onLongPress: () {
                                    setS(() {
                                      isSelectionMode = true;
                                      selectedIds.add(id);
                                    });
                                  },
                                  onTap: isSelectionMode
                                      ? () {
                                          setS(() {
                                            if (isSelected) {
                                              selectedIds.remove(id);
                                              if (selectedIds.isEmpty) {
                                                isSelectionMode = false;
                                              }
                                            } else {
                                              selectedIds.add(id);
                                            }
                                          });
                                        }
                                      : null,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? AppColors.primary
                                              .withValues(alpha: 0.08)
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: ListTile(
                                      leading: isSelectionMode
                                          ? Icon(
                                              isSelected
                                                  ? Icons.check_circle_rounded
                                                  : Icons
                                                      .radio_button_unchecked,
                                              color: isSelected
                                                  ? AppColors.primary
                                                  : const Color.fromARGB(255, 23, 61, 117),
                                            )
                                          : const Text('📦',
                                              style: TextStyle(fontSize: 24)),
                                      title: Text(d['title'] as String? ?? '',
                                          style: AppTextStyles.labelMedium),
                                      subtitle: Text(
                                          '${d['price'] ?? 0} с  •  ${d['in_stock'] ?? 0} шт',
                                          style: AppTextStyles.labelSmall
                                              .copyWith(
                                                  color: AppColors.grey500)),
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),

                    // ── Өчүрүү баскычы ──
                    if (isSelectionMode && selectedIds.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                        decoration: BoxDecoration(
                          color: const Color.fromARGB(255, 156, 49, 49),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.06),
                              blurRadius: 12,
                              offset: const Offset(0, -4),
                            ),
                          ],
                        ),
                        child: SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            onPressed: deleteSelected,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.error,
                              foregroundColor: const Color.fromARGB(255, 61, 192, 116),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14)),
                              elevation: 0,
                            ),
                            child: Text(
                              '🗑️ Тандалган товарларды өчүрүү (${selectedIds.length})',
                              style: AppTextStyles.labelLarge
                                  .copyWith(color: const Color.fromARGB(255, 43, 61, 196)),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  // ══════════════════════════════════════════════════════
  // ADMIN КАРТАСЫ
  // ══════════════════════════════════════════════════════

  void _showAdminCardSheet() {
    final cardCtrl = TextEditingController();
    final expCtrl = TextEditingController();
    final cvvCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color.fromARGB(255, 181, 46, 46),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 24,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text('🏦', style: TextStyle(fontSize: 28)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Admin картасы',
                            style: AppTextStyles.headingSmall),
                        Text(
                          'Сатуучулардан акча ушул картага түшөт',
                          style: AppTextStyles.bodySmall
                              .copyWith(color: AppColors.grey500),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (_adminCardMasked != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color.fromARGB(255, 37, 155, 86),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: AppColors.success.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.credit_card,
                          color: AppColors.success, size: 20),
                      const SizedBox(width: 8),
                      Text(_adminCardMasked!,
                          style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              color: AppColors.success,
                              fontSize: 16)),
                      const SizedBox(width: 6),
                      Text('байланган',
                          style: AppTextStyles.bodySmall
                              .copyWith(color: AppColors.grey500)),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 20),
              TextField(
                controller: cardCtrl,
                keyboardType: TextInputType.number,
                maxLength: 19,
                decoration: _inputDec(
                  _adminCardMasked != null
                      ? 'Жаңы карта (алмаштыруу)'
                      : 'Карта номери',
                  '0000 0000 0000 0000',
                ),
                onChanged: (v) {
                  final digits = v.replaceAll(' ', '');
                  final formatted = digits
                      .replaceAllMapped(
                          RegExp(r'.{1,4}'), (m) => '${m.group(0)} ')
                      .trim();
                  cardCtrl.value = TextEditingValue(
                    text: formatted,
                    selection:
                        TextSelection.collapsed(offset: formatted.length),
                  );
                  setS(() {});
                },
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: expCtrl,
                      keyboardType: TextInputType.number,
                      maxLength: 5,
                      decoration: _inputDec('Мөөнөтү', 'MM/YY'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: cvvCtrl,
                      keyboardType: TextInputType.number,
                      maxLength: 3,
                      obscureText: true,
                      decoration: _inputDec('CVV', '•••'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: cardCtrl.text.replaceAll(' ', '').length == 16
                      ? () => _saveAdminCard(cardCtrl.text, ctx)
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1E40AF),
                    disabledBackgroundColor: const Color.fromARGB(255, 86, 136, 236),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(
                    _adminCardMasked != null
                        ? '🔄  Картаны алмаштыруу'
                        : '✅  Картаны сактоо',
                    style: const TextStyle(
                        color: Color.fromARGB(255, 226, 47, 47), fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              if (_adminCardMasked != null) ...[
                const SizedBox(height: 8),
                Center(
                  child: TextButton(
                    onPressed: () => _removeAdminCard(ctx),
                    child: const Text('Картаны өчүрүү',
                        style:
                            TextStyle(color: AppColors.grey500, fontSize: 13)),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _saveAdminCard(String cardNumber, BuildContext ctx) async {
    Navigator.pop(ctx);
    final digits = cardNumber.replaceAll(' ', '');
    if (digits.length < 16) return;  
    final masked = '•••• ${digits.substring(12)}';
    await supabase.from('admin_settings').upsert({
      'key': 'payment',
      'card_token': 'admin_token_${digits.substring(12)}',
      'card_masked': masked,
      'updated_at': DateTime.now().toIso8601String(),
    });
    setState(() {
      _adminCardMasked = masked;
      _adminCardToken = 'admin_token_${digits.substring(12)}';
    });
    if (mounted) _showSnack('✅ Admin картасы сакталды!', AppColors.success);
  }

  Future<void> _removeAdminCard(BuildContext ctx) async {
    Navigator.pop(ctx);
    await supabase.from('admin_settings').update({
      'card_token': null,
      'card_masked': null,
    }).eq('key', 'payment');
    setState(() {
      _adminCardMasked = null;
      _adminCardToken = null;
    });
    if (mounted) _showSnack('🗑️ Admin картасы өчүрүлдү', AppColors.grey600);
  }

  // ══════════════════════════════════════════════════════
  // ТОВАР ФУНКЦИЯЛАРЫ
  // ══════════════════════════════════════════════════════

  Future<void> _deleteProduct(Map<String, dynamic> product) async {
    final name = product['title'] as String? ?? 'Товар';
    final confirm = await _showConfirmDialog(
        '"$name" товарды толугу менен өчүрөсүзбү?\nБул кайтарылгыс!');
    if (confirm == true) {
      await supabase
          .from('products')
          .delete()
          .eq('id', product['id'] as String);
      _showSnack('🗑️ "$name" өчүрүлдү', AppColors.error);
    }
  }

  Future<void> _toggleBlockProduct(Map<String, dynamic> product) async {
    final id = product['id'] as String;
    final name = product['title'] as String? ?? 'Товар';
    final isBlocked = product['is_blocked'] as bool? ?? false;
    await supabase
        .from('products')
        .update({'is_blocked': !isBlocked}).eq('id', id);
    _showSnack(
      isBlocked ? '🔓 "$name" блоктон чыгарылды' : '🔒 "$name" блоктолду',
      isBlocked ? AppColors.success : AppColors.error,
    );
  }

  // ══════════════════════════════════════════════════════
  // BUILD
  // ══════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 96, 127, 189),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E40AF),
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Row(
          children: [
            const Text('🛡️', style: TextStyle(fontSize: 22)),
            const SizedBox(width: 8),
            Text('Admin панели',
                style:
                    AppTextStyles.headingMedium.copyWith(color: const Color.fromARGB(255, 196, 133, 133))),
          ],
        ),
        actions: [
          GestureDetector(
            onTap: _showAdminCardSheet,
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: _adminCardMasked != null
                    ? const Color.fromARGB(255, 192, 159, 159).withValues(alpha: 0.2)
                    : AppColors.error.withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.credit_card, color: Color.fromARGB(255, 185, 135, 135), size: 16),
                  const SizedBox(width: 4),
                  Text(
                    _adminCardMasked ?? 'Карта жок',
                    style: const TextStyle(
                        color: Color.fromARGB(255, 102, 183, 172),
                        fontSize: 12,
                        fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ),


          



GestureDetector(
  onTap: () => Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => const AdminStoryManagerScreen()),
  ),
  child: const Padding(
    padding: EdgeInsets.only(right: 4),
    child: Icon(Icons.auto_stories_rounded,
        color: Color(0xFFD97706), size: 24),
  ),
),









          GestureDetector(
  onTap: () => Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => const AdminStatsScreen()),
  ),


  child: const Padding(
    padding: EdgeInsets.only(right: 8),
    child: Icon(Icons.bar_chart_rounded, color: Color.fromARGB(255, 44, 131, 185), size: 24),
  ),
),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color.fromARGB(255, 184, 125, 125),
          labelColor: const Color.fromARGB(255, 222, 137, 137),
          unselectedLabelColor: Colors.white60,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: [
            Tab(text: '⏳ Өтүнүчтөр (${_pendingSellers.length})'),
            Tab(text: '✅ Sellerлер (${_approvedSellers.length})'),
            Tab(text: '👥 Баары (${_allSellers.length})'),
            const Tab(text: '📦 Товарлар'),
            const Tab(text: '💳 Төлөмдөр'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildPendingTab(),
                _buildApprovedTab(),
                _buildAllTab(),
                _buildProductsTab(),
                _buildPaymentsTab(),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _loadData,
        backgroundColor: const Color(0xFF1E40AF),
        child: const Icon(Icons.refresh, color: Color.fromARGB(255, 212, 108, 108)),
      ),
    );
  }

  // ══════════════════════════════════════════════════════
  // ⏳ ӨТҮНҮЧТӨР TAB
  // ══════════════════════════════════════════════════════

  Widget _buildPendingTab() {
    if (_pendingSellers.isEmpty) {
      return _buildEmpty('⏳', 'Күтүүдөгү өтүнүч жок');
    }
    return ListView.builder(
      padding: const EdgeInsets.all(14),
      itemCount: _pendingSellers.length,
      itemBuilder: (_, i) => _buildRequestCard(_pendingSellers[i]),
    );
  }

  Widget _buildRequestCard(SellerModel s) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color.fromARGB(255, 210, 171, 171),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                    color: const Color.fromARGB(255, 200, 173, 143),
                    borderRadius: BorderRadius.circular(12)),
                child: const Center(
                    child: Text('🏪', style: TextStyle(fontSize: 24))),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(s.shopName, style: AppTextStyles.labelLarge),
                    Text(s.name,
                        style: AppTextStyles.labelSmall
                            .copyWith(color: AppColors.grey500)),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                    color: const Color.fromARGB(255, 203, 171, 134),
                    borderRadius: BorderRadius.circular(20)),
                child: const Text('⏳ Жаңы',
                    style: TextStyle(fontSize: 12, color: AppColors.primary)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(s.phone,
              style:
                  AppTextStyles.labelSmall.copyWith(color: AppColors.grey500)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => _reject(s),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                        color: const Color.fromARGB(255, 247, 91, 91),
                        borderRadius: BorderRadius.circular(10)),
                    child: Center(
                        child: Text('❌  Четке кагуу',
                            style: AppTextStyles.labelMedium
                                .copyWith(color: AppColors.error))),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: GestureDetector(
                  onTap: () => _approve(s),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                        color: const Color.fromARGB(255, 50, 221, 122),
                        borderRadius: BorderRadius.circular(10)),
                    child: Center(
                        child: Text('✅  Бекитүү',
                            style: AppTextStyles.labelMedium
                                .copyWith(color: AppColors.success))),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════
  // ✅ SELLERЛЕР TAB — ИЗДӨӨ МЕНЕН
  // ══════════════════════════════════════════════════════

  Widget _buildApprovedTab() {
    final list = _filteredApproved;
    return Column(
      children: [
        // ── Издөө талаасы ──
        Container(
          color: const Color.fromARGB(255, 141, 136, 175),
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
          child: TextField(
            controller: _searchCtrl,
            style: const TextStyle(fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Дүкөн аты, номер, контейнер...',
              hintStyle: TextStyle(color: AppColors.grey400, fontSize: 14),
              prefixIcon:
                  const Icon(Icons.search, color: AppColors.grey400, size: 20),
              suffixIcon: _searchQuery.isNotEmpty
                  ? GestureDetector(
                      onTap: () => _searchCtrl.clear(),
                      child: const Icon(Icons.close,
                          color: Color.fromARGB(255, 5, 13, 28), size: 18),
                    )
                  : null,
              filled: true,
              fillColor: const Color.fromARGB(255, 227, 231, 239),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        // ── Натыйжа саны ──
        if (_searchQuery.isNotEmpty)
          Container(
            color: const Color.fromARGB(255, 244, 236, 236),
            padding: const EdgeInsets.only(left: 14, bottom: 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Табылды: ${list.length} seller',
                style:
                    AppTextStyles.labelSmall.copyWith(color: const Color.fromARGB(255, 47, 99, 201)),
              ),
            ),
          ),
        // ── Тизме ──
        Expanded(
          child: list.isEmpty
              ? _buildEmpty(
                  _searchQuery.isNotEmpty ? '🔍' : '✅',
                  _searchQuery.isNotEmpty
                      ? '"$_searchQuery" табылган жок'
                      : 'Seller жок',
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(14),
                  itemCount: list.length,
                  itemBuilder: (_, i) => _buildSellerCard(list[i]),
                ),
        ),
      ],
    );
  }

  Widget _buildSellerCard(SellerModel s) {
    final paid = s.currentMonthPaid;
    final isBlocked = s.status == SellerStatus.blocked;

    return GestureDetector(
      onTap: () => _showSellerProducts(s),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color.fromARGB(255, 188, 173, 173),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isBlocked
                ? Colors.grey.withValues(alpha: 0.4)
                : paid
                    ? AppColors.success.withValues(alpha: 0.3)
                    : AppColors.error.withValues(alpha: 0.3),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 8,
                offset: const Offset(0, 2))
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: isBlocked
                        ? const Color(0xFFF0F0F0)
                        : const Color(0xFFFFF8F0),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(
                      isBlocked
                          ? '🔒'
                          : (s.shopName.isNotEmpty
                              ? s.shopName[0].toUpperCase()
                              : '🏪'),
                      style: TextStyle(
                          fontSize: isBlocked ? 22 : 18,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s.shopName, style: AppTextStyles.labelLarge),
                      Text(s.name,
                          style: AppTextStyles.labelSmall
                              .copyWith(color: AppColors.grey500)),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _statusBadge(s.status),
                    const SizedBox(height: 4),
                    if (s.hasCard)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: s.autoPayEnabled
                              ? const Color.fromARGB(255, 24, 34, 28)
                              : const Color.fromARGB(255, 211, 187, 187),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          s.autoPayEnabled ? '🔄 Авто' : '⏸ Токтоп',
                          style: TextStyle(
                            fontSize: 10,
                            color: s.autoPayEnabled
                                ? AppColors.success
                                : AppColors.grey500,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              s.containerNumber.isNotEmpty
                  ? s.containerNumber
                  : 'Контейнер жок',
              style: AppTextStyles.labelSmall.copyWith(
                color: s.containerNumber.isEmpty
                    ? AppColors.error
                    : AppColors.grey600,
              ),
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (!isBlocked)
                  _actionButton(
                    label: paid ? '❌ Төлөм алып салуу' : '💰 Төлөдү',
                    color: paid ? AppColors.error : AppColors.success,
                    bgColor: paid
                        ? const Color.fromARGB(255, 255, 253, 253)
                        : const Color(0xFFEEFFF5),
                    onTap: () => _markPayment(s, !paid),
                  ),
                _actionButton(
                  label: '📞 Номер',
                  color: AppColors.primary,
                  bgColor: const Color.fromARGB(255, 211, 179, 179),
                  onTap: () => _editPhone(s),
                ),
                _actionButton(
                  label: '🏪 Контейнер',
                  color: const Color(0xFF7C3AED),
                  bgColor: const Color.fromARGB(255, 123, 103, 222),
                  onTap: () => _editContainer(s),
                ),
                _actionButton(
                  label: s.hasLocation ? '📍 Локация бар' : '📍 Локация кошуу',
                  color: s.hasLocation
                      ? AppColors.success
                      : const Color(0xFF7C3AED),
                  bgColor: s.hasLocation
                      ? const Color(0xFFEEFFF5)
                      : const Color(0xFFF5F3FF),
                  onTap: () => _openMapPicker(s),
                ),
                _actionButton(
                  label: '🔑 Пароль',
                  color: const Color(0xFF0369A1),
                  bgColor: const Color(0xFFE0F2FE),
                  onTap: () => _resetPassword(s),
                ),
                if (s.hasCard)
                  _actionButton(
                    label: s.autoPayEnabled
                        ? '⛔ Авто токтотуу'
                        : '▶️ Авто иштетүү',
                    color:
                        s.autoPayEnabled ? AppColors.error : AppColors.success,
                    bgColor: s.autoPayEnabled
                        ? const Color(0xFFFFEEEE)
                        : const Color(0xFFEEFFF5),
                    onTap: () => _toggleSellerAutoPay(s),
                  ),
                _actionButton(
                  label: isBlocked ? '🔓 Блоктон чыгаруу' : '🔒 Блоктоо',
                  color: isBlocked ? AppColors.success : AppColors.error,
                  bgColor: isBlocked
                      ? const Color(0xFFEEFFF5)
                      : const Color(0xFFFFEEEE),
                  onTap: () => _toggleBlock(s),
                ),
                _actionButton(
                  label: '🗑️ Өчүрүү',
                  color: AppColors.error,
                  bgColor: const Color(0xFFFFEEEE),
                  onTap: () => _delete(s),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════
  // 👥 БААРЫ TAB
  // ══════════════════════════════════════════════════════

  Widget _buildAllTab() {
    if (_allSellers.isEmpty) return _buildEmpty('👥', 'Seller жок');
    return ListView.builder(
      padding: const EdgeInsets.all(14),
      itemCount: _allSellers.length,
      itemBuilder: (_, i) {
        final s = _allSellers[i];
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color.fromARGB(255, 19, 16, 16),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 6,
                  offset: const Offset(0, 2))
            ],
          ),
          child: Row(
            children: [
              const Text('🏪', style: TextStyle(fontSize: 24)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(s.shopName, style: AppTextStyles.labelLarge),
                    Text(s.phone,
                        style: AppTextStyles.labelSmall
                            .copyWith(color: AppColors.grey500)),
                  ],
                ),
              ),
              _statusBadge(s.status),
            ],
          ),
        );
      },
    );
  }

  // ══════════════════════════════════════════════════════
  // 📦 ТОВАРЛАР TAB
  // ══════════════════════════════════════════════════════

  Widget _buildProductsTab() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: supabase
          .from('products')
          .stream(primaryKey: ['id']).order('created_at', ascending: false),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(color: AppColors.primary));
        }
        if (snap.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text('Маалымат жүктөлбөдү.\n${snap.error}',
                  style: AppTextStyles.bodyMedium, textAlign: TextAlign.center),
            ),
          );
        }
        final products = snap.data ?? [];
        if (products.isEmpty) return _buildEmpty('📦', 'Товар жок');

        final blocked = products.where((p) => p['is_blocked'] == true).toList();
        final active = products.where((p) => p['is_blocked'] != true).toList();
        final sorted = [...blocked, ...active];

        return Column(
          children: [
            Container(
              color: const Color.fromARGB(255, 81, 70, 70),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  _statChip('Баары: ${products.length}', AppColors.primary),
                  const SizedBox(width: 8),
                  _statChip('Актив: ${active.length}', AppColors.success),
                  const SizedBox(width: 8),
                  _statChip('Блок: ${blocked.length}', AppColors.error),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: sorted.length,
                itemBuilder: (_, i) => _buildProductCard(sorted[i]),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildProductCard(Map<String, dynamic> product) {
    final name = product['title'] as String? ?? 'Аты жок';
    final price = (product['price'] as num?)?.toDouble() ?? 0;
    final isBlocked = product['is_blocked'] as bool? ?? false;
    final inStock = (product['in_stock'] as num?)?.toInt() ?? 0;
    final images = product['images'] as List<dynamic>? ?? [];
    final imageUrl = images.isNotEmpty ? images.first as String : '';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: const Color.fromARGB(255, 159, 146, 146),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isBlocked
              ? AppColors.error.withValues(alpha: 0.4)
              : const Color.fromARGB(255, 189, 193, 202),
          width: isBlocked ? 1.5 : 1,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: imageUrl.isNotEmpty
              ? Image.network(
                  imageUrl,
                  width: 46,
                  height: 46,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    width: 46,
                    height: 46,
                    color: isBlocked
                        ? const Color.fromARGB(255, 40, 212, 192)
                        : const Color(0xFFFFF8F0),
                    child: Center(
                      child: Text(isBlocked ? '🔒' : '📦',
                          style: const TextStyle(fontSize: 22)),
                    ),
                  ),
                )
              : Container(
                  width: 46,
                  height: 46,
                  color: isBlocked
                      ? const Color(0xFFFFEEEE)
                      : const Color(0xFFFFF8F0),
                  child: Center(
                    child: Text(isBlocked ? '🔒' : '📦',
                        style: const TextStyle(fontSize: 22)),
                  ),
                ),
        ),
        title: Text(name, style: AppTextStyles.labelLarge),
        subtitle: Text('${price.toInt()} с • $inStock шт',
            style: AppTextStyles.labelSmall.copyWith(color: AppColors.grey500)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            GestureDetector(
              onTap: () => _toggleBlockProduct(product),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: isBlocked
                      ? const Color.fromARGB(255, 36, 36, 36)
                      : const Color.fromARGB(255, 156, 214, 234),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  isBlocked ? '🔓 Ачуу' : '🔒 Блоктоо',
                  style: AppTextStyles.labelSmall.copyWith(
                      color: isBlocked ? AppColors.success : AppColors.error),
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => _deleteProduct(product),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                    color: const Color.fromARGB(255, 101, 61, 61),
                    borderRadius: BorderRadius.circular(8)),
                child: Text('🗑️',
                    style: AppTextStyles.labelSmall
                        .copyWith(color: AppColors.error)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════
  // 💳 ТӨЛӨМДӨР TAB
  // ══════════════════════════════════════════════════════

  Widget _buildPaymentsTab() {
    final now = DateTime.now();
    final currentMonth = '${now.year}-${now.month.toString().padLeft(2, '0')}';
    final paid = _approvedSellers.where((s) => s.currentMonthPaid).toList();
    final unpaid = _approvedSellers
        .where((s) => !s.currentMonthPaid && s.status == SellerStatus.approved)
        .toList();
    final totalExpected = _approvedSellers
            .where((s) => s.status == SellerStatus.approved)
            .length *
        2000;
    final totalReceived = paid.length * 2000;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1E40AF), Color(0xFF3B82F6)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$currentMonth — Ай статистикасы',
                    style:
                        const TextStyle(color: Colors.white70, fontSize: 13)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                        child: _payStatCard(
                            'Түштү', '$totalReceived сом', AppColors.success)),
                    const SizedBox(width: 10),
                    Expanded(
                        child: _payStatCard(
                            'Күтүлөт', '$totalExpected сом', Colors.white70)),
                    const SizedBox(width: 10),
                    Expanded(
                        child: _payStatCard('Карызда',
                            '${unpaid.length} seller', AppColors.error)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          GestureDetector(
            onTap: _showAdminCardSheet,
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: _adminCardMasked != null
                      ? AppColors.success.withValues(alpha: 0.4)
                      : AppColors.error.withValues(alpha: 0.4),
                ),
              ),
              child: Row(
                children: [
                  const Text('🏦', style: TextStyle(fontSize: 26)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Менин картам (кириш)',
                            style: AppTextStyles.labelLarge),
                        Text(
                          _adminCardMasked ??
                              'Карта байланган эмес — басып кошуңуз',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: _adminCardMasked != null
                                ? AppColors.success
                                : AppColors.error,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.arrow_forward_ios,
                      size: 16, color: AppColors.grey400),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          if (paid.isNotEmpty) ...[
            Text('✅ Төлөгөндөр (${paid.length})',
                style: AppTextStyles.headingSmall),
            const SizedBox(height: 10),
            ...paid.map((s) => _buildPaymentRow(s, true)),
            const SizedBox(height: 16),
          ],
          if (unpaid.isNotEmpty) ...[
            Text('❌ Төлөбөгөндөр (${unpaid.length})',
                style: AppTextStyles.headingSmall),
            const SizedBox(height: 10),
            ...unpaid.map((s) => _buildPaymentRow(s, false)),
          ],
        ],
      ),
    );
  }

  Widget _payStatCard(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(color: Colors.white70, fontSize: 11)),
          const SizedBox(height: 4),
          Text(value,
              style: TextStyle(
                  color: color, fontSize: 13, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildPaymentRow(SellerModel s, bool paid) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: paid
              ? AppColors.success.withValues(alpha: 0.3)
              : AppColors.error.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Text(paid ? '✅' : '❌', style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s.shopName, style: AppTextStyles.labelMedium),
                Row(
                  children: [
                    Text(s.phone,
                        style: AppTextStyles.labelSmall
                            .copyWith(color: AppColors.grey500)),
                    if (s.hasCard) ...[
                      const SizedBox(width: 6),
                      Text(
                        s.autoPayEnabled ? '🔄 Авто' : '⏸ Авто токтоп',
                        style: TextStyle(
                          fontSize: 10,
                          color: s.autoPayEnabled
                              ? AppColors.success
                              : AppColors.grey400,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          if (s.hasCard)
            GestureDetector(
              onTap: () => _toggleSellerAutoPay(s),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                  color: s.autoPayEnabled
                      ? const Color(0xFFFFEEEE)
                      : const Color(0xFFEEFFF5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  s.autoPayEnabled ? '⛔ Токтот' : '▶️ Иштет',
                  style: TextStyle(
                    fontSize: 11,
                    color:
                        s.autoPayEnabled ? AppColors.error : AppColors.success,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: () => _markPayment(s, !paid),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              decoration: BoxDecoration(
                color: paid ? const Color(0xFFFFEEEE) : const Color(0xFFEEFFF5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                paid ? 'Алып сал' : 'Төлөдү',
                style: TextStyle(
                  fontSize: 11,
                  color: paid ? AppColors.error : AppColors.success,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════
  // ЖАРДАМЧЫ WIDGETS
  // ══════════════════════════════════════════════════════

  Widget _statusBadge(SellerStatus status) {
    String text;
    Color color;
    Color bg;
    switch (status) {
      case SellerStatus.pending:
        text = '⏳ Күтүүдө';
        color = AppColors.primary;
        bg = const Color(0xFFFFF8F0);
      case SellerStatus.approved:
        text = '✅ Активдүү';
        color = AppColors.success;
        bg = const Color(0xFFEEFFF5);
      case SellerStatus.rejected:
        text = '❌ Четке';
        color = AppColors.error;
        bg = const Color(0xFFFFEEEE);
      case SellerStatus.blocked:
        text = '🔒 Блок';
        color = AppColors.grey500;
        bg = const Color(0xFFF0F0F0);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(text, style: AppTextStyles.labelSmall.copyWith(color: color)),
    );
  }

  Widget _actionButton({
    required String label,
    required Color color,
    required Color bgColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
            color: bgColor, borderRadius: BorderRadius.circular(10)),
        child:
            Text(label, style: AppTextStyles.labelSmall.copyWith(color: color)),
      ),
    );
  }

  Widget _statChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20)),
      child:
          Text(label, style: AppTextStyles.labelSmall.copyWith(color: color)),
    );
  }

  Widget _buildEmpty(String icon, String text) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(icon, style: const TextStyle(fontSize: 64)),
          const SizedBox(height: 16),
          Text(text,
              style: AppTextStyles.headingSmall
                  .copyWith(color: AppColors.grey400)),
        ],
      ),
    );
  }

  InputDecoration _inputDec(String label, String hint) => InputDecoration(
        labelText: label,
        hintText: hint,
        counterText: '',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      );

  void _showSnack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: color),
    );
  }

  Future<bool?> _showConfirmDialog(String message) {
    return showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Ырастоо', style: AppTextStyles.headingSmall),
        content: Text(message, style: AppTextStyles.bodyMedium),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child:
                const Text('Жок', style: TextStyle(color: AppColors.grey500)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Ооба', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }
}
