// lib/features/chat/screens/chat_list_screen.dart

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../config/theme/app_colors.dart';
import '../../../../config/theme/app_text_styles.dart';
import '../../../../core/app_localizations.dart';
import '../../../../core/supabase_client.dart';
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

  // ── 2 секунд long-press үчүн Timer ──
  Timer? _longPressTimer;

  String get _cacheKey {
    final myId = supabase.auth.currentUser?.id ?? '';
    return widget.isSeller ? 'chats_seller_$myId' : 'chats_buyer_$myId';
  }

  @override
  void initState() {
    super.initState();
    _loadCache();
  }

  @override
  void dispose() {
    _longPressTimer?.cancel();
    super.dispose();
  }

  // ════════════════════════════════════════════════════
  // КЭШТЕР
  // ════════════════════════════════════════════════════

  Future<void> _loadCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_cacheKey);
      if (raw == null) return;
      final list = (jsonDecode(raw) as List)
          .map((e) => ChatModel.fromJson(e as Map<String, dynamic>))
          .toList();
      if (mounted) {
        setState(() {
          _cachedChats = list;
          _cacheLoaded = true;
        });
      }
    } catch (_) {}
  }

  Future<void> _saveCache(List<ChatModel> chats) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          _cacheKey, jsonEncode(chats.map((c) => c.toJson()).toList()));
    } catch (_) {}
  }

  Future<void> _clearCacheKey() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_cacheKey);
    } catch (_) {}
  }

  // ════════════════════════════════════════════════════
  // SELECTION MODE
  // ════════════════════════════════════════════════════

  void _exitSelectionMode() => setState(() {
        _isSelectionMode = false;
        _selectedIds.clear();
      });

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

  void _selectAll(List<ChatModel> chats) => setState(
      () => _selectedIds.addAll(chats.map((c) => c.id)));

  void _deselectAll() => setState(() => _selectedIds.clear());

  // ════════════════════════════════════════════════════
  // 2 СЕКУНД LONG-PRESS ЛОГИКАСЫ
  // ════════════════════════════════════════════════════

  void _onPressStart(String chatId) {
    if (_isSelectionMode) return; // Selection mode'до жөн tap иштесин
    _longPressTimer?.cancel();

    _longPressTimer = Timer(const Duration(seconds: 2), () {
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      setState(() {
        _isSelectionMode = true;
        _selectedIds.add(chatId);
      });
    });
  }

  void _onPressEnd() {
    _longPressTimer?.cancel();
    _longPressTimer = null;
  }

  // ════════════════════════════════════════════════════
  // ӨЧҮРҮҮ (кэш + Supabase)
  // ════════════════════════════════════════════════════

  Future<void> _deleteSelected() async {
    final loc = AppLocalizations.of(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(loc.get('delete_chat')),
        content: Text(
            '${_selectedIds.length} ${loc.get('delete_chat_confirm')}'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(loc.get('no')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(loc.get('yes'),
                style: const TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    final toDelete = Set<String>.from(_selectedIds);

    // UI'дан дароо алып салуу
    setState(
        () => _cachedChats.removeWhere((c) => toDelete.contains(c.id)));
    _exitSelectionMode();

    // ✅ Кэшти жаңыртуу (өчүрүлгөндөр жок)
    await _saveCache(_cachedChats);

    // Supabase'тен өчүрүү
    for (final id in toDelete) {
      try {
        await _service.deleteChat(id, isSeller: widget.isSeller);
      } catch (e) {
        debugPrint('❌ deleteChat ката: $e');
      }
    }
  }

  // ════════════════════════════════════════════════════
  // BUILD
  // ════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bgColor =
        isDark ? const Color(0xFF121212) : const Color(0xFFF4F5F7);
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
                icon: Icon(Icons.close,
                    color: theme.colorScheme.onSurface),
                onPressed: _exitSelectionMode,
              ),
              title: Text(
                  '${_selectedIds.length} ${loc.get('selected')}',
                  style: AppTextStyles.headingSmall),
              actions: [
                // ── Баарын тандоо / алып салуу ──
                StreamBuilder<List<ChatModel>>(
                  stream: stream,
                  builder: (context, snap) {
                    final chats =
                        snap.data ?? _cachedChats;
                    final allSelected =
                        chats.isNotEmpty &&
                            _selectedIds.length == chats.length;
                    return TextButton(
                      onPressed: () => allSelected
                          ? _deselectAll()
                          : _selectAll(chats),
                      child: Text(
                        allSelected
                            ? loc.get('deselect_all')
                            : loc.get('select_all'),
                        style: AppTextStyles.labelLarge.copyWith(
                            color: AppColors.primary),
                      ),
                    );
                  },
                ),
                // ── Өчүрүү баскычы ──
                IconButton(
                  icon: const Icon(Icons.delete_outline,
                      color: AppColors.error),
                  onPressed:
                      _selectedIds.isEmpty ? null : _deleteSelected,
                ),
              ],
            )
          : AppBar(
              backgroundColor: cardColor,
              elevation: 0,
              title: Text(
                loc.get('messages'),
                style: AppTextStyles.headingMedium.copyWith(
                  color: isDark ? Colors.white : AppColors.black,
                ),
              ),
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

          final isWaiting =
              snapshot.connectionState == ConnectionState.waiting;
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
                  const Text('💬',
                      style: TextStyle(fontSize: 64)),
                  const SizedBox(height: 16),
                  Text(loc.get('no_chats'),
                      style: AppTextStyles.headingSmall),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: chats.length,
            itemBuilder: (context, i) {
              final chat = chats[i];
              final unread = widget.isSeller
                  ? chat.sellerUnread
                  : chat.buyerUnread;
              final hasProduct = !widget.isSeller &&
                  chat.productName != null &&
                  chat.productName!.isNotEmpty;
              final isSelected = _selectedIds.contains(chat.id);

              final displayName = widget.isSeller
                  ? (chat.buyerName.isNotEmpty
                      ? chat.buyerName
                      : chat.buyerId)
                  : chat.sellerName;

              return GestureDetector(
                // ── 2 секунд basып туруу ──
                onLongPressStart: (_) => _onPressStart(chat.id),
                onLongPressEnd: (_) => _onPressEnd(),
                onLongPressCancel: _onPressEnd,
                // ── Tap: selection же navigate ──
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
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.primary.withValues(alpha: 0.08)
                        : cardColor,
                    borderRadius: BorderRadius.circular(14),
                    border: isSelected
                        ? Border.all(
                            color: AppColors.primary.withValues(alpha: 0.3),
                            width: 1.5)
                        : null,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
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
                                : AppColors.grey400,
                            size: 26,
                          )
                        : CircleAvatar(
                            radius: 24,
                            backgroundImage: _avatarUrl(chat) != null
                                ? NetworkImage(_avatarUrl(chat)!)
                                : null,
                            backgroundColor: AppColors.grey200,
                            child: _avatarUrl(chat) == null
                                ? const Icon(Icons.person,
                                    color: AppColors.grey400, size: 22)
                                : null,
                          ),
                    title: Text(displayName,
                        style: AppTextStyles.bodyLarge,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (hasProduct)
                          Text(
                            '📦 ${chat.productName}',
                            style: AppTextStyles.labelSmall.copyWith(
                                color: AppColors.grey500),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        Text(
                          chat.lastMessage,
                          style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.grey600),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          _formatTime(chat.lastTime),
                          style: AppTextStyles.labelSmall
                              .copyWith(color: AppColors.grey500),
                        ),
                        if (unread > 0) ...[
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.primary,
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
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  // ════════════════════════════════════════════════════
  // ЖАРДАМЧЫ МЕТОДДОР
  // ════════════════════════════════════════════════════

  String? _avatarUrl(ChatModel chat) {
    if (widget.isSeller) return chat.buyerAvatar;
    return chat.sellerAvatar;
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inDays == 0) {
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } else if (diff.inDays == 1) {
      return 'кечээ';
    } else if (diff.inDays < 7) {
      const days = ['Дшм', 'Шшм', 'Срш', 'Бшм', 'Жмк', 'Ишм', 'Жкш'];
      return days[dt.weekday - 1];
    } else {
      return '${dt.day}.${dt.month.toString().padLeft(2, '0')}';
    }
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
            ? Color.lerp(const Color(0xFF2C2C2C), const Color(0xFF3A3A3A),
                _anim.value)!
            : Color.lerp(const Color(0xFFE8E8E8), const Color(0xFFF5F5F5),
                _anim.value)!;

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: 6,
          itemBuilder: (_, __) => Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                CircleAvatar(radius: 24, backgroundColor: shimmerColor),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                          height: 13,
                          width: 120,
                          decoration: BoxDecoration(
                              color: shimmerColor,
                              borderRadius: BorderRadius.circular(6))),
                      const SizedBox(height: 6),
                      Container(
                          height: 11,
                          width: 180,
                          decoration: BoxDecoration(
                              color: shimmerColor,
                              borderRadius: BorderRadius.circular(6))),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}