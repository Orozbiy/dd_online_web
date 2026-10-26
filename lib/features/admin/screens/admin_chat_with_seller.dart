import 'package:flutter/material.dart';

import '../../../config/theme/app_colors.dart';
import '../../../config/theme/app_text_styles.dart';
import '../../../core/supabase_client.dart';
import '../../seller/models/seller_model.dart';
import '../../chat/screens/chat_screen.dart';

// ══════════════════════════════════════════════════════
// Колдонуу (admin_panel_screen.dart ичинде):
//
//   import 'admin_chat_with_seller.dart';
//
//   void _showSendToSellerSheet(BuildContext context) {
//     showAdminChatSheet(context, _allSellers);
//   }
// ══════════════════════════════════════════════════════

void showAdminChatSheet(BuildContext context, List<SellerModel> sellers) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _AdminChatSellerSheet(sellers: sellers),
  );
}

class _AdminChatSellerSheet extends StatefulWidget {
  final List<SellerModel> sellers;
  const _AdminChatSellerSheet({required this.sellers});

  @override
  State<_AdminChatSellerSheet> createState() => _AdminChatSellerSheetState();
}

class _AdminChatSellerSheetState extends State<_AdminChatSellerSheet> {
  final _searchCtrl = TextEditingController();
  String _query = '';
  bool _opening = false;

  // seller_id → {last_time, unread_count}
  Map<String, Map<String, dynamic>> _chatMeta = {};
  // ignore: unused_field
  bool _metaLoaded = false;

  // Сортировкаланган тизме: акыркы SMS бар болсо алды, жок болсо арты
  List<SellerModel> get _sorted {
    final list = List<SellerModel>.from(widget.sellers);
    list.sort((a, b) {
      final ta = _chatMeta[a.uid]?['last_time'] as String?;
      final tb = _chatMeta[b.uid]?['last_time'] as String?;
      if (ta == null && tb == null) return 0;
      if (ta == null) return 1;
      if (tb == null) return -1;
      return tb.compareTo(ta); // акыркы биринчи
    });
    return list;
  }

  List<SellerModel> get _filtered {
    final base = _sorted;
    if (_query.isEmpty) return base;
    final q = _query.toLowerCase();
    return base
        .where((s) =>
            s.shopName.toLowerCase().contains(q) ||
            s.name.toLowerCase().contains(q) ||
            s.containerNumber.toLowerCase().contains(q))
        .toList();
  }

  @override
  void initState() {
    super.initState();
    _loadChatMeta();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  // Бардык admin чаттарынын акыркы убактысын жана окулбагандарын жүктөйт
  Future<void> _loadChatMeta() async {
    try {
      final adminId = supabase.auth.currentUser?.id;
      if (adminId == null) return;

      final rows = await supabase
          .from('chats')
          .select('seller_id, last_message_at, buyer_unread')
          .eq('buyer_id', adminId)
          .filter('product_id', 'is', 'null');

      final meta = <String, Map<String, dynamic>>{};
      for (final row in (rows as List)) {
        final sellerId = row['seller_id'] as String;
        final time = row['last_message_at'] as String?;
        final unread = (row['buyer_unread'] as num?)?.toInt() ?? 0;
        meta[sellerId] = {'last_time': time, 'unread': unread};
      }

      if (mounted) setState(() {
        _chatMeta = meta;
        _metaLoaded = true;
      });
    } catch (_) {
      if (mounted) setState(() => _metaLoaded = true);
    }
  }

  Future<String> _getOrCreateChat({
    required String adminId,
    required String sellerId,
  }) async {
    final rows = await supabase
        .from('chats')
        .select('id')
        .eq('buyer_id', adminId)
        .eq('seller_id', sellerId)
        .filter('product_id', 'is', 'null')
        .limit(1);

    if ((rows as List).isNotEmpty) return rows.first['id'] as String;

    final inserted = await supabase
        .from('chats')
        .insert({
          'buyer_id': adminId,
          'seller_id': sellerId,
          'product_id': null,
          'seller_name': '',
          'last_message': '',
        })
        .select('id')
        .single();

    return inserted['id'] as String;
  }

  Future<void> _openChat(SellerModel seller) async {
    if (_opening) return;
    setState(() => _opening = true);

    try {
      final adminId = supabase.auth.currentUser?.id;
      if (adminId == null) return;

      // Окулбаган санды дароо 0 кылабыз
      if ((_chatMeta[seller.uid]?['unread'] ?? 0) > 0) {
        setState(() {
          _chatMeta[seller.uid]?['unread'] = 0;
        });
      }

      final chatId = await _getOrCreateChat(
        adminId: adminId,
        sellerId: seller.uid,
      );

      if (!mounted) return;

      // Navigator.of сактап алабыз — pop кийин context жарактуу болбой калышы мүмкүн
      final nav = Navigator.of(context);
      nav.pop(); // sheet'ти жап

      nav.push(
        MaterialPageRoute(
          builder: (_) => ChatScreen(
            chatId: chatId,
            sellerName: seller.shopName,
            productId: null,
            productName: '',
            productImage: '',
            isSeller: false, // Admin кардар ролунда жазат
            buyerId: adminId,
            sellerId: seller.uid,
            otherAvatarUrl: '',
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ката: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      // Ар дайым _opening = false — эске алынсын!
      if (mounted) setState(() => _opening = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sheetBg = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final fillColor = isDark ? const Color(0xFF2C2C2C) : const Color(0xFFF5F5F5);
    final textColor = isDark ? Colors.white : AppColors.black;
    final subColor = isDark ? Colors.white60 : AppColors.grey500;
    final items = _filtered;

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
            // ── Handle ──
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // ── Башлык ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF1E40AF), Color(0xFF3B82F6)],
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.chat_rounded,
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

            // ── Издөө ──
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

            // ── Сатуучулар тизмеси ──
            Expanded(
              child: items.isEmpty
                  ? Center(
                      child: Text('Табылган жок',
                          style:
                              AppTextStyles.bodySmall.copyWith(color: subColor)),
                    )
                  : ListView.builder(
                      controller: scrollCtrl,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      itemCount: items.length,
                      itemBuilder: (_, i) {
                        final s = items[i];
                        final unread =
                            (_chatMeta[s.uid]?['unread'] as int?) ?? 0;
                        final hasChat = _chatMeta.containsKey(s.uid);

                        return ListTile(
                          onTap: _opening ? null : () => _openChat(s),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          leading: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              CircleAvatar(
                                backgroundColor: const Color(0xFF1E40AF)
                                    .withValues(alpha: 0.15),
                                child: Text(
                                  s.shopName.isNotEmpty
                                      ? s.shopName[0].toUpperCase()
                                      : '🏪',
                                  style: const TextStyle(
                                      color: Color(0xFF1E40AF),
                                      fontWeight: FontWeight.bold),
                                ),
                              ),
                              if (unread > 0)
                                Positioned(
                                  top: -3,
                                  right: -3,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 5, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AppColors.error,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                          color: sheetBg, width: 1.5),
                                    ),
                                    child: Text(
                                      '$unread',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          title: Text(s.shopName,
                              style: AppTextStyles.labelLarge
                                  .copyWith(color: textColor)),
                          subtitle: Text(
                            '${s.name}  •  ${s.containerNumber}',
                            style: AppTextStyles.labelSmall
                                .copyWith(color: subColor),
                          ),
                          trailing: _opening
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: AppColors.primary),
                                )
                              : hasChat
                                  ? const Icon(
                                      Icons.chat_bubble_rounded,
                                      color: AppColors.primary,
                                      size: 20,
                                    )
                                  : Icon(
                                      Icons.chat_bubble_outline_rounded,
                                      color: AppColors.grey400,
                                      size: 20,
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