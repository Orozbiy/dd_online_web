// lib/features/chat/screens/chat_list_screen.dart

import 'dart:async';
import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../config/theme/app_colors.dart';
import '../../../../config/theme/dd_design.dart';
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

  void _selectAll(List<ChatModel> chats) =>
      setState(() => _selectedIds.addAll(chats.map((c) => c.id)));

  void _deselectAll() => setState(() => _selectedIds.clear());

  void _onPressStart(String chatId) {
    _longPressTimer?.cancel();
    if (_isSelectionMode) {
      _toggleSelection(chatId);
      return;
    }
    _longPressTimer = Timer(const Duration(seconds: 0), () {
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

  Future<void> _deleteSelected() async {
    final loc = AppLocalizations.of(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(loc.get('delete_chat')),
        content: Text('${_selectedIds.length} ${loc.get('delete_chat_confirm')}'),
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
    setState(() => _cachedChats.removeWhere((c) => toDelete.contains(c.id)));
    _exitSelectionMode();
    await _saveCache(_cachedChats);

   final prefs = await SharedPreferences.getInstance();
for (final id in toDelete) {
  try {
    // ← смс кэшин тазала
    await prefs.remove('messages_$id');
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

    final appBarBg = isDark
        ? Colors.black.withOpacity(0.55)
        : Colors.white.withOpacity(0.95);

    // ── Чат карточка фону ──
    final cardBg = isDark
        ? Colors.white.withOpacity(0.06)
        : Colors.white;

    // ── Scaffold фону: сатуучудан ачылса таза ак/кара ──
    final scaffoldBg = isDark ? DD.bgDark : DD.bgLight;

    final myId = supabase.auth.currentUser?.id ?? '';
    final stream = widget.isSeller
        ? _service.sellerChatsStream(widget.sellerId ?? myId)
        : _service.buyerChatsStream(myId);

    return Scaffold(
      backgroundColor: scaffoldBg,
      extendBodyBehindAppBar: false,

      // ── AppBar — размытие ──
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: _isSelectionMode
                ? AppBar(
                    backgroundColor: appBarBg,
                    elevation: 0,
                    leading: IconButton(
                      icon: Icon(Icons.close, color: theme.colorScheme.onSurface),
                      onPressed: _exitSelectionMode,
                    ),
                    title: Text(
                      '${_selectedIds.length} ${loc.get('selected')}',
                      style: AppTextStyles.headingSmall,
                    ),
                    actions: [
                      StreamBuilder<List<ChatModel>>(
                        stream: stream,
                        builder: (context, snap) {
                          final chats = snap.data ?? _cachedChats;
                          final allSelected = chats.isNotEmpty &&
                              _selectedIds.length == chats.length;
                          return TextButton(
                            onPressed: () => allSelected
                                ? _deselectAll()
                                : _selectAll(chats),
                            child: Text(
                              allSelected
                                  ? loc.get('deselect_all')
                                  : loc.get('select_all'),
                              style: AppTextStyles.labelLarge
                                  .copyWith(color: DD.accent),
                            ),
                          );
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline,
                            color: AppColors.error),
                        onPressed:
                            _selectedIds.isEmpty ? null : _deleteSelected,
                      ),
                    ],
                  )
                : AppBar(
                    backgroundColor: appBarBg,
                    elevation: 0,
                    title: Text(
                      loc.get('messages'),
                      style: AppTextStyles.headingSmall.copyWith(
                        color: isDark ? Colors.white : AppColors.black,
                      ),
                    ),
                  ),
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
                  const Text('💬', style: TextStyle(fontSize: 64)),
                  const SizedBox(height: 16),
                  Text(loc.get('no_chats'), style: AppTextStyles.headingSmall),
                ],
              ),
            );
          }

          return ListView.builder(
            // ── AppBar бийиктигин эсепке алуу ──
            padding: EdgeInsets.fromLTRB(
                12, kToolbarHeight + MediaQuery.of(context).padding.top + 8, 12, 12),
            itemCount: chats.length,
            itemBuilder: (context, i) {
              final chat = chats[i];
              final unread =
                  widget.isSeller ? chat.sellerUnread : chat.buyerUnread;
              final hasProduct = !widget.isSeller &&
                  chat.productName != null &&
                  chat.productName!.isNotEmpty;
              final isSelected = _selectedIds.contains(chat.id);

              final displayName = widget.isSeller
                  ? (chat.buyerName.isNotEmpty ? chat.buyerName : chat.buyerId)
                  : chat.sellerName;

              return GestureDetector(
                onLongPressStart: (_) => _onPressStart(chat.id),
                onLongPressEnd: (_) => _onPressEnd(),
                onLongPressCancel: _onPressEnd,
              onTap: _isSelectionMode
    ? () => _toggleSelection(chat.id)
    : () async {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                ChatScreen.fromChat(chat, isSeller: widget.isSeller),
          ),
        );
        // Кайткандан кийин кэшти жаңырт (жаңы чат тизмеде чыксын)
        if (mounted) await _loadCache();
      },
                child: AnimatedContainer(
                 duration: const Duration(milliseconds: 10),
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    // ── Жарым өткөрүмдүү карточка ──
                    color: isSelected
                        ? DD.accent.withValues(alpha: 0.12)
                        : cardBg,
                    borderRadius: BorderRadius.circular(DD.rCard),
                    border: isSelected
                        ? Border.all(
                            color: DD.accent.withValues(alpha: 0.4),
                            width: 1.5)
                        : Border.all(
                            color: isDark
                                ? Colors.white.withOpacity(0.08)
                                : const Color(0xFFE8EAED),
                            width: 1.0),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.04),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ListTile(
                    isThreeLine: hasProduct,
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    leading: _isSelectionMode
                        ? Icon(
                            isSelected
                                ? Icons.check_circle_rounded
                                : Icons.radio_button_unchecked,
                            color: isSelected ? DD.accent : AppColors.grey400,
                            size: 26,
                          )
                       : Container(
    padding: const EdgeInsets.all(2),
    decoration: const BoxDecoration(
      gradient: DD.accentGradient,
      shape: BoxShape.circle,
    ),
    child: CircleAvatar(
      radius: 22,
      backgroundImage: (_avatarUrl(chat) != null && _avatarUrl(chat)!.isNotEmpty)
          ? NetworkImage(_avatarUrl(chat)!)
          : null,
      backgroundColor: DD.accent,
      child: (_avatarUrl(chat) == null || _avatarUrl(chat)!.isEmpty)
          ? Text(
              _getInitial(chat),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 17,
              ),
            )
          : null,
    ),
  ),
                    title: Text(displayName,
                        style: AppTextStyles.bodyLarge.copyWith(
                          color: isDark ? Colors.white : AppColors.black,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (hasProduct)
                          Text(
                            '📦 ${chat.productName}',
                            style: AppTextStyles.labelSmall
                                .copyWith(color: AppColors.grey500),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        Text(
                          chat.lastMessage,
                          style: AppTextStyles.bodySmall
                              .copyWith(color: AppColors.grey600),
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
                              gradient: DD.accentGradient,
                              borderRadius: BorderRadius.circular(DD.rPill),
                              boxShadow: [
                                BoxShadow(
                                  color: DD.accent.withValues(alpha: 0.4),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Text(
                              unread > 99 ? '99+' : '$unread',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
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

  String? _avatarUrl(ChatModel chat) {
    if (widget.isSeller) return chat.buyerAvatar;
    return chat.sellerAvatar;
  }
  String _getInitial(ChatModel chat) {
  final name = widget.isSeller
      ? (chat.buyerName.isNotEmpty ? chat.buyerName : '?')
      : (chat.sellerName.isNotEmpty ? chat.sellerName : '?');
  return name[0].toUpperCase();
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

    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) {
        final shimmerColor = isDark
            ? Color.lerp(const Color(0xFF2C2C2C), const Color(0xFF3A3A3A),
                _anim.value)!
            : Color.lerp(const Color(0xFFE8E8E8), const Color(0xFFF5F5F5),
                _anim.value)!;

        final cardBg = isDark
            ? Colors.white.withOpacity(0.06)
            : Colors.white;

        return ListView.builder(
          padding: EdgeInsets.fromLTRB(
              12,
              kToolbarHeight + MediaQuery.of(context).padding.top + 8,
              12,
              12),
          itemCount: 6,
          itemBuilder: (_, __) => Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isDark
                    ? Colors.white.withOpacity(0.08)
                    : const Color(0xFFE8EAED),
                width: 1.0,
              ),
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