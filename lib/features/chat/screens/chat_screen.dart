import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:dd_online/features/admin/widgets/voice_record_button.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import '../../../config/theme/app_colors.dart';
import '../../../config/theme/app_text_styles.dart';
import '../../../core/app_localizations.dart';
import '../../../core/supabase_client.dart';
import '../../../core/utils/image_utils.dart';
import '../../../services/notification_service.dart';
import '../models/chat_model.dart';
import '../models/message_model.dart';
import '../services/chat_service.dart';
import '../widgets/message_bubble.dart';

import '../widgets/chat_product_banner.dart';

class ChatScreen extends StatefulWidget {
  final String chatId;
  final String sellerName;
  final String? productId;
  final String productName;
  final String productImage;
  final bool isSeller;
  final String buyerId;
  final String sellerId;
  final String otherAvatarUrl;

  const ChatScreen({
    super.key,
    required this.chatId,
    required this.sellerName,
    this.productId,
    required this.productName,
    required this.productImage,
    required this.isSeller,
    required this.buyerId,
    required this.sellerId,
    this.otherAvatarUrl = '',
  });

  factory ChatScreen.fromChat(ChatModel chat, {required bool isSeller}) {
    return ChatScreen(
      chatId:         chat.id,
      sellerName:     chat.sellerName,
      productName:    chat.productName ?? '',
      productImage:   chat.productImage ?? '',
      isSeller:       isSeller,
      buyerId:        chat.buyerId,
      sellerId:       chat.sellerId,
      otherAvatarUrl: isSeller ? chat.buyerAvatar : chat.sellerAvatar,
    );
  }

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  static const _cloudName    = 'dedwm4krp';
  static const _uploadPreset = 'dd-online';

  final _service    = ChatService();
  final _msgCtrl    = TextEditingController();
  final _scrollCtrl = ScrollController();

  bool _isSendingImage = false;
  bool _hasText        = false;

  List<MessageModel> _cachedMessages = [];
  bool _initialLoadDone = false;
  late final Stream<List<MessageModel>> _messagesStream;
  StreamSubscription<List<MessageModel>>? _msgSub;

  bool _isSelectionMode = false;
  final Set<String> _selectedIds = {};

  MessageModel? _replyingTo;

  String? get _myId => supabase.auth.currentUser?.id;
  String _myDisplayName       = '';
  String _receiverDisplayName = '';

  @override
  void initState() {
    super.initState();
    _messagesStream = _service.messagesStream(widget.chatId);
    _msgSub = _messagesStream.listen((msgs) {
      if (!mounted) return;
      setState(() { _cachedMessages = msgs; _initialLoadDone = true; });
      final myId = _myId;
      if (myId != null && msgs.any((m) => m.senderId != myId && !m.isRead)) _markRead();
    });
    _markRead();
    _loadMyName();
    _msgCtrl.addListener(() {
      final has = _msgCtrl.text.trim().isNotEmpty;
      if (has != _hasText) setState(() => _hasText = has);
    });
  }

  @override
  void dispose() {
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    _msgSub?.cancel();
    super.dispose();
  }

  Future<void> _loadMyName() async {
    try {
      final myId = _myId;
      if (myId == null) return;

      if (widget.isSeller) {
        final storeRow = await supabase
            .from('stores')
            .select('store_name')
            .eq('owner_id', myId)
            .maybeSingle();
        if (storeRow != null && mounted) {
          setState(() => _myDisplayName = storeRow['store_name'] as String? ?? '');
        }
        final buyerRow = await supabase
            .from('profiles')
            .select('full_name')
            .eq('id', widget.buyerId)
            .maybeSingle();
        if (buyerRow != null && mounted) {
          setState(() => _receiverDisplayName = buyerRow['full_name'] as String? ?? '');
        }
      } else {
        final profileRow = await supabase
            .from('profiles')
            .select('full_name')
            .eq('id', myId)
            .maybeSingle();
        if (profileRow != null && mounted) {
          setState(() => _myDisplayName = profileRow['full_name'] as String? ?? '');
        }
        if (mounted) setState(() => _receiverDisplayName = widget.sellerName);
      }
    } catch (e) {
      debugPrint('⚠️ _loadMyName ката: $e');
    }
  }

  Future<void> _markRead() async {
    final myId = _myId;
    if (myId == null) return;
    await _service.markAsRead(chatId: widget.chatId, myUserId: myId, readerIsBuyer: !widget.isSeller);
  }

  void _scrollToBottom() {
    if (_scrollCtrl.hasClients) {
      Future.delayed(const Duration(milliseconds: 100), () {
        if (_scrollCtrl.hasClients) _scrollCtrl.animateTo(0, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
      });
    }
  }

  String get _receiverUid => widget.isSeller ? widget.buyerId : widget.sellerId;

  String get _senderDisplayName => widget.isSeller
      ? (_myDisplayName.isNotEmpty ? _myDisplayName : '')
      : widget.sellerName;

  void _send() {
    final loc  = AppLocalizations.of(context);
    final text = _msgCtrl.text.trim();
    final myId = _myId;
    if (text.isEmpty || myId == null) return;
    _msgCtrl.clear();
    final replyTo = _replyingTo;
    if (replyTo != null) setState(() => _replyingTo = null);
    _service.sendMessage(
      chatId:      widget.chatId,
      senderId:    myId,
      text:        text,
      replyToId:   replyTo?.id,
      replyToText: replyTo != null ? (replyTo.text.isNotEmpty ? replyTo.text : '📷 ${loc.get('chat_image')}') : null,
    ).then((_) => NotificationService().sendChatNotification(
      receiverUid: _receiverUid,
      senderName:  _senderDisplayName,
      messageText: text,
      chatId:      widget.chatId,
    )).catchError((e) => debugPrint('❌ _send ката: $e'));
  }

  Future<ImageSource?> _chooseImageSource() {
    final loc = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sheetColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;

    return showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: sheetColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.grey300, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 12),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined, color: AppColors.primary),
              title: Text(loc.get('prod_img_camera'), style: AppTextStyles.labelLarge),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_outlined, color: AppColors.primary),
              title: Text(loc.get('prod_img_gallery'), style: AppTextStyles.labelLarge),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _pickAndSendImage() async {
    final loc  = AppLocalizations.of(context);
    final myId = _myId;
    if (myId == null) return;
    final source = await _chooseImageSource();
    if (source == null) return;
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: source);
    if (picked == null) return;
    setState(() => _isSendingImage = true);
    try {
      final bytes      = await picked.readAsBytes();
      final compressed = await compressImage(bytes);
      final url        = await _uploadToCloudinary(compressed);
      if (url == null) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(loc.get('chat_img_fail'))));
        return;
      }
      final replyTo = _replyingTo;
      if (replyTo != null) setState(() => _replyingTo = null);
      await _service.sendMessage(
        chatId:      widget.chatId,
        senderId:    myId,
        imageUrl:    url,
        replyToId:   replyTo?.id,
        replyToText: replyTo != null ? (replyTo.text.isNotEmpty ? replyTo.text : '📷 ${loc.get('chat_image')}') : null,
      );
      NotificationService().sendChatNotification(receiverUid: _receiverUid, senderName: _senderDisplayName, messageText: '📷 ${loc.get('chat_image')}', chatId: widget.chatId);
      _scrollToBottom();
    } finally {
      if (mounted) setState(() => _isSendingImage = false);
    }
  }

  Future<String?> _uploadToCloudinary(Uint8List bytes) async {
    try {
      final uri     = Uri.parse('https://api.cloudinary.com/v1_1/$_cloudName/image/upload');
      final request = http.MultipartRequest('POST', uri)
        ..fields['upload_preset'] = _uploadPreset
        ..files.add(http.MultipartFile.fromBytes('file', bytes, filename: 'chat_${DateTime.now().millisecondsSinceEpoch}.jpg'));
      final streamedResponse = await request.send().timeout(const Duration(seconds: 60));
      final response = await http.Response.fromStream(streamedResponse);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return data['secure_url'] as String?;
      }
      return null;
    } catch (_) { return null; }
  }

  Future<String?> _uploadAudioToCloudinary(String filePath) async {
    try {
      final uri     = Uri.parse('https://api.cloudinary.com/v1_1/$_cloudName/video/upload');
      final request = http.MultipartRequest('POST', uri)
        ..fields['upload_preset'] = _uploadPreset
        ..files.add(await http.MultipartFile.fromPath('file', filePath));
      final streamedResponse = await request.send().timeout(const Duration(seconds: 60));
      final response = await http.Response.fromStream(streamedResponse);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return data['secure_url'] as String?;
      }
      return null;
    } catch (_) { return null; }
  }

  Future<void> _sendVoiceMessage(String path, int durationSeconds) async {
    final loc  = AppLocalizations.of(context);
    final myId = _myId;
    if (myId == null) return;
    setState(() => _isSendingImage = true);
    try {
      final url = await _uploadAudioToCloudinary(path);
      if (url == null) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(loc.get('chat_audio_fail'))));
        return;
      }
      final replyTo = _replyingTo;
      if (replyTo != null) setState(() => _replyingTo = null);
      await _service.sendMessage(
        chatId:        widget.chatId,
        senderId:      myId,
        audioUrl:      url,
        audioDuration: durationSeconds,
        replyToId:     replyTo?.id,
        replyToText:   replyTo != null ? (replyTo.text.isNotEmpty ? replyTo.text : '📷 ${loc.get('chat_image')}') : null,
      );
      NotificationService().sendChatNotification(receiverUid: _receiverUid, senderName: _senderDisplayName, messageText: '🎤 ${loc.get('chat_voice')}', chatId: widget.chatId);
      _scrollToBottom();
    } finally {
      if (mounted) setState(() => _isSendingImage = false);
    }
  }

  void _enterSelectionMode(String msgId) => setState(() { _isSelectionMode = true; _selectedIds.add(msgId); });
  void _exitSelectionMode()              => setState(() { _isSelectionMode = false; _selectedIds.clear(); });

  void _toggleSelection(String msgId) {
    if (!_isSelectionMode) return;
    setState(() {
      if (_selectedIds.contains(msgId)) {
        _selectedIds.remove(msgId);
        if (_selectedIds.isEmpty) _isSelectionMode = false;
      } else {
        _selectedIds.add(msgId);
      }
    });
  }

  void _selectAll(List<MessageModel> messages) =>
      setState(() => _selectedIds..clear()..addAll(messages.map((m) => m.id)));

  Future<void> _deleteSelected() async {
    final loc     = AppLocalizations.of(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title:   Text(loc.get('chat_delete_msgs_title')),
        content: Text('${_selectedIds.length} ${loc.get('chat_delete_msgs_body')}'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(loc.get('no'))),
          TextButton(onPressed: () => Navigator.pop(context, true),  child: Text(loc.get('chat_delete_yes'), style: const TextStyle(color: AppColors.error))),
        ],
      ),
    );
    if (confirm == true) { await _service.deleteMessages(_selectedIds.toList()); _exitSelectionMode(); }
  }

  Future<void> _copyMessage(MessageModel msg) async {}

  Future<void> _deleteSingle(MessageModel msg) async {
    final loc     = AppLocalizations.of(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title:   Text(loc.get('chat_delete_msg_title')),
        content: Text(loc.get('chat_delete_msg_body')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(loc.get('no'))),
          TextButton(onPressed: () => Navigator.pop(context, true),  child: Text(loc.get('chat_delete_yes'), style: const TextStyle(color: AppColors.error))),
        ],
      ),
    );
    if (confirm == true) await _service.deleteMessages([msg.id]);
  }

  void _startReply(MessageModel msg) => setState(() => _replyingTo = msg);
  void _cancelReply()                => setState(() => _replyingTo = null);

  void _scrollToMessage(String? replyToId, List<MessageModel> messages) {
    if (replyToId == null) return;
    final reversedIndex = messages.indexWhere((m) => m.id == replyToId);
    if (reversedIndex == -1) return;
    final offset = (messages.length - 1 - reversedIndex) * 80.0;
    if (_scrollCtrl.hasClients) _scrollCtrl.animateTo(
      offset.clamp(0.0, _scrollCtrl.position.maxScrollExtent),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc   = AppLocalizations.of(context);
    final myId  = _myId;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bgColor   = isDark ? const Color(0xFF121212) : const Color(0xFFF4F5F7);
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final inputBg   = isDark ? const Color(0xFF2C2C2C) : const Color(0xFFF7F7F7);
    final dividerColor = isDark ? const Color(0xFF2C2C2C) : const Color(0xFFEEEEEE);

    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: bgColor,
      appBar: _isSelectionMode
          ? AppBar(
              backgroundColor: cardColor,
              elevation: 0,
              leading: IconButton(
                icon: Icon(Icons.close, color: theme.colorScheme.onSurface),
                onPressed: _exitSelectionMode,
              ),
              title: Text('${_selectedIds.length} ${loc.get('selected')}', style: AppTextStyles.headingSmall),
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
              leading: IconButton(
                icon: Icon(Icons.arrow_back, color: theme.colorScheme.onSurface),
                onPressed: () => Navigator.pop(context),
              ),
              title: Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundImage: widget.otherAvatarUrl.isNotEmpty ? NetworkImage(widget.otherAvatarUrl) : null,
                    backgroundColor: AppColors.grey200,
                    child: widget.otherAvatarUrl.isEmpty ? const Icon(Icons.person, size: 18, color: AppColors.grey400) : null,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _receiverDisplayName.isNotEmpty
                              ? _receiverDisplayName
                              : (widget.isSeller ? loc.get('chat_buyer') : widget.sellerName),
                          style: AppTextStyles.labelLarge,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (widget.productName.isNotEmpty)
                          Text(widget.productName,
                              style: AppTextStyles.labelSmall.copyWith(color: AppColors.grey500),
                              overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                ],
              ),
            ),
      body: myId == null
          ? Center(child: Text(loc.get('chat_login_required')))
          : Column(
              children: [
                ChatProductBanner(
                  productId:    widget.productId,
                  productName:  widget.productName,
                  productImage: widget.productImage,
                ),
                Expanded(
                  child: !_initialLoadDone
                      ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                      : _cachedMessages.isEmpty
                          ? Center(child: Text(loc.get('chat_empty'), style: AppTextStyles.bodyMedium.copyWith(color: AppColors.grey400)))
                          : Column(
                              children: [
                                if (_isSelectionMode)
                                  Container(
                                    color: cardColor,
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                    child: Align(
                                      alignment: Alignment.centerRight,
                                      child: TextButton(
                                        onPressed: () => _selectAll(_cachedMessages),
                                        child: Text(loc.get('select_all')),
                                      ),
                                    ),
                                  ),
                                Expanded(
                                  child: ListView.builder(
                                    controller: _scrollCtrl,
                                    reverse: true,
                                    padding: const EdgeInsets.all(12),
                                    itemCount: _cachedMessages.length,
                                    itemBuilder: (context, i) {
                                      final msg  = _cachedMessages[_cachedMessages.length - 1 - i];
                                      final isMe = msg.senderId == myId;
                                      return MessageBubble(
                                        message:         msg,
                                        isMe:            isMe,
                                        isSelectionMode: _isSelectionMode,
                                        isSelected:      _selectedIds.contains(msg.id),
                                        onLongPress:     () => _enterSelectionMode(msg.id),
                                        onTap:           () => _toggleSelection(msg.id),
                                        onCopy:          () => _copyMessage(msg),
                                        onDelete:        () => _deleteSingle(msg),
                                        onReply:         () => _startReply(msg),
                                        onReplyTap:      () => _scrollToMessage(msg.replyToId, _cachedMessages),
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ),
                ),

                // ── Жооп берүү preview ──
                if (!_isSelectionMode && _replyingTo != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: cardColor,
                      border: Border(top: BorderSide(color: dividerColor)),
                    ),
                    child: Row(
                      children: [
                        Container(width: 3, height: 36, color: AppColors.primary),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(loc.get('chat_reply'), style: AppTextStyles.labelSmall.copyWith(color: AppColors.primary)),
                              Text(
                                _replyingTo!.text.isNotEmpty ? _replyingTo!.text : '📷 ${loc.get('chat_image')}',
                                maxLines: 1, overflow: TextOverflow.ellipsis,
                                style: AppTextStyles.bodyMedium.copyWith(color: AppColors.grey600),
                              ),
                            ],
                          ),
                        ),
                        GestureDetector(onTap: _cancelReply, child: const Icon(Icons.close, color: AppColors.grey400, size: 20)),
                      ],
                    ),
                  ),

                // ── Жазуу талаасы ──
                if (!_isSelectionMode)
                  Container(
                    padding: EdgeInsets.fromLTRB(12, 8, 12, MediaQuery.of(context).padding.bottom + 8),
                    decoration: BoxDecoration(
                      color: cardColor,
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, -2))],
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        _isSendingImage
                            ? const SizedBox(width: 44, height: 44, child: Padding(padding: EdgeInsets.all(10), child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary)))
                            : GestureDetector(
                                onTap: _pickAndSendImage,
                                child: Container(
                                  width: 44, height: 44,
                                  decoration: BoxDecoration(color: inputBg, borderRadius: BorderRadius.circular(22)),
                                  child: const Icon(Icons.image_outlined, color: AppColors.grey500, size: 22),
                                ),
                              ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _msgCtrl,
                            minLines: 1, maxLines: 4,
                            textInputAction: TextInputAction.send,
                            onSubmitted: (_) => _send(),
                            decoration: InputDecoration(
                              hintText: loc.get('chat_hint'),
                              filled: true,
                              fillColor: inputBg,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _hasText
                            ? GestureDetector(
                                onTap: _send,
                                child: Container(
                                  width: 44, height: 44,
                                  decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(22)),
                                  child: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                                ),
                              )
                            : VoiceRecordButton(onRecorded: _sendVoiceMessage, onCancel: () {}),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }
}