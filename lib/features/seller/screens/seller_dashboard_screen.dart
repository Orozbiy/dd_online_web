import 'package:flutter/material.dart';
import '../../../config/theme/app_colors.dart';
import '../../../config/theme/app_text_styles.dart';
import '../../../core/app_localizations.dart';
import '../models/seller_model.dart';
import '../services/seller_service.dart';
import '../services/subscription_service.dart';
import 'seller_product_screen.dart';
import '../../chat/screens/chat_list_screen.dart';
import '../../chat/services/chat_service.dart';
import 'location_picker_screen.dart';
import '../../../core/supabase_client.dart';
import 'seller_login_screen.dart';
import '../../home/screens/home_screen.dart';
import 'seller_close_account_screen.dart';
import '../widgets/working_hours_sheet.dart';
import 'seller_rules_screen.dart';
import 'seller_edit_profile_screen.dart';

class SellerDashboardScreen extends StatefulWidget {
  final String uid;
  const SellerDashboardScreen({super.key, required this.uid});

  @override
  State<SellerDashboardScreen> createState() => _SellerDashboardScreenState();
}

class _SellerDashboardScreenState extends State<SellerDashboardScreen> {
  final _service     = SellerService();
  final _subService  = SubscriptionService();
  final _chatService = ChatService();

  SellerModel? _seller;
  bool _isLoading = true;
  String _workStart = '09:00';
  String _workEnd   = '18:00';
  String _workDays  = 'Дш-Жм';

  @override
  void initState() {
    super.initState();
    _loadSeller();
  }

  Future<void> _loadSeller() async {
    final seller = await _service.getSellerByUid(widget.uid);
    if (seller != null) {
      try {
        final store = await supabase
            .from('stores')
            .select('work_start, work_end, work_days')
            .eq('owner_id', widget.uid)
            .maybeSingle();
        if (store != null && mounted) {
          setState(() {
            _workStart = store['work_start'] as String? ?? '09:00';
            _workEnd   = store['work_end']   as String? ?? '18:00';
            _workDays  = store['work_days']  as String? ?? 'Дш-Жм';
          });
        }
      } catch (_) {}
    }
    if (mounted) {
      setState(() { _seller = seller; _isLoading = false; });
    }
  }

  void _showSnack(String msg, [Color color = AppColors.grey600]) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: color),
    );
  }

  void _logout() {
    final loc = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(loc.get('sign_out'), style: AppTextStyles.headingSmall),
        content: Text(loc.get('dash_logout_confirm'), style: AppTextStyles.bodyMedium),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context),
              child: Text(loc.get('no'), style: const TextStyle(color: AppColors.grey500))),
          TextButton(
            onPressed: () {
  Navigator.pop(context);
  Navigator.push(context, MaterialPageRoute(
    builder: (_) => SellerCloseAccountScreen(sellerUid: _seller!.uid),
  ));


            },
            child: Text(loc.get('dash_close_account'), style: const TextStyle(color: AppColors.error)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await supabase.auth.signOut();
              if (!mounted) return;
              Navigator.pushAndRemoveUntil(context,
                  MaterialPageRoute(builder: (_) => const SellerLoginScreen()),
                  (route) => false);
            },
            child: Text(loc.get('yes'), style: const TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }

  void _goBack() {
    Navigator.pushAndRemoveUntil(context,
        MaterialPageRoute(builder: (_) => const HomeScreen()), (route) => false);
  }

  void _showSubscriptionSheet() {
    final loc      = AppLocalizations.of(context);
    final cardCtrl = TextEditingController();
    final expCtrl  = TextEditingController();
    final cvvCtrl  = TextEditingController();
    bool agreed = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Padding(
          padding: EdgeInsets.only(
              left: 20, right: 20, top: 24,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                const Text('💳', style: TextStyle(fontSize: 28)),
                const SizedBox(width: 10),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(loc.get('sub_monthly'), style: AppTextStyles.headingSmall),
                  Text(loc.get('sub_charge_info'),
                      style: AppTextStyles.bodySmall.copyWith(color: AppColors.grey500)),
                ])),
              ]),
              if (_seller?.hasCard == true) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEEFFF5),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
                  ),
                  child: Row(children: [
                    const Icon(Icons.credit_card, color: AppColors.success, size: 20),
                    const SizedBox(width: 8),
                    Text(_seller!.cardMasked ?? '',
                        style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.success)),
                    const SizedBox(width: 4),
                    Text(loc.get('sub_card_linked'),
                        style: AppTextStyles.bodySmall.copyWith(color: AppColors.grey500)),
                  ]),
                ),
              ],
              const SizedBox(height: 20),
              TextField(
                controller: cardCtrl,
                keyboardType: TextInputType.number,
                maxLength: 19,
                decoration: _inputDec(
                  _seller?.hasCard == true ? loc.get('sub_new_card') : loc.get('sub_card_number'),
                  '0000 0000 0000 0000',
                ),
                onChanged: (v) {
                  final digits    = v.replaceAll(' ', '');
                  final formatted = digits.replaceAllMapped(RegExp(r'.{1,4}'), (m) => '${m.group(0)} ').trim();
                  cardCtrl.value  = TextEditingValue(text: formatted, selection: TextSelection.collapsed(offset: formatted.length));
                },
              ),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: TextField(controller: expCtrl, keyboardType: TextInputType.number, maxLength: 5, decoration: _inputDec(loc.get('sub_expiry'), 'MM/YY'))),
                const SizedBox(width: 12),
                Expanded(child: TextField(controller: cvvCtrl, keyboardType: TextInputType.number, maxLength: 3, obscureText: true, decoration: _inputDec('CVV', '•••'))),
              ]),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: () => setS(() => agreed = !agreed),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Checkbox(value: agreed, onChanged: (v) => setS(() => agreed = v ?? false), activeColor: AppColors.primary),
                  Expanded(child: Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(loc.get('sub_agree_text'), style: const TextStyle(fontSize: 13, color: Color(0xFF374151))),
                  )),
                ]),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity, height: 50,
                child: ElevatedButton(
                  onPressed: agreed && cardCtrl.text.replaceAll(' ', '').length == 16
                      ? () => _saveCard(cardCtrl.text, ctx) : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    disabledBackgroundColor: AppColors.grey200,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(
                    _seller?.hasCard == true ? loc.get('sub_replace_card') : loc.get('sub_link_card'),
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              if (_seller?.autoPayEnabled == true) ...[
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity, height: 46,
                  child: OutlinedButton(
                    onPressed: () => _cancelSub(ctx),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.error),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(loc.get('sub_cancel_autopay'),
                        style: const TextStyle(color: AppColors.error, fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
              if (_seller?.hasCard == true) ...[
                const SizedBox(height: 8),
                Center(child: TextButton(
                  onPressed: () => _removeCard(ctx),
                  child: Text(loc.get('sub_remove_card'),
                      style: const TextStyle(color: AppColors.grey500, fontSize: 13)),
                )),
              ],
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDec(String label, String hint) => InputDecoration(
        labelText: label, hintText: hint, counterText: '',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      );

  Future<void> _saveCard(String cardNumber, BuildContext ctx) async {
    final loc    = AppLocalizations.of(context);
    Navigator.pop(ctx);
    final digits = cardNumber.replaceAll(' ', '');
    if (digits.length < 16) return;
    final masked = '•••• ${digits.substring(12)}';
    await _subService.saveCard(uid: _seller!.uid, cardToken: 'token_${digits.substring(12)}', cardMasked: masked);
    await _loadSeller();
    if (mounted) _showSnack(loc.get('sub_card_saved'), AppColors.success);
  }

  Future<void> _cancelSub(BuildContext ctx) async {
    final loc = AppLocalizations.of(context);
    Navigator.pop(ctx);
    await _subService.cancelAutoPayment(_seller!.uid);
    await _loadSeller();
    if (mounted) _showSnack(loc.get('sub_autopay_cancelled'), AppColors.error);
  }

  Future<void> _removeCard(BuildContext ctx) async {
    final loc = AppLocalizations.of(context);
    Navigator.pop(ctx);
    await _subService.removeCard(_seller!.uid);
    await _loadSeller();
    if (mounted) _showSnack(loc.get('sub_card_removed'), AppColors.grey600);
  }

  @override
  Widget build(BuildContext context) {
    final loc    = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // ── Адаптивдүү түстөр ──
    final bgColor      = isDark ? const Color(0xFF121212) : const Color(0xFFF4F5F7);
    final appBarColor  = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final arrowColor   = isDark ? Colors.white : AppColors.black;
    final titleColor   = isDark ? Colors.white : AppColors.black;
    final cardBg       = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final sectionColor = isDark ? Colors.white : AppColors.black;
    final contactBg    = isDark ? const Color(0xFF1A2E1A) : const Color(0xFFF0FFF4);
    final contactBorder= const Color(0xFF22C55E).withValues(alpha: isDark ? 0.4 : 0.3);
    final contactText  = isDark ? const Color(0xFF86EFAC) : const Color(0xFF374151);

    if (_isLoading) {
      return PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) { if (!didPop) _goBack(); },
        child: Scaffold(
          backgroundColor: bgColor,
          body: const Center(child: CircularProgressIndicator()),
        ),
      );
    }

    if (_seller == null) {
      return PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) { if (!didPop) _goBack(); },
        child: Scaffold(
          backgroundColor: bgColor,
          body: Center(child: Text(loc.get('no_info'), style: AppTextStyles.bodyMedium)),
        ),
      );
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) { if (!didPop) _goBack(); },
      child: Scaffold(
        backgroundColor: bgColor,
        appBar: AppBar(
          backgroundColor: appBarColor,
          elevation: 0,
          leading: GestureDetector(
            onTap: _goBack,
            child: Icon(Icons.arrow_back, color: arrowColor),
          ),
          title: Row(children: [
            const Text('🏪', style: TextStyle(fontSize: 22)),
            const SizedBox(width: 8),
            Text(loc.get('dash_title'),
                style: AppTextStyles.headingMedium.copyWith(color: titleColor)),
          ]),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Сатуучу карточкасы (градиент — өзгөрбөйт) ──
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFD97706), Color(0xFFEF4444)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [BoxShadow(color: const Color(0xFFD97706).withValues(alpha: 0.3), blurRadius: 16, offset: const Offset(0, 6))],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Container(
                        width: 52, height: 52,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Center(child: Text(
                          _seller!.shopName.isNotEmpty ? _seller!.shopName[0].toUpperCase() : '🏪',
                          style: const TextStyle(fontSize: 26, color: Colors.white, fontWeight: FontWeight.bold),
                        )),
                      ),
                      const SizedBox(width: 14),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(_seller!.shopName, style: AppTextStyles.headingSmall.copyWith(color: Colors.white)),
                        const SizedBox(height: 4),
                        Text(_seller!.name, style: AppTextStyles.labelMedium.copyWith(color: Colors.white70)),
                      ])),

IconButton(



 onPressed: () async {
  final updated = await Navigator.push<bool>(context, MaterialPageRoute(
    builder: (_) => SellerEditProfileScreen(
      currentName:      _seller!.name,
      currentShopName:  _seller!.shopName,
      currentContainer: _seller!.containerNumber,
    ),
  ));
  if (updated == true) _loadSeller();
},
  icon: const Icon(Icons.edit, color: Colors.white, size: 20),
  padding: EdgeInsets.zero,
  constraints: const BoxConstraints(),
),

                    ]),
                    const SizedBox(height: 16),
                    const Divider(color: Colors.white24),
                    const SizedBox(height: 12),
                    Row(children: [
                      const Icon(Icons.phone, color: Colors.white70, size: 16),
                      const SizedBox(width: 6),
                      Text(_seller!.phone, style: AppTextStyles.labelMedium.copyWith(color: Colors.white)),
                    ]),
                  ],
                ),
              ),
              const SizedBox(height: 24),


GestureDetector(
  onTap: () => Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => const SellerRulesScreen()),
  ),
  child: Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
    decoration: BoxDecoration(
      color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(
        color: const Color(0xFFD97706).withValues(alpha: 0.5),
      ),
      boxShadow: isDark
          ? []
          : [
              BoxShadow(
                color: const Color(0xFFD97706).withValues(alpha: 0.08),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
    ),
    child: Row(
      children: [
        // ── Сол жак иконка ──
        Container(
          width: 42, height: 42,
          decoration: BoxDecoration(
            color: const Color(0xFFD97706).withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          alignment: Alignment.center,
          child: const Text('📋', style: TextStyle(fontSize: 22)),
        ),
        const SizedBox(width: 14),

        // ── Текст ──
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                loc.get('rules_btn_title'),
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : AppColors.black,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                loc.get('rules_btn_sub'),
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.grey500,
                ),
              ),
            ],
          ),
        ),

        // ── Оң жак жебе ──
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: const Color(0xFFD97706).withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(
            Icons.arrow_forward_ios_rounded,
            size: 14,
            color: Color(0xFFD97706),
          ),
        ),
      ],
    ),
  ),
),

const SizedBox(height: 20),



              Text(loc.get('dash_manage'),
                  style: AppTextStyles.headingSmall.copyWith(color: sectionColor)),
              const SizedBox(height: 12),

              _buildMenuItem(context,
                icon: '📦', title: loc.get('my_products'), subtitle: loc.get('dash_products_sub'),
                onTap: () => Navigator.push(context, MaterialPageRoute(
                    builder: (_) => SellerProductScreen(sellerUid: _seller!.uid, shopName: _seller!.shopName)))),
              const SizedBox(height: 10),

              _buildMenuItem(context,
                icon: '📊', title: loc.get('dash_stats'), subtitle: loc.get('dash_stats_sub'),
                onTap: () => _showSnack(loc.get('coming_soon'))),
              const SizedBox(height: 10),

              _buildMenuItem(context,
                icon: '📍', title: loc.get('dash_location'), subtitle: loc.get('dash_location_sub'),
                onTap: () async {
                  await Navigator.push(context, MaterialPageRoute(
                      builder: (_) => LocationPickerScreen(
                        shopName: _seller!.shopName, sellerUid: _seller!.uid,
                        initialLat: _seller!.latitude, initialLng: _seller!.longitude,
                      )));
                  _loadSeller();
                }),
              const SizedBox(height: 10),

              _buildMenuItem(context,
                icon: '🕐', title: loc.get('dash_hours'),
                subtitle: '$_workDays  $_workStart — $_workEnd',
                onTap: () async {
                  final saved = await showModalBottomSheet<bool>(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (_) => WorkingHoursSheet(
                      sellerUid: widget.uid, initialStart: _workStart,
                      initialEnd: _workEnd, initialDays: _workDays,
                    ),
                  );
                  if (saved == true) _loadSeller();
                }),
              const SizedBox(height: 10),

              _buildChatMenuItem(loc, cardBg),
              const SizedBox(height: 10),

              _buildMenuItem(context,
                icon: '📞', title: loc.get('dash_change_phone'), subtitle: loc.get('dash_change_phone_sub'),
                onTap: () => _showSnack(loc.get('coming_soon'))),
              const SizedBox(height: 10),

              _buildSubscriptionButton(loc, isDark),
              const SizedBox(height: 24),

              // ── Байланыш блогу ──
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: contactBg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: contactBorder),
                ),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('💬', style: TextStyle(fontSize: 22)),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(loc.get('dash_contact_title'),
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF16A34A))),
                    const SizedBox(height: 4),
                    Text(loc.get('dash_contact_desc'),
                        style: TextStyle(fontSize: 13, color: contactText)),
                    const SizedBox(height: 6),
                    const Text('+996221000330',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF16A34A))),
                  ])),
                ]),
              ),

              SizedBox(
                width: double.infinity, height: 50,
                child: OutlinedButton(
                  onPressed: _logout,
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    side: const BorderSide(color: AppColors.error, width: 1.5),
                  ),
                  child: Text('🚪  ${loc.get('sign_out')}',
                      style: AppTextStyles.labelLarge.copyWith(color: AppColors.error)),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSubscriptionButton(AppLocalizations loc, bool isDark) {
    final hasCard = _seller?.hasCard ?? false;
    final autoOn  = _seller?.autoPayEnabled ?? false;
    final paid    = _seller?.currentMonthPaid ?? false;

    Color borderColor;
    Color bgColor;
    String statusText;
    String subtitleText;

    if (autoOn && paid) {
      borderColor  = AppColors.success;
      bgColor      = isDark ? const Color(0xFF0D2B1A) : const Color(0xFFEEFFF5);
      statusText   = loc.get('sub_status_paid');
      subtitleText = '${_seller?.cardMasked ?? ''} · ${loc.get('sub_per_month')}';
    } else if (autoOn && !paid) {
      borderColor  = AppColors.primary;
      bgColor      = isDark ? const Color(0xFF2B1E0A) : const Color(0xFFFFF8F0);
      statusText   = loc.get('sub_status_active');
      subtitleText = '${_seller?.cardMasked ?? ''} · ${loc.get('sub_charge_day')}';
    } else if (hasCard && !autoOn) {
      borderColor  = AppColors.grey400;
      bgColor      = isDark ? const Color(0xFF1E1E1E) : Colors.white;
      statusText   = loc.get('sub_status_paused');
      subtitleText = _seller?.cardMasked ?? '';
    } else {
      borderColor  = AppColors.error.withValues(alpha: 0.5);
      bgColor      = isDark ? const Color(0xFF2B0D0D) : const Color(0xFFFFF1F0);
      statusText   = loc.get('sub_status_none');
      subtitleText = loc.get('sub_link_hint');
    }

    return GestureDetector(
      onTap: _showSubscriptionSheet,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderColor.withValues(alpha: 0.5)),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Row(children: [
          const Text('💳', style: TextStyle(fontSize: 26)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(statusText,
                style: AppTextStyles.labelLarge.copyWith(
                  color: isDark ? Colors.white : AppColors.black,
                )),
            const SizedBox(height: 2),
            Text(subtitleText, style: AppTextStyles.bodySmall.copyWith(color: AppColors.grey500)),
          ])),
          const Icon(Icons.arrow_forward_ios, color: AppColors.grey400, size: 16),
        ]),
      ),
    );
  }

  Widget _buildChatMenuItem(AppLocalizations loc, Color cardBg) {
    return StreamBuilder<List>(
      stream: _chatService.sellerChatsStream(_seller!.uid),
      builder: (context, snap) {
        final isDark      = Theme.of(context).brightness == Brightness.dark;
        final chats       = snap.data ?? [];
        final totalUnread = chats.fold<int>(0, (sum, chat) => sum + ((chat as dynamic).sellerUnread as int));
        final titleColor  = isDark ? Colors.white : AppColors.black;

        return GestureDetector(
          onTap: () => Navigator.push(context, MaterialPageRoute(
              builder: (_) => ChatListScreen(isSeller: true, sellerId: _seller!.uid))),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
            ),
            child: Row(children: [
              Stack(clipBehavior: Clip.none, children: [
                const Text('💬', style: TextStyle(fontSize: 28)),
                if (totalUnread > 0)
                  Positioned(
                    top: -6, right: -8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.error,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.white, width: 1.5),
                      ),
                      child: Text(totalUnread > 99 ? '99+' : '$totalUnread',
                          style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                    ),
                  ),
              ]),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Text(loc.get('dash_messages'),
                      style: AppTextStyles.labelLarge.copyWith(color: titleColor)),
                  if (totalUnread > 0) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(color: AppColors.error, borderRadius: BorderRadius.circular(10)),
                      child: Text('$totalUnread ${loc.get('dash_new')}',
                          style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ]),
                const SizedBox(height: 2),
                Text(
                  totalUnread > 0 ? '$totalUnread ${loc.get('dash_unread')}' : loc.get('dash_chat_with_customers'),
                  style: AppTextStyles.labelSmall.copyWith(
                    color: totalUnread > 0 ? AppColors.error : AppColors.grey500,
                    fontWeight: totalUnread > 0 ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ])),
              const Icon(Icons.arrow_forward_ios, color: AppColors.grey400, size: 16),
            ]),
          ),
        );
      },
    );
  }

  Widget _buildMenuItem(BuildContext context, {
    required String icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    final isDark     = Theme.of(context).brightness == Brightness.dark;
    final cardBg     = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final titleColor = isDark ? Colors.white : AppColors.black;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(14),
          boxShadow: isDark ? [] : [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Row(children: [
          Text(icon, style: const TextStyle(fontSize: 26)),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: AppTextStyles.labelLarge.copyWith(color: titleColor)),
            const SizedBox(height: 2),
            Text(subtitle, style: AppTextStyles.labelSmall.copyWith(color: AppColors.grey500, fontSize: 12)),
          ])),
          const Icon(Icons.arrow_forward_ios, color: AppColors.grey400, size: 16),
        ]),
      ),
    );
  }
}