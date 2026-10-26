import 'package:flutter/material.dart';
import '../../../config/theme/app_colors.dart';
import '../../../config/theme/app_text_styles.dart';
import '../../../core/supabase_client.dart';
import '../../seller/models/seller_model.dart';
import '../../seller/services/seller_service.dart';
import '../../seller/services/subscription_service.dart';
import 'admin_chat_with_seller.dart';
import '../../map/screens/admin_map_picker_screen.dart';
import 'admin_stats_screen.dart';
import 'admin_story_manager_screen.dart';
import 'admin_seller_stats_screen.dart';
import 'admin_phone_requests_screen.dart';
import '../widgets/admin_notification_sender.dart';
import 'admin_complaints_screen.dart';

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
  List<Map<String, dynamic>> _phoneRequests = []; 
  bool _isLoading = true;

  final _searchCtrl = TextEditingController();
  String _searchQuery = '';

  // Билдирүүлөр издөө
  final _notifSearchCtrl = TextEditingController();
  String _notifQuery = '';

  String? _adminCardMasked;
  // ignore: unused_field
  String? _adminCardToken;
  

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 7, vsync: this);
    _loadData();
    _loadAdminCard();
    _searchCtrl.addListener(() {
      setState(() => _searchQuery = _searchCtrl.text.toLowerCase().trim());
    });
    _notifSearchCtrl.addListener(() {
      setState(() => _notifQuery = _notifSearchCtrl.text.toLowerCase().trim());
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchCtrl.dispose();
    _notifSearchCtrl.dispose();
    super.dispose();
  }

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

  // ── Номер өзгөртүү өтүнүчтөрү ──
  final phoneReqs = await supabase
      .from('phone_change_requests')
      .select()
      .order('created_at', ascending: false);

  setState(() {
    _allSellers      = all;
    _pendingSellers  = all.where((s) => s.status == SellerStatus.pending).toList();
    _approvedSellers = all.where((s) =>
        s.status == SellerStatus.approved ||
        s.status == SellerStatus.blocked).toList();
    _phoneRequests   = (phoneReqs as List).cast<Map<String, dynamic>>();
    _isLoading       = false;
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
      _showSnack('⛔ ${seller.shopName} авто төлөмү токтотулду', AppColors.error);
    } else {
      if (!seller.hasCard) {
        _showSnack('❗ Сатуучунун картасы байланган эмес', AppColors.error);
        return;
      }
      await _subService.enableAutoPayment(seller.uid);
      _showSnack('✅ ${seller.shopName} авто төлөмү иштетилди', AppColors.success);
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
        title: const Text('📞 Номер өзгөртүү', style: AppTextStyles.headingSmall),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(hintText: '+996 XXX XXX XXX'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Жок', style: TextStyle(color: AppColors.grey500)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, ctrl.text.trim()),
            child: const Text('Сактоо', style: TextStyle(color: AppColors.primary)),
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
            child: const Text('Жок', style: TextStyle(color: AppColors.grey500)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, ctrl.text.trim()),
            child: const Text('Сактоо', style: TextStyle(color: AppColors.primary)),
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
        builder: (context, setS) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          final fieldColor = isDark ? const Color(0xFF2C2C2C) : const Color(0xFFF3F4F6);
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('🔑 Пароль жаңылоо', style: AppTextStyles.headingSmall),
                const SizedBox(height: 4),
                Text(seller.shopName,
                    style: AppTextStyles.labelSmall.copyWith(color: AppColors.grey500)),
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
                    fillColor: fieldColor,
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
                    fillColor: fieldColor,
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
                      SnackBar(content: Text(error), backgroundColor: AppColors.error),
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
                child: const Text('Жаңылоо', style: TextStyle(color: AppColors.primary)),
              ),
            ],
          );
        },
      ),
    );

    if (result != null && result.isNotEmpty) {
      final success = await _service.resetPassword(uid: seller.uid, newPassword: result);
      if (success) {
        _showSnack('🔑 ${seller.shopName} паролу жаңыланды!', AppColors.success);
      } else {
        _showSnack('Ката чыкты, кайра аракет кылыңыз', AppColors.error);
      }
    }
  }

  Future<void> _showSellerProducts(SellerModel s) async {
    final stores = await supabase.from('stores').select('id').eq('owner_id', s.uid);
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
          String searchQuery = '';
          bool isSelectionMode = false;
          final Set<String> selectedIds = {};
          List<Map<String, dynamic>> filtered = products;

          return StatefulBuilder(
            builder: (ctx, setS) {
              final isDark = Theme.of(ctx).brightness == Brightness.dark;
              final sheetBg   = isDark ? const Color(0xFF1E1E1E) : Colors.white;
              final fieldFill = isDark ? const Color(0xFF2C2C2C) : AppColors.grey100;
              final textColor = isDark ? Colors.white : AppColors.black;

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
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    title: const Text('Товарларды өчүрүү', style: AppTextStyles.headingSmall),
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
                decoration: BoxDecoration(
                  color: sheetBg,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: Column(
                  children: [
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
                                    style: AppTextStyles.headingSmall
                                        .copyWith(color: textColor)),
                                Text('Жалпы товар: $count шт',
                                    style: AppTextStyles.labelMedium
                                        .copyWith(color: AppColors.primary)),
                              ],
                            ),
                          ),
                          if (isSelectionMode)
                            IconButton(
                              icon: const Icon(Icons.close, color: AppColors.grey500),
                              onPressed: () => setS(() {
                                isSelectionMode = false;
                                selectedIds.clear();
                              }),
                            )
                          else
                            GestureDetector(
                              onTap: () => Navigator.pop(ctx),
                              child: Icon(Icons.close,
                                  color: isDark ? AppColors.grey400 : AppColors.grey600),
                            ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: TextField(
                        onChanged: (v) => setS(() => searchQuery = v),
                        style: AppTextStyles.bodyMedium.copyWith(color: textColor),
                        decoration: InputDecoration(
                          hintText: 'Товар издөө...',
                          hintStyle: AppTextStyles.bodyMedium
                              .copyWith(color: AppColors.grey400),
                          prefixIcon: const Icon(Icons.search, color: AppColors.grey400),
                          filled: true,
                          fillColor: fieldFill,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 10),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                    if (filtered.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
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
                                      ..addAll(filtered.map((p) => p['id'] as String));
                                  }
                                });
                              },
                            ),
                            Text('Баарын белгилөө',
                                style: AppTextStyles.labelLarge.copyWith(color: textColor)),
                            const Spacer(),
                            if (isSelectionMode)
                              Text('${selectedIds.length} тандалды',
                                  style: AppTextStyles.labelSmall
                                      .copyWith(color: AppColors.grey500)),
                          ],
                        ),
                      ),
                    Divider(height: 1, color: isDark ? const Color(0xFF2C2C2C) : AppColors.grey200),
                    Expanded(
                      child: filtered.isEmpty
                          ? Center(
                              child: Text('Товар жок',
                                  style: AppTextStyles.bodyMedium.copyWith(color: textColor)))
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
                                          ? AppColors.primary.withValues(alpha: 0.08)
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: ListTile(
                                      leading: isSelectionMode
                                          ? Icon(
                                              isSelected
                                                  ? Icons.check_circle_rounded
                                                  : Icons.radio_button_unchecked,
                                              color: isSelected
                                                  ? AppColors.primary
                                                  : AppColors.grey400,
                                            )
                                          : const Text('📦',
                                              style: TextStyle(fontSize: 24)),
                                      title: Text(d['title'] as String? ?? '',
                                          style: AppTextStyles.labelMedium
                                              .copyWith(color: textColor)),
                                      subtitle: Text(
                                          '${d['price'] ?? 0} с  •  ${d['in_stock'] ?? 0} шт',
                                          style: AppTextStyles.labelSmall
                                              .copyWith(color: AppColors.grey500)),
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                    if (isSelectionMode && selectedIds.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF2C1010) : const Color(0xFFFFEEEE),
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
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14)),
                              elevation: 0,
                            ),
                            child: Text(
                              '🗑️ Тандалган товарларды өчүрүү (${selectedIds.length})',
                              style: AppTextStyles.labelLarge.copyWith(color: Colors.white),
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
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) {
          final isDark = Theme.of(ctx).brightness == Brightness.dark;
          final sheetBg = isDark ? const Color(0xFF1E1E1E) : Colors.white;

          return Container(
            decoration: BoxDecoration(
              color: sheetBg,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Padding(
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
                            Text('Admin картасы',
                                style: AppTextStyles.headingSmall.copyWith(
                                    color: isDark ? Colors.white : AppColors.black)),
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
                        color: isDark
                            ? const Color(0xFF0A2C1A)
                            : AppColors.success.withValues(alpha: 0.08),
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
                        selection: TextSelection.collapsed(offset: formatted.length),
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
                        disabledBackgroundColor: AppColors.grey300,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text(
                        _adminCardMasked != null
                            ? '🔄  Картаны алмаштыруу'
                            : '✅  Картаны сактоо',
                        style: const TextStyle(
                            color: Colors.white, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                  if (_adminCardMasked != null) ...[
                    const SizedBox(height: 8),
                    Center(
                      child: TextButton(
                        onPressed: () => _removeAdminCard(ctx),
                        child: const Text('Картаны өчүрүү',
                            style: TextStyle(color: AppColors.grey500, fontSize: 13)),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
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
      await supabase.from('products').delete().eq('id', product['id'] as String);
      _showSnack('🗑️ "$name" өчүрүлдү', AppColors.error);
    }
  }

  Future<void> _toggleBlockProduct(Map<String, dynamic> product) async {
    final id = product['id'] as String;
    final name = product['title'] as String? ?? 'Товар';
    final isBlocked = product['is_blocked'] as bool? ?? false;
    await supabase.from('products').update({'is_blocked': !isBlocked}).eq('id', id);
    _showSnack(
      isBlocked ? '🔓 "$name" блоктон чыгарылды' : '🔒 "$name" блоктолду',
      isBlocked ? AppColors.success : AppColors.error,
    );
  }

  void _openSuggestionsPanel() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _SuggestionsPanelSheet(),
    );
  }

  // ══════════════════════════════════════════════════════
  // BUILD
  // ══════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scaffoldBg = isDark ? const Color(0xFF121212) : const Color(0xFFF0F4FF);

    return Scaffold(
      backgroundColor: scaffoldBg,
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E40AF),
        elevation: 0,
        automaticallyImplyLeading: false,
       title: Row(
  children: [
    const Text('🛡️', style: TextStyle(fontSize: 22)),
    const SizedBox(width: 8),
    Expanded(
      child: Text(
        'Admin панели',
        style: AppTextStyles.headingMedium.copyWith(color: Colors.white),
        overflow: TextOverflow.ellipsis,
      ),
    ),
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
                    ? Colors.white.withValues(alpha: 0.2)
                    : AppColors.error.withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.credit_card, color: Colors.white, size: 16),
                  const SizedBox(width: 4),
                  Text(
                    _adminCardMasked ?? 'Карта жок',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ),
          GestureDetector(
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const AdminStoryManagerScreen())),
            child: const Padding(
              padding: EdgeInsets.only(right: 4),
              child: Icon(Icons.auto_stories_rounded, color: Color(0xFFD97706), size: 24),
            ),
          ),
          GestureDetector(
  onTap: () => Navigator.push(context,
      MaterialPageRoute(builder: (_) => const AdminPhoneRequestsScreen())),
  child: const Padding(
    padding: EdgeInsets.only(right: 8),
    child: Icon(Icons.phone_callback_rounded, color: Colors.white70, size: 24),
  ),
),
GestureDetector(
  onTap: () => Navigator.push(context,
      MaterialPageRoute(builder: (_) => const AdminStatsScreen())),
  child: const Padding(
    padding: EdgeInsets.only(right: 8),
    child: Icon(Icons.bar_chart_rounded, color: Colors.white70, size: 24),
  ),
),
          GestureDetector(
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const AdminSellerStatsScreen())),
            child: const Padding(
              padding: EdgeInsets.only(right: 4),
              child: Icon(Icons.people_alt_rounded, color: Color(0xFF10B981), size: 24),
            ),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
         tabs: [
  Tab(text: '⏳ Өтүнүчтөр (${_pendingSellers.length})'),
  Tab(text: '✅ Sellerлер (${_approvedSellers.length})'),
  Tab(text: '👥 Баары (${_allSellers.length})'),
  const Tab(text: '📦 Товарлар'),
  const Tab(text: '💳 Төлөмдөр'),
  Tab(text: '📞 Номер (${_phoneRequests.where((r) => r['status'] == 'pending').length})'),
  const Tab(text: '🔔 Билдирүү'),  // ← ЖАҢ
],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                TabBarView(
                  controller: _tabController,
                  children: [
                    _buildPendingTab(),
                    _buildApprovedTab(),
                    _buildAllTab(),
                    _buildProductsTab(),
                    _buildPaymentsTab(),
                    const AdminPhoneRequestsScreen(),
                    _buildNotificationsTab(),
                  ],
                ),

                // ── Оң астынкы — Арыздар + Сатуучуга жазуу FAB ──
                Positioned(
                  right: 16,
                  bottom: 16,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      FloatingActionButton.extended(
                        heroTag: 'complaints',
                        onPressed: () => _openComplaintsPanel(),
                        backgroundColor: const Color(0xFFEF4444),
                        icon: const Icon(Icons.flag_rounded, color: Colors.white, size: 20),
                        label: const Text(
                          'Арыздар',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                        ),
                      ),
                      const SizedBox(height: 10),
                      FloatingActionButton.extended(
                        heroTag: 'send_to_seller',
                        onPressed: () => showAdminChatSheet(context, _allSellers),
                        backgroundColor: const Color(0xFFD97706),
                        icon: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                        label: const Text(
                          'Сатуучуга',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton(
            heroTag: 'suggestions',
            onPressed: _openSuggestionsPanel,
            backgroundColor: Colors.green,
            child: const Icon(Icons.chat_bubble_outline_rounded, color: Colors.white),
          ),
          const SizedBox(height: 12),
          FloatingActionButton(
            heroTag: 'refresh',
            onPressed: _loadData,
            backgroundColor: const Color(0xFF1E40AF),
            child: const Icon(Icons.refresh, color: Colors.white),
          ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
    );
  }

  // ── Арыздар панели ──
  void _openComplaintsPanel() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (ctx, scrollCtrl) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          final bg = isDark ? const Color(0xFF1E1E1E) : Colors.white;
          return Container(
            decoration: BoxDecoration(
              color: bg,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF3A3A3A) : Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      Container(
                        width: 40, height: 40,
                        decoration: BoxDecoration(
                          color: const Color(0xFFEF4444).withOpacity(0.12),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.flag_rounded,
                            color: Color(0xFFEF4444), size: 20),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Арыздар',
                        style: AppTextStyles.headingMedium.copyWith(
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                const Expanded(child: AdminComplaintsScreen()),
              ],
            ),
          );
        },
      ),
    );
  }

  // ── Сатуучуга билдирүү жөнөтүү ──

  // ══════════════════════════════════════════════════════
  // ⏳ ӨТҮНҮЧТӨР TAB
  // ══════════════════════════════════════════════════════

Widget _buildNotificationsTab() {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final fillColor = isDark ? const Color(0xFF2C2C2C) : const Color(0xFFF5F5F5);
  final textColor = isDark ? Colors.white : AppColors.black;

  return Column(
    children: [
      // ── Издөө ──
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
        child: TextField(
          controller: _notifSearchCtrl,
          style: TextStyle(color: textColor),
          decoration: InputDecoration(
            hintText: 'Билдирүүлөрдөн издөө...',
            hintStyle: TextStyle(color: AppColors.grey400),
            prefixIcon: Icon(Icons.search_rounded, color: AppColors.grey400),
            suffixIcon: _notifQuery.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    color: AppColors.grey400,
                    onPressed: () {
                      _notifSearchCtrl.clear();
                      setState(() => _notifQuery = '');
                    },
                  )
                : null,
            filled: true,
            fillColor: fillColor,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  const BorderSide(color: AppColors.primary, width: 1.5),
            ),
          ),
        ),
      ),

      // ── Билдирүүлөр тизмеси ──
      Expanded(
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 32),
          child: AdminNotificationSender(searchQuery: _notifQuery),
        ),
      ),
    ],
  );
}


  Widget _buildPendingTab() {
    if (_pendingSellers.isEmpty) return _buildEmpty('⏳', 'Күтүүдөгү өтүнүч жок');
    return ListView.builder(
      padding: const EdgeInsets.all(14),
      itemCount: _pendingSellers.length,
      itemBuilder: (_, i) => _buildRequestCard(_pendingSellers[i]),
    );
  }

  Widget _buildRequestCard(SellerModel s) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final iconBg    = isDark ? const Color(0xFF2C2C2C) : const Color(0xFFFFF8F0);
    final badgeBg   = isDark ? const Color(0xFF2C1E0A) : const Color(0xFFFFF3E0);
    final rejectBg  = isDark ? const Color(0xFF2C1010) : const Color(0xFFFFEEEE);
    final approveBg = isDark ? const Color(0xFF0A2C1A) : const Color(0xFFEEFFF5);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
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
                decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(12)),
                child: const Center(child: Text('🏪', style: TextStyle(fontSize: 24))),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(s.shopName,
                        style: AppTextStyles.labelLarge.copyWith(
                            color: isDark ? Colors.white : AppColors.black)),
                    Text(s.name,
                        style: AppTextStyles.labelSmall.copyWith(color: AppColors.grey500)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: badgeBg, borderRadius: BorderRadius.circular(20)),
                child: const Text('⏳ Жаңы',
                    style: TextStyle(fontSize: 12, color: AppColors.primary)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(s.phone,
              style: AppTextStyles.labelSmall.copyWith(color: AppColors.grey500)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => _reject(s),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                        color: rejectBg, borderRadius: BorderRadius.circular(10)),
                    child: Center(
                        child: Text('❌  Четке кагуу',
                            style: AppTextStyles.labelMedium.copyWith(color: AppColors.error))),
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
                        color: approveBg, borderRadius: BorderRadius.circular(10)),
                    child: Center(
                        child: Text('✅  Бекитүү',
                            style: AppTextStyles.labelMedium.copyWith(color: AppColors.success))),
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
  // ✅ SELLERЛЕР TAB
  // ══════════════════════════════════════════════════════

  Widget _buildApprovedTab() {
    final list = _filteredApproved;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final barBg    = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final fieldFill = isDark ? const Color(0xFF2C2C2C) : AppColors.grey100;

    return Column(
      children: [
        Container(
          color: barBg,
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
          child: TextField(
            controller: _searchCtrl,
            style: TextStyle(
                fontSize: 14, color: isDark ? Colors.white : AppColors.black),
            decoration: InputDecoration(
              hintText: 'Дүкөн аты, номер, контейнер...',
              hintStyle: TextStyle(color: AppColors.grey400, fontSize: 14),
              prefixIcon: const Icon(Icons.search, color: AppColors.grey400, size: 20),
              suffixIcon: _searchQuery.isNotEmpty
                  ? GestureDetector(
                      onTap: () => _searchCtrl.clear(),
                      child: const Icon(Icons.close, color: AppColors.grey400, size: 18),
                    )
                  : null,
              filled: true,
              fillColor: fieldFill,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        if (_searchQuery.isNotEmpty)
          Container(
            color: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF5F7FF),
            padding: const EdgeInsets.only(left: 14, bottom: 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Табылды: ${list.length} seller',
                style: AppTextStyles.labelSmall.copyWith(color: AppColors.primary),
              ),
            ),
          ),
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
    final isDark    = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final nameColor = isDark ? Colors.white : AppColors.black;
    final paid      = s.currentMonthPaid;
    final isBlocked = s.status == SellerStatus.blocked;
    final iconBg    = isDark
        ? const Color(0xFF2C2C2C)
        : isBlocked ? const Color(0xFFF0F0F0) : const Color(0xFFFFF8F0);

    return GestureDetector(
      onTap: () => _showSellerProducts(s),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isBlocked
                ? AppColors.grey400.withValues(alpha: 0.4)
                : paid
                    ? AppColors.success.withValues(alpha: 0.3)
                    : AppColors.error.withValues(alpha: 0.3),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
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
                      color: iconBg, borderRadius: BorderRadius.circular(12)),
                  child: Center(
                    child: Text(
                      isBlocked
                          ? '🔒'
                          : (s.shopName.isNotEmpty
                              ? s.shopName[0].toUpperCase()
                              : '🏪'),
                      style: TextStyle(
                          fontSize: isBlocked ? 22 : 18,
                          fontWeight: FontWeight.bold,
                          color: nameColor),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s.shopName,
                          style: AppTextStyles.labelLarge.copyWith(color: nameColor)),
                      Text(s.name,
                          style: AppTextStyles.labelSmall.copyWith(color: AppColors.grey500)),
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
                        padding:
                            const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: s.autoPayEnabled
                              ? (isDark ? const Color(0xFF0A2C1A) : const Color(0xFFEEFFF5))
                              : (isDark ? const Color(0xFF2C2C2C) : const Color(0xFFF0F0F0)),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          s.autoPayEnabled ? '🔄 Авто' : '⏸ Токтоп',
                          style: TextStyle(
                            fontSize: 10,
                            color: s.autoPayEnabled ? AppColors.success : AppColors.grey500,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              s.containerNumber.isNotEmpty ? s.containerNumber : 'Контейнер жок',
              style: AppTextStyles.labelSmall.copyWith(
                color: s.containerNumber.isEmpty ? AppColors.error : AppColors.grey500,
              ),
            ),
            const SizedBox(height: 12),
            Divider(height: 1, color: isDark ? const Color(0xFF2C2C2C) : AppColors.grey200),
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
                        ? (isDark ? const Color(0xFF2C1010) : const Color(0xFFFFEEEE))
                        : (isDark ? const Color(0xFF0A2C1A) : const Color(0xFFEEFFF5)),
                    onTap: () => _markPayment(s, !paid),
                  ),
                _actionButton(
                  label: '📞 Номер',
                  color: AppColors.primary,
                  bgColor: isDark ? const Color(0xFF2C1E0A) : const Color(0xFFFFF3E0),
                  onTap: () => _editPhone(s),
                ),
                _actionButton(
                  label: '🏪 Контейнер',
                  color: const Color(0xFF7C3AED),
                  bgColor: isDark ? const Color(0xFF1A1040) : const Color(0xFFF5F3FF),
                  onTap: () => _editContainer(s),
                ),
                _actionButton(
                  label: s.hasLocation ? '📍 Локация бар' : '📍 Локация кошуу',
                  color: s.hasLocation ? AppColors.success : const Color(0xFF7C3AED),
                  bgColor: s.hasLocation
                      ? (isDark ? const Color(0xFF0A2C1A) : const Color(0xFFEEFFF5))
                      : (isDark ? const Color(0xFF1A1040) : const Color(0xFFF5F3FF)),
                  onTap: () => _openMapPicker(s),
                ),
                _actionButton(
                  label: '🔑 Пароль',
                  color: const Color(0xFF0369A1),
                  bgColor: isDark ? const Color(0xFF0A1F2C) : const Color(0xFFE0F2FE),
                  onTap: () => _resetPassword(s),
                ),
                if (s.hasCard)
                  _actionButton(
                    label: s.autoPayEnabled ? '⛔ Авто токтотуу' : '▶️ Авто иштетүү',
                    color: s.autoPayEnabled ? AppColors.error : AppColors.success,
                    bgColor: s.autoPayEnabled
                        ? (isDark ? const Color(0xFF2C1010) : const Color(0xFFFFEEEE))
                        : (isDark ? const Color(0xFF0A2C1A) : const Color(0xFFEEFFF5)),
                    onTap: () => _toggleSellerAutoPay(s),
                  ),
                _actionButton(
                  label: isBlocked ? '🔓 Блоктон чыгаруу' : '🔒 Блоктоо',
                  color: isBlocked ? AppColors.success : AppColors.error,
                  bgColor: isBlocked
                      ? (isDark ? const Color(0xFF0A2C1A) : const Color(0xFFEEFFF5))
                      : (isDark ? const Color(0xFF2C1010) : const Color(0xFFFFEEEE)),
                  onTap: () => _toggleBlock(s),
                ),
                _actionButton(
                  label: '🗑️ Өчүрүү',
                  color: AppColors.error,
                  bgColor: isDark ? const Color(0xFF2C1010) : const Color(0xFFFFEEEE),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ListView.builder(
      padding: const EdgeInsets.all(14),
      itemCount: _allSellers.length,
      itemBuilder: (_, i) {
        final s = _allSellers[i];
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
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
                    Text(s.shopName,
                        style: AppTextStyles.labelLarge.copyWith(
                            color: isDark ? Colors.white : AppColors.black)),
                    Text(s.phone,
                        style: AppTextStyles.labelSmall.copyWith(color: AppColors.grey500)),
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
        final isDark = Theme.of(context).brightness == Brightness.dark;
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: AppColors.primary));
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
        final active  = products.where((p) => p['is_blocked'] != true).toList();
        final sorted  = [...blocked, ...active];

        return Column(
          children: [
            Container(
              color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
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
    final isDark    = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final nameColor = isDark ? Colors.white : AppColors.black;
    final name      = product['title'] as String? ?? 'Аты жок';
    final price     = (product['price'] as num?)?.toDouble() ?? 0;
    final isBlocked = product['is_blocked'] as bool? ?? false;
    final inStock   = (product['in_stock'] as num?)?.toInt() ?? 0;
    final images    = product['images'] as List<dynamic>? ?? [];
    final imageUrl  = images.isNotEmpty ? images.first as String : '';
    final imgBg     = isDark ? const Color(0xFF2C2C2C) : const Color(0xFFFFF8F0);
    final blockBtnBg = isDark ? const Color(0xFF2C1010) : const Color(0xFFFFEEEE);
    final unblockBtnBg = isDark ? const Color(0xFF0A2C1A) : const Color(0xFFEEFFF5);
    final deleteBg  = isDark ? const Color(0xFF2C1010) : const Color(0xFFFFEEEE);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isBlocked
              ? AppColors.error.withValues(alpha: 0.4)
              : (isDark ? const Color(0xFF2C2C2C) : AppColors.grey200),
          width: isBlocked ? 1.5 : 1,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: imageUrl.isNotEmpty
              ? Image.network(imageUrl, width: 46, height: 46, fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    width: 46, height: 46, color: imgBg,
                    child: Center(
                        child: Text(isBlocked ? '🔒' : '📦',
                            style: const TextStyle(fontSize: 22))),
                  ))
              : Container(width: 46, height: 46, color: imgBg,
                  child: Center(
                      child: Text(isBlocked ? '🔒' : '📦',
                          style: const TextStyle(fontSize: 22)))),
        ),
        title: Text(name, style: AppTextStyles.labelLarge.copyWith(color: nameColor)),
        subtitle: Text('${price.toInt()} с • $inStock шт',
            style: AppTextStyles.labelSmall.copyWith(color: AppColors.grey500)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            GestureDetector(
              onTap: () => _toggleBlockProduct(product),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: isBlocked ? unblockBtnBg : blockBtnBg,
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
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(color: deleteBg, borderRadius: BorderRadius.circular(8)),
                child: Text('🗑️',
                    style: AppTextStyles.labelSmall.copyWith(color: AppColors.error)),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg  = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final now     = DateTime.now();
    final currentMonth = '${now.year}-${now.month.toString().padLeft(2, '0')}';
    final paid   = _approvedSellers.where((s) => s.currentMonthPaid).toList();
    final unpaid = _approvedSellers
        .where((s) => !s.currentMonthPaid && s.status == SellerStatus.approved)
        .toList();
    final totalExpected =
        _approvedSellers.where((s) => s.status == SellerStatus.approved).length * 2000;
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
                    style: const TextStyle(color: Colors.white70, fontSize: 13)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: _payStatCard('Түштү', '$totalReceived сом', AppColors.success)),
                    const SizedBox(width: 10),
                    Expanded(child: _payStatCard('Күтүлөт', '$totalExpected сом', Colors.white70)),
                    const SizedBox(width: 10),
                    Expanded(child: _payStatCard('Карызда', '${unpaid.length} seller', AppColors.error)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          // ── Admin картасы ──
          GestureDetector(
            onTap: _showAdminCardSheet,
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: cardBg,
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
                        Text('Менин картам (кириш)',
                            style: AppTextStyles.labelLarge.copyWith(
                                color: isDark ? Colors.white : AppColors.black)),
                        Text(
                          _adminCardMasked ?? 'Карта байланган эмес — басып кошуңуз',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: _adminCardMasked != null
                                ? AppColors.success
                                : AppColors.error,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.arrow_forward_ios, size: 16, color: AppColors.grey400),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          if (paid.isNotEmpty) ...[
            Text('✅ Төлөгөндөр (${paid.length})',
                style: AppTextStyles.headingSmall.copyWith(
                    color: isDark ? Colors.white : AppColors.black)),
            const SizedBox(height: 10),
            ...paid.map((s) => _buildPaymentRow(s, true)),
            const SizedBox(height: 16),
          ],
          if (unpaid.isNotEmpty) ...[
            Text('❌ Төлөбөгөндөр (${unpaid.length})',
                style: AppTextStyles.headingSmall.copyWith(
                    color: isDark ? Colors.white : AppColors.black)),
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
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11)),
          const SizedBox(height: 4),
          Text(value,
              style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildPaymentRow(SellerModel s, bool paid) {
    final isDark   = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final nameColor = isDark ? Colors.white : AppColors.black;
    final autoBtnBg = s.autoPayEnabled
        ? (isDark ? const Color(0xFF2C1010) : const Color(0xFFFFEEEE))
        : (isDark ? const Color(0xFF0A2C1A) : const Color(0xFFEEFFF5));
    final markBtnBg = paid
        ? (isDark ? const Color(0xFF2C1010) : const Color(0xFFFFEEEE))
        : (isDark ? const Color(0xFF0A2C1A) : const Color(0xFFEEFFF5));

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cardColor,
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
                Text(s.shopName,
                    style: AppTextStyles.labelMedium.copyWith(color: nameColor)),
                Row(
                  children: [
                    Text(s.phone,
                        style: AppTextStyles.labelSmall.copyWith(color: AppColors.grey500)),
                    if (s.hasCard) ...[
                      const SizedBox(width: 6),
                      Text(
                        s.autoPayEnabled ? '🔄 Авто' : '⏸ Авто токтоп',
                        style: TextStyle(
                          fontSize: 10,
                          color: s.autoPayEnabled ? AppColors.success : AppColors.grey400,
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
                    color: autoBtnBg, borderRadius: BorderRadius.circular(8)),
                child: Text(
                  s.autoPayEnabled ? '⛔ Токтот' : '▶️ Иштет',
                  style: TextStyle(
                    fontSize: 11,
                    color: s.autoPayEnabled ? AppColors.error : AppColors.success,
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
                  color: markBtnBg, borderRadius: BorderRadius.circular(8)),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    String text;
    Color color;
    Color bg;
    switch (status) {
      case SellerStatus.pending:
        text  = '⏳ Күтүүдө';
        color = AppColors.primary;
        bg    = isDark ? const Color(0xFF2C1E0A) : const Color(0xFFFFF8F0);
      case SellerStatus.approved:
        text  = '✅ Активдүү';
        color = AppColors.success;
        bg    = isDark ? const Color(0xFF0A2C1A) : const Color(0xFFEEFFF5);
      case SellerStatus.rejected:
        text  = '❌ Четке';
        color = AppColors.error;
        bg    = isDark ? const Color(0xFF2C0A0A) : const Color(0xFFFFEEEE);
      case SellerStatus.blocked:
        text  = '🔒 Блок';
        color = AppColors.grey500;
        bg    = isDark ? const Color(0xFF2C2C2C) : const Color(0xFFF0F0F0);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
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
        decoration:
            BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(10)),
        child: Text(label, style: AppTextStyles.labelSmall.copyWith(color: color)),
      ),
    );
  }

  Widget _statChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20)),
      child: Text(label, style: AppTextStyles.labelSmall.copyWith(color: color)),
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
              style: AppTextStyles.headingSmall.copyWith(color: AppColors.grey400)),
        ],
      ),
    );
  }

  InputDecoration _inputDec(String label, String hint) => InputDecoration(
        labelText: label,
        hintText: hint,
        counterText: '',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
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
            child: const Text('Жок', style: TextStyle(color: AppColors.grey500)),
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

// ══════════════════════════════════════════════════════
// КАРДАРЛАР БИЛДИРҮҮЛӨРҮ
// ══════════════════════════════════════════════════════

class _SuggestionsPanelSheet extends StatefulWidget {
  @override
  State<_SuggestionsPanelSheet> createState() => _SuggestionsPanelSheetState();
}

class _SuggestionsPanelSheetState extends State<_SuggestionsPanelSheet> {
  List<Map<String, dynamic>> _suggestions = [];
  bool _loading = true;

  // Тандоо режими (белгилеп өчүрүү үчүн)
  bool _selectMode = false;
  final Set<String> _selected = {};

  // Sheet ичинде snackbar көрүнүшү үчүн өзүнчө messenger
  final _messengerKey = GlobalKey<ScaffoldMessengerState>();

  @override
  void initState() {
    super.initState();
    _load();
  }

  String _idOf(Map<String, dynamic> s) => s['id'].toString();

  Future<void> _load() async {
    try {
      final rows = await supabase
          .from('buyer_suggestions')
          .select()
          .order('created_at', ascending: false);
      if (!mounted) return;
      setState(() {
        _suggestions = (rows as List)
            .map((r) => Map<String, dynamic>.from(r as Map))
            .toList();
        _selected.removeWhere((id) => !_suggestions.any((s) => _idOf(s) == id));
        _loading = false;
      });
    } catch (e) {
      debugPrint('❌ _SuggestionsPanelSheet._load: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    (_messengerKey.currentState ?? ScaffoldMessenger.of(context)).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: error ? AppColors.error : AppColors.success,
      ),
    );
  }

  Future<void> _markRead(List<String> ids) async {
    if (ids.isEmpty) return;
    try {
      await supabase
          .from('buyer_suggestions')
          .update({'is_read': true}).inFilter('id', ids);
      if (!mounted) return;
      setState(() {
        for (final s in _suggestions) {
          if (ids.contains(_idOf(s))) s['is_read'] = true;
        }
      });
    } catch (e) {
      debugPrint('❌ suggestions markRead: $e');
      _snack('Ката: $e', error: true);
    }
  }

  Future<void> _delete(List<String> ids) async {
    if (ids.isEmpty) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Өчүрүү', style: AppTextStyles.headingSmall),
        content: Text(
          ids.length == 1
              ? 'Бул билдирүүнү өчүрөсүзбү?'
              : '${ids.length} билдирүүнү өчүрөсүзбү?',
          style: AppTextStyles.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Жок', style: TextStyle(color: AppColors.grey500)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Өчүрүү', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
    if (ok != true) return;

    try {
      final deleted = await supabase
          .from('buyer_suggestions')
          .delete()
          .inFilter('id', ids)
          .select('id');
      if (deleted.isEmpty) {
        _snack(
          'Өчүрүлгөн жок. Supabase\'де SQL миграцияны (delete уруксаты) иштетиңиз.',
          error: true,
        );
        return;
      }
      if (!mounted) return;
      setState(() {
        _suggestions.removeWhere((s) => ids.contains(_idOf(s)));
        _selected.removeAll(ids);
        if (_selected.isEmpty) _selectMode = false;
      });
      _snack('Өчүрүлдү: ${deleted.length}');
    } catch (e) {
      debugPrint('❌ suggestions delete: $e');
      _snack('Ката: $e', error: true);
    }
  }

  void _toggle(String id) {
    setState(() {
      if (_selected.contains(id)) {
        _selected.remove(id);
      } else {
        _selected.add(id);
      }
    });
  }

  void _exitSelectMode() {
    setState(() {
      _selectMode = false;
      _selected.clear();
    });
  }

  String _typeLabel(String? type) {
    switch (type) {
      case 'new_feature':      return '🆕 Жаңы нерсе';
      case 'missing_category': return '📂 Категория жетишпейт';
      case 'low_stock':        return '📦 Товар аз';
      default:                 return '💬 Башка';
    }
  }

  Widget _buildHeader() {
    final allIds = _suggestions.map(_idOf).toList();
    final allSelected = allIds.isNotEmpty && allIds.every(_selected.contains);
    final unread =
        _suggestions.where((s) => !(s['is_read'] as bool? ?? false)).length;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 8, 12),
      decoration: const BoxDecoration(
        color: Color(0xFF1E40AF),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: _selectMode
          ? Row(
              children: [
                IconButton(
                  tooltip: 'Жабуу',
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: _exitSelectMode,
                ),
                Expanded(
                  child: Text(
                    'Тандалды: ${_selected.length}',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  tooltip: allSelected ? 'Тандоону алып салуу' : 'Баарын тандоо',
                  icon: Icon(allSelected ? Icons.deselect : Icons.select_all,
                      color: Colors.white),
                  onPressed: () => setState(() {
                    if (allSelected) {
                      _selected.clear();
                    } else {
                      _selected.addAll(allIds);
                    }
                  }),
                ),
                IconButton(
                  tooltip: 'Окулду деп белгилөө',
                  icon: Icon(Icons.done_all_rounded,
                      color: _selected.isEmpty ? Colors.white38 : Colors.white),
                  onPressed: _selected.isEmpty
                      ? null
                      : () => _markRead(_selected.toList()),
                ),
                IconButton(
                  tooltip: 'Өчүрүү',
                  icon: Icon(Icons.delete_outline_rounded,
                      color: _selected.isEmpty
                          ? Colors.white38
                          : const Color(0xFFFCA5A5)),
                  onPressed: _selected.isEmpty
                      ? null
                      : () => _delete(_selected.toList()),
                ),
              ],
            )
          : Row(
              children: [
                const Text('💬', style: TextStyle(fontSize: 22)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    unread > 0
                        ? 'Кардарлар билдирүүлөрү ($unread жаңы)'
                        : 'Кардарлар билдирүүлөрү',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  tooltip: 'Тандоо',
                  icon: const Icon(Icons.checklist_rounded, color: Colors.white),
                  onPressed: _suggestions.isEmpty
                      ? null
                      : () => setState(() => _selectMode = true),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white70),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
    );
  }

  Widget _buildItem(Map<String, dynamic> s) {
    final id = _idOf(s);
    final isRead = s['is_read'] as bool? ?? false;
    final isSelected = _selected.contains(id);
    final time = DateTime.tryParse(s['created_at'] as String? ?? '')?.toLocal();
    final timeStr = time != null
        ? '${time.day}/${time.month} ${time.hour}:${time.minute.toString().padLeft(2, '0')}'
        : '';

    return GestureDetector(
      onTap: () {
        if (_selectMode) {
          _toggle(id);
        } else if (!isRead) {
          _markRead([id]);
        }
      },
      onLongPress: () {
        if (!_selectMode) {
          setState(() {
            _selectMode = true;
            _selected.add(id);
          });
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF1E40AF).withValues(alpha: 0.35)
              : const Color(0xFF334155),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected
                ? Colors.lightBlueAccent
                : (isRead ? Colors.transparent : Colors.greenAccent.withValues(alpha: 0.6)),
            width: isSelected ? 1.6 : 1,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_selectMode) ...[
              Checkbox(
                value: isSelected,
                activeColor: Colors.lightBlueAccent,
                side: const BorderSide(color: Colors.white54),
                onChanged: (_) => _toggle(id),
              ),
              const SizedBox(width: 4),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.blue.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _typeLabel(s['type'] as String?),
                          style: const TextStyle(
                              color: Colors.lightBlue, fontSize: 11),
                        ),
                      ),
                      if (!isRead) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.green,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text('Жаңы',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold)),
                        ),
                      ],
                      const Spacer(),
                      Text(timeStr,
                          style: const TextStyle(
                              color: Colors.white38, fontSize: 11)),
                      if (!_selectMode)
                        InkWell(
                          onTap: () => _delete([id]),
                          borderRadius: BorderRadius.circular(12),
                          child: const Padding(
                            padding: EdgeInsets.only(left: 8),
                            child: Icon(Icons.delete_outline_rounded,
                                color: Color(0xFFFCA5A5), size: 20),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text('👤 ${s['user_name'] ?? 'Белгисиз'}',
                      style: const TextStyle(
                          color: Colors.white70, fontSize: 12)),
                  const SizedBox(height: 4),
                  Text(s['message'] as String? ?? '',
                      style:
                          const TextStyle(color: Colors.white, fontSize: 14)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.80,
      decoration: const BoxDecoration(
        color: Color(0xFF1E293B),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        child: ScaffoldMessenger(
          key: _messengerKey,
          child: Scaffold(
            backgroundColor: Colors.transparent,
            body: Column(
              children: [
                _buildHeader(),
                Expanded(
                  child: _loading
                      ? const Center(
                          child: CircularProgressIndicator(color: Colors.white))
                      : _suggestions.isEmpty
                          ? const Center(
                              child: Text('Билдирүү жок',
                                  style: TextStyle(color: Colors.white54)))
                          : RefreshIndicator(
                              onRefresh: _load,
                              child: ListView.builder(
                                padding: const EdgeInsets.all(12),
                                itemCount: _suggestions.length,
                                itemBuilder: (_, i) => _buildItem(_suggestions[i]),
                              ),
                            ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════
// Сатуучуну тандоо + Билдирүү жөнөтүү
// ══════════════════════════════════════════════════════
class _SendToSellerSheet extends StatefulWidget {
  final List<SellerModel> sellers;
  const _SendToSellerSheet({required this.sellers});

  @override
  State<_SendToSellerSheet> createState() => _SendToSellerSheetState();
}

class _SendToSellerSheetState extends State<_SendToSellerSheet> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  List<SellerModel> get _filtered {
    if (_query.isEmpty) return widget.sellers;
    final q = _query.toLowerCase();
    return widget.sellers.where((s) =>
        s.shopName.toLowerCase().contains(q) ||
        s.name.toLowerCase().contains(q) ||
        s.containerNumber.toLowerCase().contains(q)).toList();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _openCompose(SellerModel seller) {
    Navigator.pop(context); // sheet'ти жап
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ComposeMessageSheet(seller: seller),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sheetBg = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final fillColor = isDark ? const Color(0xFF2C2C2C) : const Color(0xFFF5F5F5);
    final textColor = isDark ? Colors.white : AppColors.black;
    final subColor = isDark ? Colors.white60 : AppColors.grey500;

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (_, scrollCtrl) => Container(
        decoration: BoxDecoration(
          color: sheetBg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // Handle
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Башлык
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFD97706), Color(0xFFEF4444)],
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.send_rounded,
                        color: Colors.white, size: 18),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Сатуучуну тандаңыз',
                    style: AppTextStyles.headingSmall.copyWith(color: textColor),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: Icon(Icons.close, color: subColor),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // Издөө
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: TextField(
                controller: _searchCtrl,
                style: TextStyle(color: textColor),
                onChanged: (v) => setState(() => _query = v.trim()),
                decoration: InputDecoration(
                  hintText: 'Дүкөн аты, ысым же контейнер...',
                  hintStyle: TextStyle(color: AppColors.grey400),
                  prefixIcon: const Icon(Icons.search_rounded,
                      color: AppColors.grey400),
                  suffixIcon: _query.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.close, size: 18),
                          color: AppColors.grey400,
                          onPressed: () {
                            _searchCtrl.clear();
                            setState(() => _query = '');
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: fillColor,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 4),

            // Тизме
            Expanded(
              child: _filtered.isEmpty
                  ? Center(
                      child: Text('Табылган жок',
                          style: AppTextStyles.bodySmall
                              .copyWith(color: subColor)),
                    )
                  : ListView.builder(
                      controller: scrollCtrl,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      itemCount: _filtered.length,
                      itemBuilder: (_, i) {
                        final s = _filtered[i];
                        return ListTile(
                          onTap: () => _openCompose(s),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          leading: CircleAvatar(
                            backgroundColor: const Color(0xFFD97706)
                                .withValues(alpha: 0.15),
                            child: Text(
                              s.shopName.isNotEmpty
                                  ? s.shopName[0].toUpperCase()
                                  : '🏪',
                              style: const TextStyle(
                                  color: Color(0xFFD97706),
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                          title: Text(s.shopName,
                              style: AppTextStyles.labelLarge
                                  .copyWith(color: textColor)),
                          subtitle: Text(
                            '${s.name}  •  ${s.containerNumber}',
                            style: AppTextStyles.labelSmall
                                .copyWith(color: subColor),
                          ),
                          trailing: const Icon(
                            Icons.chevron_right_rounded,
                            color: AppColors.grey400,
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════
// Билдирүү жазуу жана жөнөтүү
// ══════════════════════════════════════════════════════
class _ComposeMessageSheet extends StatefulWidget {
  final SellerModel seller;
  const _ComposeMessageSheet({required this.seller});

  @override
  State<_ComposeMessageSheet> createState() => _ComposeMessageSheetState();
}

class _ComposeMessageSheetState extends State<_ComposeMessageSheet> {
  final _titleCtrl = TextEditingController();
  final _bodyCtrl = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _bodyCtrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final title = _titleCtrl.text.trim();
    final body = _bodyCtrl.text.trim();
    if (title.isEmpty || body.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Аталыш жана текст жазыңыз'),
        backgroundColor: AppColors.error,
      ));
      return;
    }
    setState(() => _sending = true);
    try {
      await supabase.from('admin_notifications').insert({
        'title': title,
        'body': body,
        'seller_id': widget.seller.uid,
        'created_at': DateTime.now().toIso8601String(),
      });
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('✅ ${widget.seller.shopName} дүкөнүнө жөнөтүлдү'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10)),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Ката: $e'),
          backgroundColor: AppColors.error,
        ));
        setState(() => _sending = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sheetBg = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final fillColor = isDark ? const Color(0xFF2C2C2C) : const Color(0xFFF5F5F5);
    final textColor = isDark ? Colors.white : AppColors.black;
    final subColor = isDark ? Colors.white60 : AppColors.grey500;
    final labelColor = isDark ? Colors.white70 : AppColors.grey600;

    return Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(
          color: sheetBg,
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
            Center(
              child: Container(
                width: 40, height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Башлык
            Row(
              children: [
                CircleAvatar(
                  backgroundColor:
                      const Color(0xFFD97706).withValues(alpha: 0.15),
                  child: Text(
                    widget.seller.shopName.isNotEmpty
                        ? widget.seller.shopName[0].toUpperCase()
                        : '🏪',
                    style: const TextStyle(
                        color: Color(0xFFD97706),
                        fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.seller.shopName,
                        style: AppTextStyles.labelLarge
                            .copyWith(color: textColor)),
                    Text(widget.seller.containerNumber,
                        style: AppTextStyles.labelSmall
                            .copyWith(color: subColor)),
                  ],
                ),
                const Spacer(),
                IconButton(
                  icon: Icon(Icons.close, color: subColor),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Аталышы
            Text('Аталышы',
                style: AppTextStyles.labelMedium
                    .copyWith(color: labelColor)),
            const SizedBox(height: 6),
            TextField(
              controller: _titleCtrl,
              style: TextStyle(color: textColor),
              decoration: InputDecoration(
                hintText: 'Мис: Маанилүү маалымат',
                hintStyle: TextStyle(color: AppColors.grey400),
                filled: true,
                fillColor: fillColor,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                      color: AppColors.primary, width: 1.5),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Текст
            Text('Билдирүү',
                style: AppTextStyles.labelMedium
                    .copyWith(color: labelColor)),
            const SizedBox(height: 6),
            TextField(
              controller: _bodyCtrl,
              maxLines: 4,
              style: TextStyle(color: textColor),
              decoration: InputDecoration(
                hintText: '${widget.seller.shopName} дүкөнүнө кат жазыңыз...',
                hintStyle: TextStyle(color: AppColors.grey400),
                filled: true,
                fillColor: fillColor,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                      color: AppColors.primary, width: 1.5),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Жөнөт
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _sending ? null : _send,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD97706),
                  disabledBackgroundColor: AppColors.grey300,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                icon: _sending
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2),
                      )
                    : const Icon(Icons.send_rounded,
                        color: Colors.white, size: 18),
                label: Text(
                  _sending ? 'Жөнөтүлүүдө...' : 'Жөнөт',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}