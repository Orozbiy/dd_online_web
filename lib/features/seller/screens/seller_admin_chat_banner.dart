// ignore_for_file: unnecessary_cast

import 'package:flutter/material.dart';

import '../../../config/theme/app_colors.dart';
import '../../../core/app_localizations.dart';
import '../../../core/supabase_client.dart';
import '../../chat/screens/chat_screen.dart';

// ══════════════════════════════════════════════════════
// Колдонуу (seller_dashboard_screen.dart ичинде):
//
//   import 'seller_admin_chat_banner.dart';
//
//   // Build ичинде:
//   SellerAdminChatBanner(isDark: isDark, sellerUid: _seller!.uid),
// ══════════════════════════════════════════════════════

class SellerAdminChatBanner extends StatefulWidget {
  final bool isDark;
  final String sellerUid;

  const SellerAdminChatBanner({
    super.key,
    required this.isDark,
    required this.sellerUid,
  });

  @override
  State<SellerAdminChatBanner> createState() => _SellerAdminChatBannerState();
}

class _SellerAdminChatBannerState extends State<SellerAdminChatBanner> {
  Map<String, dynamic>? _adminChat;
  int _unread = 0;
  bool _loaded = false;
  bool _opening = false;

  @override
  void initState() {
    super.initState();
    _loadAdminChat();
  }

  Future<void> _loadAdminChat() async {
    try {
      final rows = await supabase
          .from('chats')
          .select('id, buyer_id, seller_unread')
          .eq('seller_id', widget.sellerUid)
          .filter('product_id', 'is', 'null')
          .order('created_at', ascending: false)
          .limit(1);

      if (mounted) {
        if ((rows as List).isNotEmpty) {
          final chat = rows.first;
          setState(() {
            _adminChat = chat;
            _unread = (chat['seller_unread'] as num?)?.toInt() ?? 0;
            _loaded = true;
          });
        } else {
          setState(() => _loaded = true);
        }
      }
    } catch (_) {
      if (mounted) setState(() => _loaded = true);
    }
  }

  // ⚠️ ADMIN UID — Supabase → Authentication → Users бетинен тапкан UIДды ушул жерге жаз
  // же Supabase SQL Editor'до: SELECT id FROM auth.users WHERE email = 'admin@email.com';
  static const String? _hardcodedAdminUid = 'e4bb3f01-cdd3-46d8-be98-4a0a2a7870d8';

  Future<String?> _getAdminUid() async {
    // 1️⃣ Эгер кол менен жазылган болсо — ошону колдон
    if (_hardcodedAdminUid != null && _hardcodedAdminUid!.isNotEmpty) {
      return _hardcodedAdminUid;
    }

    // 2️⃣ profiles таблицасынан role='admin' менен издейбиз
    try {
      final rows = await supabase
          .from('profiles')
          .select('id')
          .eq('role', 'admin')
          .limit(1);
      if ((rows as List).isNotEmpty) {
        return rows.first['id'] as String?;
      }
    } catch (_) {}

    // 3️⃣ sellers таблицасынан издейбиз (is_admin же role колонкасы болсо)
    try {
      final rows = await supabase
          .from('sellers')
          .select('uid')
          .eq('is_admin', true)
          .limit(1);
      if ((rows as List).isNotEmpty) {
        return rows.first['uid'] as String?;
      }
    } catch (_) {}

    return null;
  }

  Future<void> _openOrCreateChat() async {
    final loc = AppLocalizations.of(context);
    if (_opening) return;
    setState(() => _opening = true);

    try {
      // Учурдагы чат бар болсо — ачат
      if (_adminChat != null) {
        final chatId = _adminChat!['id'] as String;

        // Окулбаган санды дароо 0 кылабыз (UI жооптуу болсун)
        if (_unread > 0) {
          setState(() => _unread = 0);
          supabase
              .from('chats')
              .update({'seller_unread': 0})
              .eq('id', chatId)
              .catchError((_) {});
        }

        if (!mounted) return;
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ChatScreen(
              chatId: chatId,
              sellerName: 'Админ',
              productId: null,
              productName: '',
              productImage: '',
              isSeller: true,
              buyerId: _adminChat!['buyer_id'] as String,
              sellerId: widget.sellerUid,
              otherAvatarUrl: '',
            ),
          ),
        );
        await _loadAdminChat();
        return;
      }

      // Чат жок болсо — администратордун ID'ын табат
      final adminId = await _getAdminUid();
      if (adminId == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(loc.get('admin_not_found')),
              backgroundColor: AppColors.error,
            ),
          );
        }
        return;
      }

      // Жаңы чат жасайбыз (сатуучу баштайт — ал эми seller, admin buyer)
      // Дагы бир жолу текшеребиз (race condition болбосун)
      final checkRows = await supabase
          .from('chats')
          .select('id, buyer_id, seller_unread')
          .eq('buyer_id', adminId)
          .eq('seller_id', widget.sellerUid)
          .filter('product_id', 'is', 'null')
          .limit(1);

      if ((checkRows as List).isNotEmpty) {
        setState(() => _adminChat = checkRows.first as Map<String, dynamic>);
        // Чат табылды — жаңысын жасабайбыз, төмөндөгү push иштейт
      } else {
        final insertRows = await supabase
            .from('chats')
            .insert({
              'buyer_id': adminId,
              'seller_id': widget.sellerUid,
              'product_id': null,
              'seller_name': '',
              'last_message': '',
            })
            .select('id, buyer_id, seller_unread');
        setState(() => _adminChat = (insertRows as List).first as Map<String, dynamic>);
      }
      final inserted = _adminChat!;

      if (!mounted) return;

      setState(() => _adminChat = inserted);

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatScreen(
            chatId: inserted['id'] as String,
            sellerName: 'Админ',
            productId: null,
            productName: '',
            productImage: '',
            isSeller: true,
            buyerId: adminId,
            sellerId: widget.sellerUid,
            otherAvatarUrl: '',
          ),
        ),
      );
      await _loadAdminChat();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${loc.get('error')}: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final loc = AppLocalizations.of(context);
    final isRu = loc.locale.languageCode == 'ru';
    final cardBg = isDark ? const Color(0xFF1E1A2E) : const Color(0xFFFFF8F0);
    final borderColor =
        const Color(0xFFD97706).withValues(alpha: isDark ? 0.4 : 0.35);

    return GestureDetector(
      onTap: _opening ? null : _openOrCreateChat,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderColor),
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
            // ── Иконка ──
            Stack(
              clipBehavior: Clip.none,
              children: [
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
                  child: _opening
                      ? const Center(
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          ),
                        )
                      : const Icon(
                          Icons.support_agent_rounded,
                          color: Colors.white,
                          size: 22,
                        ),
                ),
                if (_loaded && _unread > 0)
                  Positioned(
                    top: -5,
                    right: -5,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.error,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isDark
                              ? const Color(0xFF1E1A2E)
                              : const Color(0xFFFFF8F0),
                          width: 1.5,
                        ),
                      ),
                      child: Text(
                        '$_unread',
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
            const SizedBox(width: 14),

            // ── Текст ──
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isRu ? 'Уведомления от администратора' : 'Админден билдирүүлөр',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : AppColors.black,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    _opening
                        ? (isRu ? 'Открывается...' : 'Ачылып жатат...')
                        : !_loaded
                            ? '...'
                            : _unread > 0
                                ? (isRu ? 'Есть $_unread непрочитанных' : '$_unread окулбаган билдирүү бар')
                                : (isRu ? 'Напишите администратору в чате' : 'Админ менен чатта сүйлөшүңүз'),
                    style: TextStyle(
                      fontSize: 12,
                      color: _unread > 0 ? AppColors.error : AppColors.grey500,
                      fontWeight:
                          _unread > 0 ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),

            // ── Жебе ──
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
    );
  }
}