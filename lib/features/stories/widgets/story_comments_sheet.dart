import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../../core/supabase_client.dart';
import '../models/story_comment_model.dart';
import '../services/story_service.dart';

/// Instagram сыяктуу: астынан чыккан комментарий барагы.
/// [onCountChanged] — комментарий кошулганда/өчүрүлгөндө жаңы санды кайтарат.
Future<void> showStoryComments(
  BuildContext context, {
  required String storyId,
  required ValueChanged<int> onCountChanged,
  bool autofocus = false,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _StoryCommentsSheet(
      storyId: storyId,
      onCountChanged: onCountChanged,
      autofocus: autofocus,
    ),
  );
}

class _StoryCommentsSheet extends StatefulWidget {
  final String storyId;
  final ValueChanged<int> onCountChanged;
  final bool autofocus;
  const _StoryCommentsSheet({
    required this.storyId,
    required this.onCountChanged,
    required this.autofocus,
  });

  @override
  State<_StoryCommentsSheet> createState() => _StoryCommentsSheetState();
}

class _StoryCommentsSheetState extends State<_StoryCommentsSheet> {
  final _ctrl = TextEditingController();
  List<StoryCommentModel> _comments = [];
  bool _loading = true;
  bool _sending = false;

  String? get _myId => supabase.auth.currentUser?.id;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final list = await StoryService.instance.fetchComments(widget.storyId);
    if (!mounted) return;
    setState(() {
      _comments = list;
      _loading = false;
    });
    widget.onCountChanged(list.length);
  }

  Future<void> _send() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty || _sending) return;
    if (_myId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Комментарий жазуу үчүн аккаунтка кириңиз')),
      );
      return;
    }
    setState(() => _sending = true);
    final c = await StoryService.instance.addComment(widget.storyId, text);
    if (!mounted) return;
    setState(() {
      _sending = false;
      if (c != null) {
        _comments.insert(0, c);
        _ctrl.clear();
      }
    });
    if (c != null) {
      widget.onCountChanged(_comments.length);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Жөнөтүүдө ката чыкты')),
      );
    }
  }

  Future<void> _delete(StoryCommentModel c) async {
    final ok = await StoryService.instance.deleteComment(c.id);
    if (!ok || !mounted) return;
    setState(() => _comments.removeWhere((e) => e.id == c.id));
    widget.onCountChanged(_comments.length);
  }

  String _ago(DateTime d) {
    final diff = DateTime.now().difference(d);
    if (diff.inMinutes < 1) return 'азыр';
    if (diff.inMinutes < 60) return '${diff.inMinutes} мүн';
    if (diff.inHours < 24) return '${diff.inHours} саат';
    return '${diff.inDays} күн';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final fg = isDark ? Colors.white : Colors.black87;
    final sub = isDark ? Colors.white54 : Colors.black45;
    final h = MediaQuery.of(context).size.height;

    return AnimatedPadding(
      duration: const Duration(milliseconds: 120),
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        height: h * 0.65,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text('Комментарийлер',
                  style: TextStyle(
                      color: fg, fontSize: 16, fontWeight: FontWeight.w700)),
            ),
            Divider(height: 1, color: sub.withValues(alpha: 0.2)),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _comments.isEmpty
                      ? Center(
                          child: Text('Азырынча комментарий жок.\nБиринчи болуп жазыңыз!',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: sub)),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          itemCount: _comments.length,
                          itemBuilder: (_, i) {
                            final c = _comments[i];
                            final mine = c.userId == _myId;
                            return Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 8),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  CircleAvatar(
                                    radius: 17,
                                    backgroundColor:
                                        Colors.grey.withValues(alpha: 0.3),
                                    backgroundImage: (c.avatarUrl != null &&
                                            c.avatarUrl!.isNotEmpty)
                                        ? CachedNetworkImageProvider(c.avatarUrl!)
                                        : null,
                                    child: (c.avatarUrl == null ||
                                            c.avatarUrl!.isEmpty)
                                        ? Text(
                                            c.userName.isNotEmpty
                                                ? c.userName[0].toUpperCase()
                                                : '?',
                                            style: TextStyle(color: fg))
                                        : null,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(children: [
                                          Flexible(
                                            child: Text(c.userName,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                    color: fg,
                                                    fontWeight: FontWeight.w700,
                                                    fontSize: 13)),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(_ago(c.createdAt),
                                              style: TextStyle(
                                                  color: sub, fontSize: 12)),
                                        ]),
                                        const SizedBox(height: 2),
                                        Text(c.text,
                                            style: TextStyle(
                                                color: fg, fontSize: 14)),
                                      ],
                                    ),
                                  ),
                                  if (mine)
                                    GestureDetector(
                                      onTap: () => _delete(c),
                                      child: Padding(
                                        padding: const EdgeInsets.only(left: 8),
                                        child: Icon(Icons.delete_outline,
                                            size: 18, color: sub),
                                      ),
                                    ),
                                ],
                              ),
                            );
                          },
                        ),
            ),
            Divider(height: 1, color: sub.withValues(alpha: 0.2)),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                child: Row(children: [
                  Expanded(
                    child: TextField(
                      controller: _ctrl,
                      autofocus: widget.autofocus,
                      maxLength: 500,
                      minLines: 1,
                      maxLines: 3,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                      style: TextStyle(color: fg),
                      decoration: InputDecoration(
                        hintText: 'Комментарий жазуу...',
                        hintStyle: TextStyle(color: sub),
                        counterText: '',
                        isDense: true,
                        filled: true,
                        fillColor: isDark
                            ? const Color(0xFF2C2C2C)
                            : const Color(0xFFF3F3F3),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _sending
                      ? const SizedBox(
                          width: 36,
                          height: 36,
                          child: Padding(
                            padding: EdgeInsets.all(8),
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : IconButton(
                          onPressed: _send,
                          icon: const Icon(Icons.send_rounded),
                          color: const Color(0xFFE8412A),
                        ),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
