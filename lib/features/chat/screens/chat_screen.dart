import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
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
import '../widgets/voice_record_button.dart';
import '../widgets/chat_product_banner.dart';
import '../widgets/call_request_bubble.dart';
import '../../../core/services/yandex_storage_service.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../core/chat_background_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';

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
      chatId: chat.id,
      sellerName: chat.sellerName,
      productId: chat.productId,
      productName: chat.productName ?? '',
      productImage: chat.productImage ?? '',
      isSeller: isSeller,
      buyerId: chat.buyerId,
      sellerId: chat.sellerId,
      otherAvatarUrl: isSeller ? chat.buyerAvatar : chat.sellerAvatar,
    );
  }

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  static const _cloudName = 'dedwm4krp';
  static const _uploadPreset = 'dd-online';

  final _service    = ChatService();
  final _msgCtrl    = TextEditingController();
  final _scrollCtrl = ScrollController();
  final _sfxPlayer  = AudioPlayer();

  // ── AnimatedList key ──
  final GlobalKey<AnimatedListState> _listKey = GlobalKey<AnimatedListState>();

  bool _isSendingImage = false;
  bool _hasText = false;
  bool _isSending = false;

  List<MessageModel> _cachedMessages = [];
  bool _initialLoadDone = false;
  late final Stream<List<MessageModel>> _messagesStream;
  StreamSubscription<List<MessageModel>>? _msgSub;

  bool _isSelectionMode = false;
  final Set<String> _selectedIds = {};

  MessageModel? _replyingTo;

  String? get _myId => supabase.auth.currentUser?.id;
  String _myDisplayName = '';
  String _receiverDisplayName = '';
  String _sellerPhone = '';
  String get _cacheKey => 'messages_${widget.chatId}';

  // ── Бул колдонуучу ГАНА жашырган билдирүүлөр (локалдык, экинчи
  //    тарапка тийбейт — сервердеги маалымат бузулбайт) ──
  String get _hiddenKey => 'hidden_msgs_${widget.chatId}';
  final Set<String> _hiddenMessageIds = {};

  // ════════════════════════════════════════════════════
  // КЭШ
  // ════════════════════════════════════════════════════

  Future<void> _loadHiddenIds() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getStringList(_hiddenKey);
      if (raw != null) _hiddenMessageIds.addAll(raw);
    } catch (_) {}
  }

  Future<void> _saveHiddenIds() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_hiddenKey, _hiddenMessageIds.toList());
    } catch (_) {}
  }

  /// Билдирүүлөрдү ЖАЛГЫЗ ушул колдонуучу үчүн жашырат.
  /// Сервердеги саптар тийилбейт — экинчи тарап өз чатында аларды
  /// көрүп турат (факт эки тарапта тең сакталат).
  Future<void> _hideMessagesLocally(List<String> ids) async {
    _hiddenMessageIds.addAll(ids);
    await _saveHiddenIds();
    await _saveMessagesCache(_cachedMessages);
  }

  Future<void> _loadMessagesCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_cacheKey);
      if (raw == null || !mounted) return;
      final list = (jsonDecode(raw) as List)
          .map((e) => MessageModel.fromJson(e as Map<String, dynamic>))
          .where((m) => !_hiddenMessageIds.contains(m.id))
          .toList();
      if (mounted && !_initialLoadDone) {
        setState(() => _cachedMessages = list);
      }
    } catch (_) {}
  }

  Future<void> _saveMessagesCache(List<MessageModel> msgs) async {
    try {
      final visible =
          msgs.where((m) => !_hiddenMessageIds.contains(m.id)).toList();
      final toSave = visible.length > 100
          ? visible.sublist(visible.length - 100)
          : visible;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _cacheKey,
        jsonEncode(toSave.map((m) => m.toJson()).toList()),
      );
    } catch (_) {}
  }

  // ════════════════════════════════════════════════════
  // INIT / DISPOSE
  // ════════════════════════════════════════════════════

  @override
  void initState() {
    super.initState();
    _initChat();
    _markRead();
    _loadMyName();
    _msgCtrl.addListener(() {
      final has = _msgCtrl.text.trim().isNotEmpty;
      if (has != _hasText) setState(() => _hasText = has);
    });
    _requestMicPermission();
    ChatBackgroundProvider.instance.addListener(_onBgChanged);
  }

  Future<void> _initChat() async {
    // Жашырылган (локалдык "өчүрүлгөн") id'лерди биринчи жүктөп алабыз,
    // андан кийин гана кэш/стримди ачабыз — болбосо мурда жашырылган
    // билдирүүлөр бир паска кайра көрүнүп кетет.
    await _loadHiddenIds();
    await _loadMessagesCache();

    _messagesStream = _service.messagesStream(widget.chatId);

    _msgSub = _messagesStream.listen((rawMsgs) {
  if (!mounted) return;

  // Бул колдонуучу жашырган билдирүүлөр сервердеги жоопто да
  // кайта-кайта келет (башка колдонуучу тарабынан өчүрүлбөгөндүктөн) —
  // аларды бул жерде дайыма сузуп салабыз.
  final msgs =
      rawMsgs.where((m) => !_hiddenMessageIds.contains(m.id)).toList();

  final oldIds = _cachedMessages.map((m) => m.id).toSet();
  final newIds = msgs.map((m) => m.id).toSet();

  // ── Жаңы кошулгандар ──
  for (final msg in msgs) {
    if (!oldIds.contains(msg.id)) {
      _cachedMessages.insert(0, msg);
      _listKey.currentState?.insertItem(
        0,
        duration: const Duration(milliseconds: 300),
      );
    }
  }

  // ── ЖАҢЫРТЫЛГАНДАР — is_read, is_edited ж.б. өзгөрсө ──
  for (final msg in msgs) {
    final idx = _cachedMessages.indexWhere((m) => m.id == msg.id);
    if (idx != -1) {
      final old = _cachedMessages[idx];
      if (old.isRead != msg.isRead ||
          old.isEdited != msg.isEdited ||
          old.text != msg.text ||
          old.callStatus != msg.callStatus) {
        _cachedMessages[idx] = msg; // ← жаңы маалымат менен алмаштыр
      }
    }
  }

  // ── Өчүрүлгөндөр ──
  final removedIds = oldIds.difference(newIds);
  for (final id in removedIds) {
    final idx = _cachedMessages.indexWhere((m) => m.id == id);
    if (idx != -1) {
      final removed = _cachedMessages.removeAt(idx);
      _listKey.currentState?.removeItem(
        idx,
        (ctx, anim) =>
            _buildAnimatedBubble(removed, anim, myId: _myId ?? ''),
        duration: const Duration(milliseconds: 250),
      );
    }
  }

  setState(() => _initialLoadDone = true);
  _saveMessagesCache(_cachedMessages);
  final myId = _myId;
  if (myId != null &&
      _cachedMessages.any((m) => m.senderId != myId && !m.isRead))
    _markRead();
});
  }

  void _onBgChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _requestMicPermission() async {
    if (kIsWeb) return; // веб: браузер өзү микрофон уруксатын сурайт
    final status = await Permission.microphone.status;
    if (!status.isGranted) await Permission.microphone.request();
  }

  @override
  void dispose() {
    ChatBackgroundProvider.instance.removeListener(_onBgChanged);
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    _msgSub?.cancel();
    _sfxPlayer.dispose();
    super.dispose();
  }

  // ── Смс кеткен үн (тык) ──
  bool _sfxContextSet = false;

  Future<void> _playSentSound() async {
    try {
      if (!_sfxContextSet) {
        // Аудио фокусту талап кылбайт — башка ойноп жаткан үндү үзбөйт
        await _sfxPlayer.setAudioContext(AudioContext(
          android: AudioContextAndroid(
            isSpeakerphoneOn: false,
            stayAwake: false,
            contentType: AndroidContentType.sonification,
            usageType: AndroidUsageType.assistanceSonification,
            audioFocus: AndroidAudioFocus.none,
          ),
          iOS: AudioContextIOS(category: AVAudioSessionCategory.ambient),
        ));
        _sfxContextSet = true;
      }
      await _sfxPlayer.stop();
      await _sfxPlayer.play(AssetSource('sounds/message_sent.wav'));
    } catch (_) {}
  }

  // ════════════════════════════════════════════════════
  // АТ ЖҮКТӨӨ
  // ════════════════════════════════════════════════════

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
        if (storeRow != null && mounted)
          setState(
              () => _myDisplayName = storeRow['store_name'] as String? ?? '');

        final buyerRow = await supabase
            .from('profiles')
            .select('full_name')
            .eq('id', widget.buyerId)
            .maybeSingle();
        if (buyerRow != null && mounted)
          setState(() =>
              _receiverDisplayName = buyerRow['full_name'] as String? ?? '');
      } else {
        final profileRow = await supabase
            .from('profiles')
            .select('full_name')
            .eq('id', myId)
            .maybeSingle();
        if (profileRow != null && mounted)
          setState(
              () => _myDisplayName = profileRow['full_name'] as String? ?? '');

        if (mounted) setState(() => _receiverDisplayName = widget.sellerName);

        final phoneRow = await supabase
            .from('profiles')
            .select('phone')
            .eq('id', widget.sellerId)
            .maybeSingle();
        if (phoneRow != null && mounted)
          setState(() => _sellerPhone = phoneRow['phone'] as String? ?? '');
      }
    } catch (e) {
      debugPrint('⚠️ _loadMyName ката: $e');
    }
  }

  // ════════════════════════════════════════════════════
  // ОКУЛДУ / SCROLL
  // ════════════════════════════════════════════════════
Future<void> _markRead() async {
  final myId = _myId;
  if (myId == null) return;

  // Башкасынын билдирүүлөрүн delivered + read кыл
  await Future.wait([
    // Чаттан unread санын нөлгө түшүр
    supabase.from('chats').update({
      if (!widget.isSeller) 'buyer_unread':  0,
      if (widget.isSeller)  'seller_unread': 0,
    }).eq('id', widget.chatId),

    // is_delivered = true (алуучу онлайн, алды)
    supabase
        .from('messages')
        .update({'is_delivered': true})
        .eq('chat_id', widget.chatId)
        .eq('is_delivered', false)
        .neq('sender_id', myId),

    // is_read = true (чатта окуду)
    supabase
        .from('messages')
        .update({'is_read': true})
        .eq('chat_id', widget.chatId)
        .eq('is_read', false)
        .neq('sender_id', myId),
  ]);

  // Локалдык кэшти дароо жаңырт
  if (mounted) {
    setState(() {
      _cachedMessages = _cachedMessages.map((m) {
        if (m.senderId != myId) {
          return m.copyWith(isRead: true, isDelivered: true);
        }
        return m;
      }).toList();
    });
    await _saveMessagesCache(_cachedMessages);
  }
}
  void _scrollToBottom() {
    if (_scrollCtrl.hasClients) {
      Future.delayed(const Duration(milliseconds: 100), () {
        if (_scrollCtrl.hasClients)
          _scrollCtrl.animateTo(0,
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOut);
      });
    }
  }

  // ════════════════════════════════════════════════════
  // ЧАЛУУ ӨТҮНҮЧҮ
  // ════════════════════════════════════════════════════

  Future<void> _sendCallRequest() async {
    final loc = AppLocalizations.of(context);
    final myId = _myId;
    if (myId == null) return;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final confirm = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.35),
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.black.withValues(alpha: 0.55)
                    : Colors.white.withValues(alpha: 0.65),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.15)
                      : Colors.black.withValues(alpha: 0.08),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    const Text('📞', style: TextStyle(fontSize: 24)),
                    const SizedBox(width: 8),
                    Text(loc.get('call_request_dialog_title'), style: AppTextStyles.headingSmall),
                  ]),
                  const SizedBox(height: 12),
                  Text(loc.get('call_request_dialog_body')),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(_, false),
                        child: Text(loc.get('no'),
                            style: const TextStyle(color: AppColors.grey500)),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(_, true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                        child: Text(loc.get('call_request_dialog_send'),
                            style: const TextStyle(color: Colors.white)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    if (confirm != true) return;

    await supabase.from('messages').insert({
      'chat_id': widget.chatId,
      'sender_id': myId,
      'text': loc.get('call_request_title'),
      'message_type': 'call_request',
      'call_status': 'pending',
      'is_read': false,
    });

    NotificationService().sendChatNotification(
      receiverUid: _receiverUid,
      senderName: _senderDisplayName,
      messageText: loc.get('call_request_notify_text'),
      chatId: widget.chatId,
    );

    _scrollToBottom();
  }

  String get _receiverUid =>
      widget.isSeller ? widget.buyerId : widget.sellerId;

  String get _senderDisplayName => widget.isSeller
      ? (_myDisplayName.isNotEmpty ? _myDisplayName : 'Сатуучу')
      : (_myDisplayName.isNotEmpty ? _myDisplayName : 'Кардар');

  // ════════════════════════════════════════════════════
  // ЖӨНӨТҮҮ
  // ════════════════════════════════════════════════════

  void _send() {
    if (_isSending) return;
    _isSending = true;

    final loc = AppLocalizations.of(context);
    final text = _msgCtrl.text.trim();
    final myId = _myId;

    if (text.isEmpty || myId == null) {
      _isSending = false;
      return;
    }

    _msgCtrl.clear();
    final replyTo = _replyingTo;
    if (replyTo != null) setState(() => _replyingTo = null);

    _service
        .sendMessage(
      chatId: widget.chatId,
      senderId: myId,
      text: text,
      replyToId: replyTo?.id,
      replyToText: replyTo != null
          ? (replyTo.text.isNotEmpty
              ? replyTo.text
              : '📷 ${loc.get('chat_image')}')
          : null,
      senderIsBuyer: !widget.isSeller,
    )
        .then((_) async {
      _isSending = false;
      _playSentSound(); // ← текст кеткенде тык

      String receiverLocale = 'ky';
      try {
        final receiverProfile = await supabase
            .from('profiles')
            .select('locale')
            .eq('id', _receiverUid)
            .maybeSingle();
        receiverLocale = receiverProfile?['locale'] as String? ?? 'ky';
      } catch (_) {}

      String senderName;
      if (widget.isSeller) {
        senderName = _myDisplayName.isNotEmpty
            ? _myDisplayName
            : (receiverLocale == 'ru' ? 'Продавец' : 'Сатуучу');
      } else {
        senderName = _myDisplayName.isNotEmpty
            ? _myDisplayName
            : (receiverLocale == 'ru' ? 'Покупатель' : 'Кардар');
      }

      NotificationService().sendChatNotification(
        receiverUid: _receiverUid,
        senderName: senderName,
        messageText: text,
        chatId: widget.chatId,
      );
    }).onError((e, stack) {
      debugPrint('❌ _send ката: $e');
      _isSending = false;
      return null;
    });
  }

  // ════════════════════════════════════════════════════
  // СҮРӨТ / ҮНДҮК
  // ════════════════════════════════════════════════════

  Future<ImageSource?> _chooseImageSource() {
    final loc = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.black.withValues(alpha: 0.55)
                  : Colors.white.withValues(alpha: 0.60),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(20)),
              border: Border(
                top: BorderSide(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.12)
                      : Colors.black.withValues(alpha: 0.08),
                ),
              ),
            ),
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 8),
                  Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.25)
                              : AppColors.grey300,
                          borderRadius: BorderRadius.circular(2))),
                  const SizedBox(height: 12),
                  ListTile(
                    leading: const Icon(Icons.camera_alt_outlined,
                        color: AppColors.primary),
                    title: Text(loc.get('prod_img_camera'),
                        style: AppTextStyles.labelLarge),
                    onTap: () => Navigator.pop(context, ImageSource.camera),
                  ),
                  ListTile(
                    leading: const Icon(Icons.photo_outlined,
                        color: AppColors.primary),
                    title: Text(loc.get('prod_img_gallery'),
                        style: AppTextStyles.labelLarge),
                    onTap: () => Navigator.pop(context, ImageSource.gallery),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

Future<void> _pickAndSendImage() async {
  final loc = AppLocalizations.of(context);
  final myId = _myId;
  if (myId == null) return;
  final source = await _chooseImageSource();
  if (source == null) return;
  final picker = ImagePicker();
  final picked = await picker.pickImage(source: source);
  if (picked == null) return;
  setState(() => _isSendingImage = true);
  try {
    final bytes = await picked.readAsBytes();
    // ✅ compressChatImage — чат үчүн оптималдашырылган (800x800, quality 70)
    final compressed = await compressChatImage(bytes);
    final url = await YandexStorageService.instance.uploadImage(
      compressed,
      folder: 'chat',
    );
    if (url == null) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(loc.get('chat_img_fail'))));
      }
      return;
    }
    final replyTo = _replyingTo;
    if (replyTo != null) setState(() => _replyingTo = null);
    await _service.sendMessage(
      chatId: widget.chatId,
      senderId: myId,
      imageUrl: url,
      replyToId: replyTo?.id,
      replyToText: replyTo != null
          ? (replyTo.text.isNotEmpty
              ? replyTo.text
              : '📷 ${loc.get('chat_image')}')
          : null,
      senderIsBuyer: !widget.isSeller,
    );
    NotificationService().sendChatNotification(
      receiverUid: _receiverUid,
      senderName: _senderDisplayName,
      messageText: '📷 ${loc.get('chat_image')}',
      chatId: widget.chatId,
    );
    _playSentSound(); // ← сүрөт кеткенде тык
    _scrollToBottom();
  } finally {
    if (mounted) setState(() => _isSendingImage = false);
  }
}
 


  Future<String?> _uploadAudioToCloudinary(String filePath) async {
    try {
      final uri =
          Uri.parse('https://api.cloudinary.com/v1_1/$_cloudName/video/upload');
      final request = http.MultipartRequest('POST', uri)
        ..fields['upload_preset'] = _uploadPreset
        ..files.add(await http.MultipartFile.fromPath('file', filePath));
      final streamedResponse =
          await request.send().timeout(const Duration(seconds: 60));
      final response = await http.Response.fromStream(streamedResponse);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return data['secure_url'] as String?;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

Future<void> _sendVoiceMessage(String path, int durationSeconds) async {
  final loc = AppLocalizations.of(context);
  final myId = _myId;
  if (myId == null) return;
  setState(() => _isSendingImage = true);
  try {
    // ВЕБ: record пакети blob URL кайтарат — байттарды HTTP аркылуу алабыз
    final Uint8List bytes = kIsWeb
        ? (await http.get(Uri.parse(path))).bodyBytes
        : await File(path).readAsBytes();

    String? url;
    try {
      url = await YandexStorageService.instance.uploadAudio(
        bytes,
        folder: 'chat_audio',
        filename: 'audio_${DateTime.now().millisecondsSinceEpoch}.${kIsWeb ? 'webm' : 'm4a'}',
        contentType: kIsWeb ? 'audio/webm' : 'audio/m4a',
      );
    } catch (e) {
      if (mounted) {
        final isNetworkError = e.toString().contains('SocketException') ||
            e.toString().contains('Failed host lookup') ||
            e.toString().contains('No address associated');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isNetworkError
                  ? 'Интернет туташуусу жок. Тармакты текшериңиз.'
                  : loc.get('chat_audio_fail'),
            ),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    if (url == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(loc.get('chat_audio_fail')),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    final replyTo = _replyingTo;
    if (replyTo != null) setState(() => _replyingTo = null);

    await _service.sendMessage(
      chatId: widget.chatId,
      senderId: myId,
      audioUrl: url,
      audioDuration: durationSeconds,
      replyToId: replyTo?.id,
      replyToText: replyTo != null
          ? (replyTo.text.isNotEmpty
              ? replyTo.text
              : '🎵 ${loc.get('chat_audio')}')
          : null,
      senderIsBuyer: !widget.isSeller,
    );

    NotificationService().sendChatNotification(
      receiverUid: _receiverUid,
      senderName: _senderDisplayName,
      messageText: '🎵 ${loc.get('chat_audio')}',
      chatId: widget.chatId,
    );

    _playSentSound();
    _scrollToBottom();
  } finally {
    if (mounted) setState(() => _isSendingImage = false);
  }
}
 
  // ════════════════════════════════════════════════════
  // ТАНДОО РЕЖИМИ
  // ════════════════════════════════════════════════════

  void _enterSelectionMode(String msgId) => setState(() {
        _isSelectionMode = true;
        _selectedIds.add(msgId);
      });

  void _exitSelectionMode() => setState(() {
        _isSelectionMode = false;
        _selectedIds.clear();
      });

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

  void _selectAll(List<MessageModel> messages) => setState(() => _selectedIds
    ..clear()
    ..addAll(messages.map((m) => m.id)));

  // ════════════════════════════════════════════════════
  // ӨЧҮРҮҮ — ТАНДАЛГАНДАР
  // ════════════════════════════════════════════════════

  Future<void> _deleteSelected() async {
    final loc = AppLocalizations.of(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(loc.get('chat_delete_msgs_title')),
        content: Text(
            '${_selectedIds.length} ${loc.get('chat_delete_msgs_body')}'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(loc.get('no')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(loc.get('chat_delete_yes'),
                style: const TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    final toDelete = Set<String>.from(_selectedIds);
    _exitSelectionMode();

    // Индекси чоңдон кичинеге карай өчүр — индекс бузулбасын
    final entries = _cachedMessages
        .asMap()
        .entries
        .where((e) => toDelete.contains(e.value.id))
        .toList()
        .reversed
        .toList();

    for (final entry in entries) {
      final idx = _cachedMessages.indexWhere((m) => m.id == entry.value.id);
      if (idx == -1) continue;
      final removed = _cachedMessages.removeAt(idx);
      _listKey.currentState?.removeItem(
        idx,
        (ctx, anim) => _buildAnimatedBubble(removed, anim, myId: _myId ?? ''),
        duration: const Duration(milliseconds: 250),
      );
    }

    // Локалдык жашыруу — серверге, демек экинчи тарапка тийбейт.
    await _hideMessagesLocally(toDelete.toList());
  }

  // ════════════════════════════════════════════════════
  // ӨЧҮРҮҮ — ЖЕКЕ
  // ════════════════════════════════════════════════════

  Future<void> _deleteSingle(MessageModel msg) async {
    final loc = AppLocalizations.of(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(loc.get('chat_delete_msg_title')),
        content: Text(loc.get('chat_delete_msg_body')),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(loc.get('no'))),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(loc.get('chat_delete_yes'),
                  style: const TextStyle(color: AppColors.error))),
        ],
      ),
    );
    if (confirm != true) return;

    final idx = _cachedMessages.indexWhere((m) => m.id == msg.id);
    if (idx != -1) {
      final removed = _cachedMessages.removeAt(idx);
      _listKey.currentState?.removeItem(
        idx,
        (ctx, anim) => _buildAnimatedBubble(removed, anim, myId: _myId ?? ''),
        duration: const Duration(milliseconds: 250),
      );
    }
    // Локалдык жашыруу — серверге, демек экинчи тарапка тийбейт.
    await _hideMessagesLocally([msg.id]);
  }

  // ════════════════════════════════════════════════════
  // АНИМАЦИЯ BUBBLE ЖАРДАМЧЫ
  // ════════════════════════════════════════════════════

  Widget _buildAnimatedBubble(
    MessageModel msg,
    Animation<double> anim, {
    required String myId,
  }) {
    final isMe = msg.senderId == myId;
    return SizeTransition(
      sizeFactor: CurvedAnimation(parent: anim, curve: Curves.easeOut),
      child: FadeTransition(
        opacity: anim,
        child: msg.isCallRequest
            ? CallRequestBubble(
                message: msg,
                isMe: isMe,
                isSeller: widget.isSeller,
                myPhone: _sellerPhone,
              )
            : MessageBubble(
                message: msg,
                isMe: isMe,
                isSelectionMode: false,
                isSelected: false,
                onLongPress: () {},
                onTap: () {},
                onCopy: () {},
                onDelete: () {},
                onReply: () {},
                onEdit: () {},
                onReplyTap: () {},
              ),
      ),
    );
  }

  // ════════════════════════════════════════════════════
  // БАШКА ФУНКЦИЯЛАР
  // ════════════════════════════════════════════════════

  Future<void> _copyMessage(MessageModel msg) async {}

  void _editMessage(MessageModel msg) {
    final loc = AppLocalizations.of(context);
    final diff = DateTime.now().difference(msg.timestamp);
    if (diff.inMinutes >= 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(loc.get('edit_msg_too_late')),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    final ctrl = TextEditingController(text: msg.text);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(loc.get('edit_msg_title'),
            style: AppTextStyles.headingSmall),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          maxLines: null,
          decoration: InputDecoration(
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.primary, width: 2),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child:
                Text(loc.get('edit_msg_no'), style: const TextStyle(color: AppColors.grey500)),
          ),
          ElevatedButton(
            onPressed: () async {
              final newText = ctrl.text.trim();
              if (newText.isEmpty || newText == msg.text) {
                Navigator.pop(context);
                return;
              }
              Navigator.pop(context);
              await _service.editMessage(messageId: msg.id, newText: newText);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: Text(loc.get('edit_msg_save'), style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _startReply(MessageModel msg) => setState(() => _replyingTo = msg);
  void _cancelReply() => setState(() => _replyingTo = null);

  void _scrollToMessage(String? replyToId, List<MessageModel> messages) {
    if (replyToId == null) return;
    final reversedIndex = messages.indexWhere((m) => m.id == replyToId);
    if (reversedIndex == -1) return;
   final offset = reversedIndex * 80.0;
    if (_scrollCtrl.hasClients)
      _scrollCtrl.animateTo(
        offset.clamp(0.0, _scrollCtrl.position.maxScrollExtent),
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
  }

  // ════════════════════════════════════════════════════
  // BUILD
  // ════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final myId = _myId;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;

    final glassAppBarBg = isDark
        ? Colors.black.withValues(alpha: 0.45)
        : Colors.white.withValues(alpha: 0.60);
    final glassBottomBg = isDark
        ? Colors.black.withValues(alpha: 0.40)
        : Colors.white.withValues(alpha: 0.55);
    final glassInputFill = isDark
        ? Colors.white.withValues(alpha: 0.10)
        : Colors.black.withValues(alpha: 0.06);
    final glassButtonBg = isDark
        ? Colors.white.withValues(alpha: 0.12)
        : Colors.black.withValues(alpha: 0.08);

    return Stack(
      children: [
        // ── ФОН ТЕМАСЫ ──
        Positioned.fill(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 400),
            child: KeyedSubtree(
              key: ValueKey(ChatBackgroundProvider.instance.theme),
              child:
                  ChatBackgroundProvider.instance.theme.buildBackground(isDark),
            ),
          ),
        ),

        // ── SCAFFOLD ──
        Scaffold(
          resizeToAvoidBottomInset: true,
          backgroundColor: Colors.transparent,
          extendBodyBehindAppBar: true,
          appBar: PreferredSize(
            preferredSize: const Size.fromHeight(kToolbarHeight),
            child: ClipRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: _isSelectionMode
                    ? AppBar(
                        backgroundColor: glassAppBarBg,
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
                          IconButton(
                            icon: const Icon(Icons.delete_outline,
                                color: AppColors.error),
                            onPressed:
                                _selectedIds.isEmpty ? null : _deleteSelected,
                          ),
                        ],
                      )
                    : AppBar(
                        backgroundColor: glassAppBarBg,
                        elevation: 0,
                        leading: IconButton(
                          icon: Icon(Icons.arrow_back,
                              color: theme.colorScheme.onSurface),
                          onPressed: () => Navigator.pop(context),
                        ),
                        title: Row(
                          children: [
                            CircleAvatar(
                              radius: 18,
                              backgroundImage: widget.otherAvatarUrl.isNotEmpty
                                  ? NetworkImage(widget.otherAvatarUrl)
                                  : null,
                              backgroundColor: AppColors.grey200,
                              child: widget.otherAvatarUrl.isEmpty
                                  ? const Icon(Icons.person,
                                      size: 18, color: AppColors.grey400)
                                  : null,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _receiverDisplayName.isNotEmpty
                                        ? _receiverDisplayName
                                        : (widget.isSeller
                                            ? loc.get('chat_buyer')
                                            : widget.sellerName),
                                    // Күндүзгү режимде кара, түнкүдө ак
                                    // (мурда теманын тартмасы менен кээде
                                    // ак болуп, ак фондо көрүнбөй калып
                                    // калчу)
                                    style: AppTextStyles.labelLarge.copyWith(
                                      color: isDark
                                          ? Colors.white
                                          : AppColors.black,
                                      fontWeight: FontWeight.w700,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  if (widget.productName.isNotEmpty)
                                    Text(widget.productName,
                                        style: AppTextStyles.labelSmall
                                            .copyWith(color: AppColors.grey500),
                                        overflow: TextOverflow.ellipsis),
                                ],
                              ),
                            ),
                          ],
                        ),
                        actions: [
                          if (!widget.isSeller)
                            IconButton(
                              icon: const Icon(Icons.phone_callback_rounded,
                                  color: AppColors.primary),
                              tooltip: 'Өтүнүч жиберүү',
                              onPressed: _sendCallRequest,
                            ),
                        ],
                      ),
              ),
            ),
          ),
          body: myId == null
              ? Center(child: Text(loc.get('chat_login_required')))
              : Column(
                  children: [
                    SizedBox(
                        height: kToolbarHeight +
                            MediaQuery.of(context).padding.top),
                    ChatProductBanner(
                      productId: widget.productId,
                      productName: widget.productName,
                      productImage: widget.productImage,
                    ),
                    Expanded(
                      child: !_initialLoadDone
                          ? const Center(
                              child: CircularProgressIndicator(
                                  color: AppColors.primary))
                          : _cachedMessages.isEmpty
                              ? Center(
                                  child: Text(loc.get('chat_empty'),
                                      style: AppTextStyles.bodyMedium.copyWith(
                                          color: AppColors.grey400)))
                              : Column(
                                  children: [
                                    if (_isSelectionMode)
                                      Container(
                                        color: cardColor,
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 12, vertical: 4),
                                        child: Align(
                                          alignment: Alignment.centerRight,
                                          child: TextButton(
                                            onPressed: () =>
                                                _selectAll(_cachedMessages),
                                            child: Text(loc.get('select_all')),
                                          ),
                                        ),
                                      ),

                                    // ── ANIMATED LIST ──
                                    Expanded(
                                      child: AnimatedList(
                                        key: _listKey,
                                        controller: _scrollCtrl,
                                        reverse: true,
                                        padding: const EdgeInsets.all(12),
                                        initialItemCount:
                                            _cachedMessages.length,
                                        itemBuilder: (context, i, animation) {
                                          final msg = _cachedMessages[i];
                                          final isMe = msg.senderId == myId;

                                          return SizeTransition(
                                            sizeFactor: CurvedAnimation(
                                                parent: animation,
                                                curve: Curves.easeOut),
                                            child: FadeTransition(
                                              opacity: animation,
                                              child: msg.isCallRequest
                                                  ? CallRequestBubble(
                                                      message: msg,
                                                      isMe: isMe,
                                                      isSeller: widget.isSeller,
                                                      myPhone: _sellerPhone,
                                                    )
                                                  : MessageBubble(
                                                      message: msg,
                                                      isMe: isMe,
                                                      isSelectionMode:
                                                          _isSelectionMode,
                                                      isSelected: _selectedIds
                                                          .contains(msg.id),
                                                      onLongPress: () =>
                                                          _enterSelectionMode(
                                                              msg.id),
                                                      onTap: () =>
                                                          _toggleSelection(
                                                              msg.id),
                                                      onCopy: () =>
                                                          _copyMessage(msg),
                                                      onDelete: () =>
                                                          _deleteSingle(msg),
                                                      onReply: () =>
                                                          _startReply(msg),
                                                      onEdit: () =>
                                                          _editMessage(msg),
                                                      onReplyTap: () =>
                                                          _scrollToMessage(
                                                              msg.replyToId,
                                                              _cachedMessages),
                                                    ),
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                    ),

                    // ── ЖООП PREVIEW ──
                    if (!_isSelectionMode && _replyingTo != null)
                      ClipRect(
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: glassBottomBg,
                              border: Border(
                                  top: BorderSide(
                                      color: isDark
                                          ? Colors.white.withValues(alpha: 0.12)
                                          : Colors.black
                                              .withValues(alpha: 0.08))),
                            ),
                            child: Row(
                              children: [
                                Container(
                                    width: 3,
                                    height: 36,
                                    color: AppColors.primary),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(loc.get('chat_reply'),
                                          style: AppTextStyles.labelSmall
                                              .copyWith(
                                                  color: AppColors.primary)),
                                      Text(
                                        _replyingTo!.text.isNotEmpty
                                            ? _replyingTo!.text
                                            : '📷 ${loc.get('chat_image')}',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: AppTextStyles.bodyMedium
                                            .copyWith(
                                                color: AppColors.grey600),
                                      ),
                                    ],
                                  ),
                                ),
                                GestureDetector(
                                    onTap: _cancelReply,
                                    child: const Icon(Icons.close,
                                        color: AppColors.grey400, size: 20)),
                              ],
                            ),
                          ),
                        ),
                      ),

                    // ── ЖАЗУУ ТАЛААСЫ ──
                    if (!_isSelectionMode)
                      ClipRect(
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                          child: Container(
                            padding: EdgeInsets.fromLTRB(
                                12,
                                8,
                                12,
                                MediaQuery.of(context).padding.bottom + 8),
                            decoration: BoxDecoration(
                              color: glassBottomBg,
                              border: Border(
                                top: BorderSide(
                                  color: isDark
                                      ? Colors.white.withValues(alpha: 0.10)
                                      : Colors.black.withValues(alpha: 0.07),
                                ),
                              ),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                _isSendingImage
                                    ? const SizedBox(
                                        width: 44,
                                        height: 44,
                                        child: Padding(
                                            padding: EdgeInsets.all(10),
                                            child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: AppColors.primary)))
                                    : GestureDetector(
                                        onTap: _pickAndSendImage,
                                        child: Container(
                                          width: 44,
                                          height: 44,
                                          decoration: BoxDecoration(
                                              color: glassButtonBg,
                                              borderRadius:
                                                  BorderRadius.circular(22),
                                              border: Border.all(
                                                color: isDark
                                                    ? Colors.white.withValues(
                                                        alpha: 0.15)
                                                    : Colors.black.withValues(
                                                        alpha: 0.10),
                                              )),
                                          child: const Icon(
                                              Icons.image_outlined,
                                              color: AppColors.grey500,
                                              size: 22),
                                        ),
                                      ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: TextField(
                                    controller: _msgCtrl,
                                    minLines: 1,
                                    maxLines: 4,
                                    textInputAction: TextInputAction.send,
                                    onSubmitted: (_) => _send(),
                                    // ← Жазылган текст күндүзгү/түнкү режимде ар дайым көрүнүктүү
                                    style: TextStyle(
                                      color: isDark ? Colors.white : AppColors.black,
                                      fontSize: 15,
                                    ),
                                    cursorColor: AppColors.primary,
                                    decoration: InputDecoration(
                                      hintText: loc.get('chat_hint'),
                                      hintStyle: TextStyle(
                                        color: isDark
                                            ? Colors.white.withValues(alpha: 0.45)
                                            : AppColors.grey400,
                                      ),
                                      filled: true,
                                      fillColor: glassInputFill,
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                              horizontal: 16, vertical: 10),
                                      border: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(20),
                                          borderSide: BorderSide(
                                            color: isDark
                                                ? Colors.white
                                                    .withValues(alpha: 0.15)
                                                : Colors.black
                                                    .withValues(alpha: 0.10),
                                          )),
                                      enabledBorder: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(20),
                                          borderSide: BorderSide(
                                            color: isDark
                                                ? Colors.white
                                                    .withValues(alpha: 0.15)
                                                : Colors.black
                                                    .withValues(alpha: 0.10),
                                          )),
                                      focusedBorder: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(20),
                                          borderSide: const BorderSide(
                                              color: AppColors.primary,
                                              width: 1.5)),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                _hasText
                                    ? GestureDetector(
                                        onTap: _send,
                                        child: Container(
                                          width: 44,
                                          height: 44,
                                          decoration: BoxDecoration(
                                              color: AppColors.primary,
                                              borderRadius:
                                                  BorderRadius.circular(22)),
                                          child: const Icon(Icons.send_rounded,
                                              color: Colors.white, size: 20),
                                        ),
                                      )
                                    : VoiceRecordButton(
                                        onRecorded: _sendVoiceMessage,
                                        onCancel: () {}),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}