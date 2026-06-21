import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/utils/image_utils.dart';
import '../../../config/theme/app_colors.dart';
import '../../../config/theme/app_text_styles.dart';
import '../../../core/app_localizations.dart';
import '../../../core/supabase_client.dart';
import '../models/chat_model.dart';
import '../services/chat_service.dart';
import 'chat_screen.dart';

class ChatListScreen extends StatefulWidget {
  final bool isSeller;
  final String? sellerId;

  const ChatListScreen({super.key, required this.isSeller, this.sellerId});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  final _service = ChatService();

  List<ChatModel> _cachedChats = [];
  bool _cacheLoaded = false;
  bool _isSelectionMode = false;
  final Set<String> _selectedIds = {};

  String get _cacheKey {
    final myId = supabase.auth.currentUser?.id ?? '';
    return widget.isSeller ? 'chats_seller_$myId' : 'chats_buyer_$myId';
  }

  @override
  void initState() {
    super.initState();
    _loadCache();
  }

  Future<void> _loadCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_cacheKey);
      if (raw == null) return;
      final list = (jsonDecode(raw) as List)
          .map((e) => ChatModel.fromJson(e as Map<String, dynamic>))
          .toList();
      if (mounted) setState(() { _cachedChats = list; _cacheLoaded = true; });
    } catch (_) {}
  }

  Future<void> _saveCache(List<ChatModel> chats) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cacheKey, jsonEncode(chats.map((c) => c.toJson()).toList()));
    } catch (_) {}
  }

  void _exitSelectionMode() => setState(() { _isSelectionMode = false; _selectedIds.clear(); });

  void _toggleSelection(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
        if (_selectedIds.isEmpty) _isSelectionMode = false;
      } else {
        _selectedIds.add(id);
      }
    });
  }

  void _selectAll(List<ChatModel> chats) =>
      setState(() => _selectedIds.addAll(chats.map((c) => c.id)));

  Future<void> _deleteSelected() async {
    final loc = AppLocalizations.of(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(loc.get('delete_chat')),
        content: Text('${_selectedIds.length} ${loc.get('delete_chat_confirm')}'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(loc.get('no')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(loc.get('yes'), style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    final toDelete = Set<String>.from(_selectedIds);
    setState(() => _cachedChats.removeWhere((c) => toDelete.contains(c.id)));
    _exitSelectionMode();
    await _saveCache(_cachedChats);

    for (final id in toDelete) {
      try {
        await _service.deleteChat(id, isSeller: widget.isSeller);
      } catch (e) {
        debugPrint('❌ deleteChat ката: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF121212) : const Color(0xFFF4F5F7);
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;

    final myId = supabase.auth.currentUser?.id ?? '';
    final stream = widget.isSeller
        ? _service.sellerChatsStream(widget.sellerId ?? myId)
        : _service.buyerChatsStream(myId);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: _isSelectionMode
          ? AppBar(
              backgroundColor: cardColor,
              elevation: 0,
              leading: IconButton(
                icon: Icon(Icons.close, color: theme.colorScheme.onSurface),
                onPressed: _exitSelectionMode,
              ),
              title: Text('${_selectedIds.length} ${loc.get('selected')}',
                  style: AppTextStyles.headingSmall),
              actions: [
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: AppColors.error),
                  onPressed: _selectedIds.isEmpty ? null : _deleteSelected,
                ),
              ],
            )
          : AppBar(
              backgroundColor: cardColor,
              elevation: 0,
              title: Text(loc.get('messages'), style: AppTextStyles.headingMedium),
            ),
      body: StreamBuilder<List<ChatModel>>(
        stream: stream,
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            final fresh = snapshot.data!;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              _saveCache(fresh);
              _cachedChats = fresh;
              _cacheLoaded = true;
            });
          }

          final isWaiting = snapshot.connectionState == ConnectionState.waiting;
          final showSkeleton = isWaiting && !_cacheLoaded;
          final chats = snapshot.hasData
              ? snapshot.data!
              : (_cacheLoaded ? _cachedChats : <ChatModel>[]);

          if (showSkeleton) return _ChatSkeletonList();

          if (chats.isEmpty && !isWaiting) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('💬', style: TextStyle(fontSize: 64)),
                  const SizedBox(height: 16),
                  Text(loc.get('no_chats'), style: AppTextStyles.headingSmall),
                ],
              ),
            );
          }

          return Column(
            children: [
              if (_isSelectionMode)
                Container(
                  color: cardColor,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => _selectAll(chats),
                      child: Text(
                        _selectedIds.length == chats.length
                            ? loc.get('deselect_all')
                            : loc.get('select_all'),
                        style: AppTextStyles.labelLarge,
                      ),
                    ),
                  ),
                ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: chats.length,
                  itemBuilder: (context, i) {
                    final chat = chats[i];
                    final unread = widget.isSeller ? chat.sellerUnread : chat.buyerUnread;
                    final hasProduct = !widget.isSeller &&
                        chat.productName != null &&
                        chat.productName!.isNotEmpty;
                    final isSelected = _selectedIds.contains(chat.id);

                    final displayName = widget.isSeller
                        ? (chat.buyerName.isNotEmpty ? chat.buyerName : chat.buyerId)
                        : chat.sellerName;

                    return GestureDetector(
                      onLongPress: () {
                        if (_isSelectionMode) return;
                        setState(() {
                          _isSelectionMode = true;
                          _selectedIds.add(chat.id);
                        });
                      },
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.primary.withValues(alpha: 0.08)
                              : cardColor,
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.04),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            )
                          ],
                        ),
                        child: ListTile(
                          isThreeLine: hasProduct,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 6),
                          leading: _isSelectionMode
                              ? Icon(
                                  isSelected
                                      ? Icons.check_circle_rounded
                                      : Icons.radio_button_unchecked,
                                  color: isSelected
                                      ? AppColors.primary
                                      : AppColors.grey300,
                                  size: 28,
                                )
                              : _ChatAvatar(chat: chat, isSeller: widget.isSeller),
                          title: Text(
                            displayName,
                            style: AppTextStyles.labelLarge,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (hasProduct) ...[
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    if (chat.productImage != null &&
                                        chat.productImage!.isNotEmpty)
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(6),
                                        child: CachedNetworkImage(
                                          imageUrl: toCloudinaryThumb(
                                              chat.productImage!, width: 80),
                                          width: 24,
                                          height: 24,
                                          fit: BoxFit.cover,
                                          errorWidget: (_, __, ___) => Container(
                                              width: 24,
                                              height: 24,
                                              color: AppColors.grey100),
                                        ),
                                      ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        chat.productName!,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: AppTextStyles.labelSmall.copyWith(
                                            color: AppColors.grey500,
                                            fontWeight: FontWeight.w600),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                              ],
                              Text(
                                chat.lastMessage.isNotEmpty
                                    ? chat.lastMessage
                                    : loc.get('new_chat'),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTextStyles.labelSmall
                                    .copyWith(color: AppColors.grey500),
                              ),
                            ],
                          ),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                chat.formattedTime,
                                style: AppTextStyles.labelSmall
                                    .copyWith(color: AppColors.grey400),
                              ),
                              if (unread > 0) ...[
                                const SizedBox(height: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 7, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppColors.error,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    unread > 99 ? '99+' : '$unread',
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          onTap: _isSelectionMode
                              ? () => _toggleSelection(chat.id)
                              : () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => ChatScreen.fromChat(
                                          chat,
                                          isSeller: widget.isSeller),
                                    ),
                                  ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// SKELETON
// ─────────────────────────────────────────────────────────────
class _ChatSkeletonList extends StatefulWidget {
  @override
  State<_ChatSkeletonList> createState() => _ChatSkeletonListState();
}

class _ChatSkeletonListState extends State<_ChatSkeletonList>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat(reverse: true);
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;

    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) {
        final shimmerColor = isDark
            ? Color.lerp(const Color(0xFF2C2C2C), const Color(0xFF3A3A3A), _anim.value)!
            : Color.lerp(const Color(0xFFE8E8E8), const Color(0xFFF5F5F5), _anim.value)!;
        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: 7,
          itemBuilder: (_, i) => Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2))
              ],
            ),
            child: Row(
              children: [
                Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                        color: shimmerColor, shape: BoxShape.circle)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                          height: 14,
                          width: double.infinity * 0.6,
                          decoration: BoxDecoration(
                              color: shimmerColor,
                              borderRadius: BorderRadius.circular(7))),
                      const SizedBox(height: 8),
                      Container(
                          height: 11,
                          width: 180,
                          decoration: BoxDecoration(
                              color: shimmerColor,
                              borderRadius: BorderRadius.circular(6))),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                    height: 10,
                    width: 38,
                    decoration: BoxDecoration(
                        color: shimmerColor,
                        borderRadius: BorderRadius.circular(5))),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────
// AVATAR
// ─────────────────────────────────────────────────────────────
class _ChatAvatar extends StatelessWidget {
  final ChatModel chat;
  final bool isSeller;
  const _ChatAvatar({required this.chat, required this.isSeller});

  @override
  Widget build(BuildContext context) {
    final url = isSeller ? chat.buyerAvatar : chat.sellerAvatar;
    final initial = isSeller
        ? (chat.buyerName.isNotEmpty ? chat.buyerName[0].toUpperCase() : '?')
        : (chat.sellerName.isNotEmpty ? chat.sellerName[0].toUpperCase() : '?');

    if (url.isNotEmpty) {
      return CircleAvatar(
        radius: 23,
        backgroundImage: NetworkImage(url),
        backgroundColor: AppColors.grey100,
      );
    }
    return CircleAvatar(
      radius: 23,
      backgroundColor: AppColors.primary.withValues(alpha: 0.15),
      child: Text(
        initial,
        style: const TextStyle(
            color: AppColors.primary,
            fontWeight: FontWeight.bold,
            fontSize: 16),
      ),
    );
  }
}