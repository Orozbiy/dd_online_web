import 'package:flutter/material.dart';
import '../../../config/theme/app_colors.dart';
import '../../../config/theme/app_text_styles.dart';
import '../models/message_model.dart';

class AssistantChatScreen extends StatefulWidget {
  const AssistantChatScreen({super.key});

  @override
  State<AssistantChatScreen> createState() => _AssistantChatScreenState();
}

class _AssistantChatScreenState extends State<AssistantChatScreen> {
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isTyping = false;
  bool _isBotTyping = false;

  final List<MessageModel> _messages = [
    MessageModel(
      id: 'welcome',
      senderId: 'bot',
      text:
          'Салам! 👋 Мен DD Online жардамчысымын!\n\nМага мындай суроолор берсеңиз болот:\n• 🔍 Товар издөө\n• 🗺️ Дордойдо кайсы контейнер?\n• 💰 Баасы боюнча маалымат\n• 🕐 Иштөө убактысы\n• 📞 Байланыш маалымат',
      timestamp: DateTime.now(),
      isRead: true,
    ),
  ];

  // Суроолор жана жооптор
  final Map<String, String> _botReplies = {
    'салам': 'Салам! Кандай жардам кереk? 😊',
    'hello': 'Hello! How can I help you? 😊',
    'иштөө убакты':
        '🕐 Дордой базары:\nДүйшөмбү — Жекшемби\n⏰ 07:00 — 18:00\n\nЖекшемби да иштейт!',
    'убакты': '🕐 Дордой базары:\nДүйшөмбү — Жекшемби\n⏰ 07:00 — 18:00',
    'дарек':
        '📍 Дордой базары:\nБишкек ш., Дордой кв.\nМикробус: 107, 154, 240\nМаршрутка: 101, 131',
    'кийим':
        '👕 Кийим-кече дүкөндөр:\n🏪 A бөлүм — 1-3 катар\n🏪 B бөлүм — 5-8 катар\n\nЖалпы 500+ дүкөн бар!',
    'бут кийим':
        '👟 Бут кийим:\n🏪 C бөлүм — 2-4 катар\n\nРазмер 36-47 чейин бар.',
    'электроника':
        '📱 Электроника:\n🏪 D бөлүм — 1-2 катар\n\nТелефон, ноутбук, аксессуарлар.',
    'байланыш':
        '📞 Байланыш:\n☎️ +996 312 000 000\n📧 info@dd-online.kg\n💬 Instagram: @dd_online_kg',
    'рахмат': 'Кош болуңуз! 😊 Дагы суроолорунуз болсо жазыңыз!',
    'жардам':
        'Мен сизге жардам берем! Эмне кереk?\n\n• Товар издөө\n• Дүкөн маалымат\n• Дордойдо кантип баруу\n• Байланыш маалымат',
  };

  String _getBotReply(String input) {
    final lower = input.toLowerCase();
    for (final key in _botReplies.keys) {
      if (lower.contains(key)) {
        return _botReplies[key]!;
      }
    }
    return 'Түшүнбөдүм 😅\n\nМындай суроолор берсеңиз болот:\n• Иштөө убакты\n• Дарек\n• Кийим, бут кийим\n• Байланыш\n• Жардам';
  }

  void _sendMessage() {
    final text = _inputController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _messages.add(MessageModel(
        id: DateTime.now().toIso8601String(),
        senderId: 'current_user',
        text: text,
        timestamp: DateTime.now(),
        isRead: true,
      ));
      _inputController.clear();
      _isTyping = false;
      _isBotTyping = true;
    });

    _scrollToBottom();

    Future.delayed(const Duration(milliseconds: 1200), () {
      if (!mounted) return;
      setState(() {
        _isBotTyping = false;
        _messages.add(MessageModel(
          id: '${DateTime.now().toIso8601String()}_bot',
          senderId: 'bot',
          text: _getBotReply(text),
          timestamp: DateTime.now(),
          isRead: true,
        ));
      });
      _scrollToBottom();
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // Тез суроолор
  final List<String> _quickReplies = [
    '🕐 Иштөө убакты',
    '📍 Дардек',
    '👕 Кийим кайда?',
    '👟 Бут кийим',
    '📱 Электроника',
    '📞 Байланыш',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: const Icon(Icons.arrow_back, color: AppColors.black),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFFD97706), Color(0xFFEF4444)],
                ),
                shape: BoxShape.circle,
              ),
              child: const Text('🤖', style: TextStyle(fontSize: 18)),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('DD Жардамчы', style: AppTextStyles.headingSmall),
                Text('🟢 Дайыма онлайн',
                    style: AppTextStyles.labelSmall
                        .copyWith(color: AppColors.success)),
              ],
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Билдирүүлөр
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(12),
              itemCount: _messages.length + (_isBotTyping ? 1 : 0),
              itemBuilder: (context, i) {
                if (_isBotTyping && i == _messages.length) {
                  return _TypingIndicator();
                }
                final msg = _messages[i];
                final isMe = msg.senderId == 'current_user';
                return _AssistantBubble(message: msg, isMe: isMe);
              },
            ),
          ),

          // Тез суроолор
          SizedBox(
            height: 44,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: _quickReplies.length,
              itemBuilder: (context, i) {
                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    _inputController.text = _quickReplies[i]
                        .replaceAll(RegExp(r'[^\w\s]', unicode: true), '')
                        .trim();
                    _sendMessage();
                  },
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.4)),
                    ),
                    child: Text(_quickReplies[i],
                        style: AppTextStyles.labelMedium
                            .copyWith(color: AppColors.primary)),
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 8),

          // Жазуу аймагы
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.grey50,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: AppColors.grey200),
                    ),
                    child: TextField(
                      controller: _inputController,
                      onChanged: (v) =>
                          setState(() => _isTyping = v.isNotEmpty),
                      onSubmitted: (_) => _sendMessage(),
                      style: AppTextStyles.bodyMedium,
                      decoration: const InputDecoration(
                        hintText: 'Суроо жазыңыз...',
                        border: InputBorder.none,
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _sendMessage,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _isTyping ? AppColors.primary : AppColors.grey200,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.send_rounded,
                        color: _isTyping ? Colors.white : AppColors.grey400,
                        size: 20),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AssistantBubble extends StatelessWidget {
  final MessageModel message;
  final bool isMe;

  const _AssistantBubble({required this.message, required this.isMe});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          EdgeInsets.only(left: isMe ? 60 : 8, right: isMe ? 8 : 60, bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment:
            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isMe) ...[
            Container(
              padding: const EdgeInsets.all(6),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                    colors: [Color(0xFFD97706), Color(0xFFEF4444)]),
                shape: BoxShape.circle,
              ),
              child: const Text('🤖', style: TextStyle(fontSize: 14)),
            ),
            const SizedBox(width: 6),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isMe ? AppColors.primary : Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isMe ? 16 : 4),
                  bottomRight: Radius.circular(isMe ? 4 : 16),
                ),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 6,
                      offset: const Offset(0, 2))
                ],
              ),
              child: Text(
                message.text,
                style: AppTextStyles.bodyMedium
                    .copyWith(color: isMe ? Colors.white : AppColors.black),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TypingIndicator extends StatefulWidget {
  @override
  State<_TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<_TypingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600))
      ..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.3, end: 1.0).animate(_ctrl);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                  colors: [Color(0xFFD97706), Color(0xFFEF4444)]),
              shape: BoxShape.circle,
            ),
            child: const Text('🤖', style: TextStyle(fontSize: 14)),
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06), blurRadius: 6)
              ],
            ),
            child: FadeTransition(
              opacity: _anim,
              child: Row(
                children: List.generate(
                    3,
                    (i) => Container(
                          margin: const EdgeInsets.symmetric(horizontal: 2),
                          width: 7,
                          height: 7,
                          decoration: const BoxDecoration(
                              color: AppColors.grey400, shape: BoxShape.circle),
                        )),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
