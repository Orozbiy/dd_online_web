// lib/features/admin/widgets/admin_notification_sender.dart
//
// Мүмкүнчүлүктөр:
//  • Жаңы билдирүү жөнөтүү (аталыш + текст + сүрөт)
//  • Жөнөтүлгөн билдирүүлөрдүн тизмеси
//  • Өзгөртүү (Edit)
//  • Өчүрүү (Delete)
//  • 7 күндөн эски билдирүүлөр авто өчүрүлөт (экран ачылганда)

import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../config/theme/app_colors.dart';
import '../../../config/theme/app_text_styles.dart';
import '../../../core/services/yandex_storage_service.dart';
import '../../../core/supabase_client.dart';
import '../../../services/notification_service.dart';

class AdminNotificationSender extends StatefulWidget {
  final String searchQuery;
  const AdminNotificationSender({super.key, this.searchQuery = ''});

  @override
  State<AdminNotificationSender> createState() =>
      _AdminNotificationSenderState();
}

class _AdminNotificationSenderState extends State<AdminNotificationSender> {
  // ── Форма ──
  final _titleCtrl = TextEditingController();
  final _bodyCtrl  = TextEditingController();
  Uint8List? _pickedImage; // веб + мобил: байттар
  bool    _isUploadingImage = false;
  bool    _isSending        = false;

  // ── Тизме ──
  List<Map<String, dynamic>> _sent     = [];
  bool                       _loadingList = true;

  // ── Edit режими ──
  String? _editingId;         // null → жаңы, non-null → өзгөртүү

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _bodyCtrl.dispose();
    super.dispose();
  }

  // ── Баштапкы жүктөө + авто тазалоо ──
  Future<void> _init() async {
    await _autoDeleteOld();
    await _loadList();
  }

  // 7 күндөн эски билдирүүлөрдү өчүр
  Future<void> _autoDeleteOld() async {
    try {
      final cutoff = DateTime.now()
          .subtract(const Duration(days: 7))
          .toUtc()
          .toIso8601String();
      await supabase
          .from('admin_notifications')
          .delete()
          .lt('created_at', cutoff);
    } catch (e) {
      debugPrint('⚠️ autoDeleteOld ката: $e');
    }
  }

  // Тизмени жүктө
  Future<void> _loadList() async {
    setState(() => _loadingList = true);
    try {
      final rows = await supabase
          .from('admin_notifications')
          .select()
          .order('created_at', ascending: false);
      if (mounted) {
        setState(() {
          _sent = (rows as List).cast<Map<String, dynamic>>();
          _loadingList = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loadingList = false);
    }
  }

  // ── Сүрөт тандоо ──
  Future<void> _pickImage() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
      maxWidth: 1200,
    );
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    if (!mounted) return;
    setState(() => _pickedImage = bytes);
  }

  void _removeImage() => setState(() => _pickedImage = null);

  // ── Upload ──
  Future<String?> _uploadImage(Uint8List bytes) async {
    try {
      return await YandexStorageService.instance
          .uploadImage(bytes, folder: 'notifications');
    } catch (e) {
      debugPrint('❌ upload ката: $e');
      return null;
    }
  }

  // ── Edit баскычы басылганда форманы толтур ──
  void _startEdit(Map<String, dynamic> n) {
    setState(() {
      _editingId = n['id'] as String;
      _titleCtrl.text = n['title'] as String? ?? '';
      _bodyCtrl.text  = n['body']  as String? ?? '';
      _pickedImage    = null; // эски сүрөт URL'ди өзгөртпөй сакта
    });
    // Форма жагына scroll (жөнөкөй — жогору чыгарат)
    Scrollable.ensureVisible(
      context,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  // ── Жокко чыгаруу ──
  void _cancelEdit() {
    setState(() {
      _editingId = null;
      _titleCtrl.clear();
      _bodyCtrl.clear();
      _pickedImage = null;
    });
  }

  // ── Жөнөт / Сакта ──
  Future<void> _submit() async {
    final title = _titleCtrl.text.trim();
    final body  = _bodyCtrl.text.trim();
    if (title.isEmpty || body.isEmpty) {
      _snack('Аталышты жана текстти жазыңыз', error: true);
      return;
    }
    setState(() => _isSending = true);

    try {
      // Сүрөт upload
      String? imageUrl;
      if (_pickedImage != null) {
        setState(() => _isUploadingImage = true);
        imageUrl = await _uploadImage(_pickedImage!);
        setState(() => _isUploadingImage = false);
        if (imageUrl == null) {
          _snack('Сүрөттү жүктөөдө ката', error: true);
          setState(() => _isSending = false);
          return;
        }
      }

      if (_editingId != null) {
        // ── ӨЗГӨРТҮҮ ──
        final updateData = <String, dynamic>{
          'title': title,
          'body':  body,
        };
        if (imageUrl != null) updateData['image_url'] = imageUrl;

        await supabase
            .from('admin_notifications')
            .update(updateData)
            .eq('id', _editingId!);

        _snack('✅ Билдирүү өзгөртүлдү');
        _cancelEdit();
      } else {
        // ── ЖАҢЫ ──
        final count = await NotificationService().sendBroadcastNotification(
          title: title,
          body:  body,
        );

        await supabase.from('admin_notifications').insert({
          'title':      title,
          'body':       body,
          'created_at': DateTime.now().toIso8601String(),
          if (imageUrl != null) 'image_url': imageUrl,
        });

        _titleCtrl.clear();
        _bodyCtrl.clear();
        setState(() => _pickedImage = null);
        _snack('✅ $count колдонуучуга жөнөтүлдү!');
      }

      await _loadList();
    } catch (e) {
      _snack('Ката: $e', error: true);
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  // ── Өчүрүү ──
  Future<void> _delete(String id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Өчүрүү'),
        content: const Text('Бул билдирүү бардык колдонуучулардын экранынан жоголот. Ишенесизби?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Жок'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Ооба, өчүр',
                style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
    if (ok != true) return;

    try {
      // notification_reads да тазала
      await supabase
          .from('notification_reads')
          .delete()
          .eq('notification_id', id);
      await supabase
          .from('admin_notifications')
          .delete()
          .eq('id', id);
      _snack('Билдирүү өчүрүлдү');
      await _loadList();
    } catch (e) {
      _snack('Ката: $e', error: true);
    }
  }

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? AppColors.error : AppColors.success,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  String _timeAgo(String? createdAt) {
    if (createdAt == null) return '';
    final dt   = DateTime.tryParse(createdAt)?.toLocal();
    if (dt == null) return '';
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1)  return 'Азыр';
    if (diff.inHours < 1)    return '${diff.inMinutes} мүн. мурун';
    if (diff.inDays < 1)     return '${diff.inHours} саат мурун';
    if (diff.inDays < 7)     return '${diff.inDays} күн мурун';
    return '${dt.day}.${dt.month}.${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    final isDark     = Theme.of(context).brightness == Brightness.dark;
    final cardColor  = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final fillColor  = isDark ? const Color(0xFF2C2C2C) : const Color(0xFFF5F5F5);
    final textColor  = isDark ? Colors.white : AppColors.black;
    final subColor   = isDark ? Colors.white60 : AppColors.grey500;
    final labelColor = isDark ? Colors.white70 : AppColors.grey600;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [

        // ════════════════════════════════════════════
        // ФОРМА — жөнөтүү / өзгөртүү
        // ════════════════════════════════════════════
        Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              // Башлык
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFD97706), Color(0xFFEF4444)],
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      _editingId != null
                          ? Icons.edit_rounded
                          : Icons.campaign_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _editingId != null
                          ? 'Билдирүүнү өзгөртүү'
                          : 'Колдонуучуларга билдирүү',
                      style: AppTextStyles.headingSmall
                          .copyWith(color: textColor),
                    ),
                  ),
                  // Edit режимде — жокко чыгаруу
                  if (_editingId != null)
                    IconButton(
                      onPressed: _cancelEdit,
                      icon: const Icon(Icons.close, size: 20),
                      color: subColor,
                      tooltip: 'Жокко чыгаруу',
                    ),
                ],
              ),
              const SizedBox(height: 16),

              // Аталышы
              Text('Аталышы',
                  style: AppTextStyles.labelMedium
                      .copyWith(color: labelColor)),
              const SizedBox(height: 6),
              TextField(
                controller: _titleCtrl,
                style: TextStyle(color: textColor),
                decoration: InputDecoration(
                  hintText: 'Мис: Жаңы акция! 🔥',
                  hintStyle: TextStyle(color: AppColors.grey400),
                  filled: true,
                  fillColor: fillColor,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                          color: AppColors.primary, width: 1.5)),
                ),
              ),
              const SizedBox(height: 12),

              // Текст
              Text('Текст',
                  style: AppTextStyles.labelMedium
                      .copyWith(color: labelColor)),
              const SizedBox(height: 6),
              TextField(
                controller: _bodyCtrl,
                maxLines: 3,
                style: TextStyle(color: textColor),
                decoration: InputDecoration(
                  hintText: 'Билдирүүнүн толук текстин жазыңыз...',
                  hintStyle: TextStyle(color: AppColors.grey400),
                  filled: true,
                  fillColor: fillColor,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                          color: AppColors.primary, width: 1.5)),
                ),
              ),
              const SizedBox(height: 16),

              // Сүрөт
              Text('Сүрөт (милдеттүү эмес)',
                  style: AppTextStyles.labelMedium
                      .copyWith(color: labelColor)),
              const SizedBox(height: 8),

              if (_pickedImage == null)
                GestureDetector(
                  onTap: _pickImage,
                  child: Container(
                    width: double.infinity,
                    height: 110,
                    decoration: BoxDecoration(
                      color: fillColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.4),
                        width: 1.5,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_photo_alternate_outlined,
                            color: AppColors.primary, size: 34),
                        const SizedBox(height: 6),
                        Text('Галерейдан тандоо',
                            style: AppTextStyles.bodySmall
                                .copyWith(color: AppColors.primary)),
                      ],
                    ),
                  ),
                )
              else
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.memory(
                        _pickedImage!,
                        width: double.infinity,
                        height: 180,
                        fit: BoxFit.cover,
                      ),
                    ),
                    if (_isUploadingImage)
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Center(
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2.5),
                          ),
                        ),
                      ),
                    Positioned(
                      top: 8, right: 8,
                      child: GestureDetector(
                        onTap: _removeImage,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.65),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.close,
                              color: Colors.white, size: 18),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 8, right: 8,
                      child: GestureDetector(
                        onTap: _pickImage,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.65),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              Icon(Icons.edit, color: Colors.white, size: 14),
                              SizedBox(width: 4),
                              Text('Өзгөртүү',
                                  style: TextStyle(
                                      color: Colors.white, fontSize: 12)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

              const SizedBox(height: 16),

              // Жөнөт / Сакта баскычы
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: _isSending ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _editingId != null
                        ? const Color(0xFF2563EB)
                        : AppColors.primary,
                    disabledBackgroundColor: AppColors.grey300,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  icon: _isSending
                      ? const SizedBox(
                          width: 18, height: 18,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : Icon(
                          _editingId != null
                              ? Icons.save_rounded
                              : Icons.send_rounded,
                          color: Colors.white, size: 18),
                  label: Text(
                    _isSending
                        ? (_editingId != null
                            ? 'Сакталууда...'
                            : 'Жөнөтүлүүдө...')
                        : (_editingId != null
                            ? 'Сактоо'
                            : 'Баардыгына жөнөт'),
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ),

        // ════════════════════════════════════════════
        // ЖӨНӨТҮЛГӨН БИЛДИРҮҮЛӨРДҮН ТИЗМЕСИ
        // ════════════════════════════════════════════
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Text(
                'Жөнөтүлгөн билдирүүлөр',
                style: AppTextStyles.headingSmall.copyWith(color: textColor),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${_sent.length}',
                  style: AppTextStyles.labelSmall
                      .copyWith(color: AppColors.primary),
                ),
              ),
              const Spacer(),
              // Жаңылоо
              IconButton(
                onPressed: _loadList,
                icon: const Icon(Icons.refresh_rounded, size: 20),
                color: subColor,
                tooltip: 'Жаңылоо',
              ),
            ],
          ),
        ),

        // Маалымат: 7 күн
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Text(
            '⏱ Билдирүүлөр 7 күндөн кийин авто өчүрүлөт',
            style: AppTextStyles.labelSmall.copyWith(color: subColor),
          ),
        ),

        const SizedBox(height: 8),

        if (_loadingList)
          const Padding(
            padding: EdgeInsets.all(32),
            child: Center(
                child: CircularProgressIndicator(color: AppColors.primary)),
          )
        else if (_sent.isEmpty)
          Padding(
            padding: const EdgeInsets.all(32),
            child: Center(
              child: Column(
                children: [
                  Icon(Icons.notifications_none_rounded,
                      size: 56,
                      color: isDark ? Colors.white24 : Colors.grey[300]),
                  const SizedBox(height: 12),
                  Text('Жөнөтүлгөн билдирүү жок',
                      style:
                          AppTextStyles.bodyMedium.copyWith(color: subColor)),
                ],
              ),
            ),
          )
        else
          Builder(builder: (_) {
            final q = widget.searchQuery.toLowerCase().trim();
            final filtered = q.isEmpty
                ? _sent
                : _sent.where((n) {
                    final t = (n['title'] as String? ?? '').toLowerCase();
                    final b = (n['body'] as String? ?? '').toLowerCase();
                    return t.contains(q) || b.contains(q);
                  }).toList();
            if (filtered.isEmpty && q.isNotEmpty) {
              return Padding(
                padding: const EdgeInsets.all(32),
                child: Center(
                  child: Text(
                    'Издөө боюнча эч нерсе табылган жок',
                    style: AppTextStyles.bodySmall.copyWith(color: subColor),
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }
            return ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            itemCount: filtered.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (_, i) {
              final n        = filtered[i];
              final id       = n['id'] as String;
              final title    = n['title'] as String? ?? '';
              final body     = n['body']  as String? ?? '';
              final imageUrl = n['image_url'] as String?;
              final isEditing = _editingId == id;

              return Container(
                decoration: BoxDecoration(
                  color: isEditing
                      ? const Color(0xFF2563EB).withValues(alpha: 0.08)
                      : cardColor,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isEditing
                        ? const Color(0xFF2563EB).withValues(alpha: 0.5)
                        : (isDark
                            ? const Color(0xFF2A2560)
                            : Colors.grey.withValues(alpha: 0.15)),
                    width: isEditing ? 1.5 : 0.8,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Башлык + баскычтар
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Иконка
                              Container(
                                width: 38,
                                height: 38,
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [
                                      Color(0xFFD97706),
                                      Color(0xFFEF4444)
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(Icons.campaign_rounded,
                                    color: Colors.white, size: 18),
                              ),
                              const SizedBox(width: 10),
                              // Текст
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(title,
                                        style: AppTextStyles.labelLarge
                                            .copyWith(
                                          color: textColor,
                                          fontWeight: FontWeight.w700,
                                        )),
                                    const SizedBox(height: 3),
                                    Text(body,
                                        style: AppTextStyles.bodySmall
                                            .copyWith(color: subColor),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              // Edit + Delete
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _ActionBtn(
                                    icon: Icons.edit_rounded,
                                    color: const Color(0xFF2563EB),
                                    tooltip: 'Өзгөртүү',
                                    onTap: () => _startEdit(n),
                                  ),
                                  const SizedBox(width: 6),
                                  _ActionBtn(
                                    icon: Icons.delete_rounded,
                                    color: AppColors.error,
                                    tooltip: 'Өчүрүү',
                                    onTap: () => _delete(id),
                                  ),
                                ],
                              ),
                            ],
                          ),

                          // Сүрөт
                          if (imageUrl != null && imageUrl.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: CachedNetworkImage(
                                imageUrl: imageUrl,
                                width: double.infinity,
                                height: 160,
                                fit: BoxFit.cover,
                                placeholder: (_, __) => Container(
                                  height: 160,
                                  color: isDark
                                      ? const Color(0xFF2A2560)
                                      : const Color(0xFFEEEEEE),
                                  child: const Center(
                                    child: CircularProgressIndicator(
                                        color: AppColors.primary,
                                        strokeWidth: 2),
                                  ),
                                ),
                                errorWidget: (_, __, ___) => Container(
                                  height: 160,
                                  color: isDark
                                      ? const Color(0xFF2A2560)
                                      : const Color(0xFFEEEEEE),
                                  child: const Icon(Icons.broken_image,
                                      color: Colors.grey),
                                ),
                              ),
                            ),
                          ],

                          // Убакыт
                          const SizedBox(height: 8),
                          Text(
                            _timeAgo(n['created_at'] as String?),
                            style: AppTextStyles.labelSmall
                                .copyWith(color: AppColors.primary),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          );
          }),
      ],
    );
  }
}

// ── Кичине жардамчы баскыч ──
class _ActionBtn extends StatelessWidget {
  final IconData  icon;
  final Color     color;
  final String    tooltip;
  final VoidCallback onTap;

  const _ActionBtn({
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: color.withValues(alpha: isDark ? 0.18 : 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 17),
        ),
      ),
    );
  }
}