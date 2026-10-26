// ══════════════════════════════════════════════════════
// АРЫЗ ФОРМАСЫ BOTTOM SHEET
// product_detail_screen.dart файлынан бөлүнүп чыгарылды.
// ══════════════════════════════════════════════════════
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../config/theme/app_colors.dart';
import '../../../config/theme/app_text_styles.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show FileOptions;
import '../../../core/supabase_client.dart';
import '../../../core/utils/image_utils.dart';

class ComplaintSheet extends StatefulWidget {
  final String productId;
  final String productName;
  final bool isRu;

  // Арыз кайсы сатуучуга/дүкөнгө айтылып жатканы (админ панелинде көрүнөт)
  final String? storeId;
  final String? sellerId;
  final String shopName;
  final String sellerName;
  final String containerNumber;

  const ComplaintSheet({
    super.key,
    required this.productId,
    required this.productName,
    required this.isRu,
    this.storeId,
    this.sellerId,
    this.shopName = '',
    this.sellerName = '',
    this.containerNumber = '',
  });

  @override
  State<ComplaintSheet> createState() => _ComplaintSheetState();
}

class _ComplaintSheetState extends State<ComplaintSheet> {
  final _purposeCtrl = TextEditingController();
  final _detailsCtrl = TextEditingController();
  final _emailCtrl   = TextEditingController();
  final _nameCtrl    = TextEditingController();
  String? _selectedTopic;
  bool _isSending = false;

  // Скриншот (милдеттүү эмес)
  Uint8List? _screenshotBytes;

  Future<void> _pickScreenshot() async {
    try {
      final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      if (!mounted) return;
      setState(() => _screenshotBytes = bytes);
    } catch (e) {
      debugPrint('❌ pick screenshot: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(widget.isRu
            ? 'Не удалось выбрать фото'
            : 'Сүрөттү тандоо мүмкүн болгон жок'),
        backgroundColor: AppColors.error,
      ));
    }
  }

  /// Скриншотту Backblaze'ке жүктөп, URL кайтарат (скриншот жок болсо null).
  Future<String?> _uploadScreenshot() async {
    final raw = _screenshotBytes;
    if (raw == null) return null;
    Uint8List bytes = raw;
    try {
      bytes = await compressImage(raw, quality: 80, maxWidth: 1280, maxHeight: 1280);
    } catch (e) {
      debugPrint('⚠️ screenshot compress: $e (түп нускасы жүктөлөт)');
    }
    // Supabase Storage → "complaint-screenshots" bucket (public)
    final uid = supabase.auth.currentUser?.id ?? 'guest';
    final path = '$uid/${DateTime.now().millisecondsSinceEpoch}.jpg';
    try {
      await supabase.storage.from('complaint-screenshots').uploadBinary(
            path,
            bytes,
            fileOptions: const FileOptions(
              contentType: 'image/jpeg',
              upsert: false,
            ),
          );
    } catch (e) {
      debugPrint('❌ screenshot upload: $e');
      throw Exception(widget.isRu
          ? 'Не удалось загрузить скриншот'
          : 'Скриншотту жүктөө мүмкүн болгон жок');
    }
    return supabase.storage.from('complaint-screenshots').getPublicUrl(path);
  }

  final List<Map<String, String>> _topics = [
    {'ky': 'Жалган сүрөт/маалымат', 'ru': 'Ложное фото/описание'},
    {'ky': 'Алдамчы сатуучу',       'ru': 'Мошенник'},
    {'ky': 'Сапатсыз товар',         'ru': 'Некачественный товар'},
    {'ky': 'Баасы жалган',           'ru': 'Неверная цена'},
    {'ky': 'Жагымсыз мамиле',        'ru': 'Грубое обращение'},
    {'ky': 'Башка',                  'ru': 'Другое'},
  ];

  @override
  void dispose() {
    _purposeCtrl.dispose();
    _detailsCtrl.dispose();
    _emailCtrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_selectedTopic == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(widget.isRu ? 'Тему выберите' : 'Теманы тандаңыз'),
        backgroundColor: AppColors.error,
      ));
      return;
    }
    if (_purposeCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(widget.isRu ? 'Опишите причину' : 'Максатын жазыңыз'),
        backgroundColor: AppColors.error,
      ));
      return;
    }
    if (_emailCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(widget.isRu ? 'Введите email' : 'Email жазыңыз'),
        backgroundColor: AppColors.error,
      ));
      return;
    }

    setState(() => _isSending = true);
    try {
      final user = supabase.auth.currentUser;
      final screenshotUrl = await _uploadScreenshot();
      await supabase.from('complaints').insert({
        'product_id':   widget.productId,
        'store_id':         widget.storeId,
        'seller_id':        widget.sellerId,
        'shop_name':        widget.shopName,
        'seller_name':      widget.sellerName,
        'container_number': widget.containerNumber,
        'screenshot_url':   screenshotUrl,
        'user_id':      user?.id,
        'sender_name':  _nameCtrl.text.trim().isNotEmpty ? _nameCtrl.text.trim() : (user?.email ?? ''),
        'sender_email': _emailCtrl.text.trim(),
        'topic':        _selectedTopic,
        'purpose':      _purposeCtrl.text.trim(),
        'details':      _detailsCtrl.text.trim(),
        'is_read':      false,
      });
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
          widget.isRu
              ? '✅ Жалоба отправлена. Ответ придёт на вашу почту.'
              : '✅ Арыз жөнөтүлдү. Жооп почтаңызга келет.',
        ),
        backgroundColor: AppColors.success,
        duration: const Duration(seconds: 4),
      ));
    } catch (e) {
      debugPrint('❌ complaint send: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(widget.isRu ? 'Ошибка: $e' : 'Ката: $e'),
          backgroundColor: AppColors.error,
        ));
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subColor = isDark ? Colors.white54 : AppColors.grey500;
    final fillColor = isDark ? const Color(0xFF2C2C2C) : const Color(0xFFF5F5F5);
    final handleColor = isDark ? const Color(0xFF3A3A3A) : Colors.grey[300]!;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── handle ──
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: handleColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF4444).withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.flag_rounded,
                        color: Color(0xFFEF4444), size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.isRu ? 'Пожаловаться' : 'Арыздануу',
                          style: AppTextStyles.headingSmall.copyWith(color: textColor),
                        ),
                        Text(
                          widget.productName,
                          style: AppTextStyles.labelSmall.copyWith(color: subColor),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (widget.shopName.isNotEmpty || widget.sellerName.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: fillColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.storefront_rounded, size: 18, color: subColor),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${widget.isRu ? 'Кому' : 'Кимге'}: '
                          '${widget.shopName.isNotEmpty ? widget.shopName : widget.sellerName}'
                          '${widget.containerNumber.isNotEmpty ? ' • ${widget.containerNumber}' : ''}',
                          style: AppTextStyles.labelMedium.copyWith(color: textColor),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 20),

              // ── Тема ──
              Text(
                widget.isRu ? 'Тема *' : 'Тема *',
                style: AppTextStyles.labelMedium.copyWith(color: subColor),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _topics.map((t) {
                  final label = widget.isRu ? t['ru']! : t['ky']!;
                  final isSelected = _selectedTopic == label;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedTopic = label),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFFEF4444)
                            : fillColor,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected
                              ? const Color(0xFFEF4444)
                              : (isDark ? Colors.white12 : AppColors.grey200),
                        ),
                      ),
                      child: Text(
                        label,
                        style: AppTextStyles.labelSmall.copyWith(
                          color: isSelected ? Colors.white : textColor,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),

              // ── Максат ──
              Text(
                widget.isRu ? 'Причина жалобы *' : 'Арыздын максаты *',
                style: AppTextStyles.labelMedium.copyWith(color: subColor),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _purposeCtrl,
                maxLines: 2,
                style: TextStyle(color: textColor),
                decoration: InputDecoration(
                  hintText: widget.isRu
                      ? 'Кратко опишите причину...'
                      : 'Кыскача сүрөттөңүз...',
                  hintStyle: AppTextStyles.bodyMedium.copyWith(color: subColor),
                  filled: true,
                  fillColor: fillColor,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.all(14),
                ),
              ),
              const SizedBox(height: 12),

              // ── Кошумча маалымат ──
              Text(
                widget.isRu ? 'Подробности (необязательно)' : 'Кошумча маалымат (милдеттүү эмес)',
                style: AppTextStyles.labelMedium.copyWith(color: subColor),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _detailsCtrl,
                maxLines: 3,
                style: TextStyle(color: textColor),
                decoration: InputDecoration(
                  hintText: widget.isRu
                      ? 'Дополнительные детали...'
                      : 'Кошумча деталдар...',
                  hintStyle: AppTextStyles.bodyMedium.copyWith(color: subColor),
                  filled: true,
                  fillColor: fillColor,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.all(14),
                ),
              ),
              const SizedBox(height: 12),

              // ── Скриншот ──
              Text(
                widget.isRu ? 'Скриншот (необязательно)' : 'Скриншот (милдеттүү эмес)',
                style: AppTextStyles.labelMedium.copyWith(color: subColor),
              ),
              const SizedBox(height: 8),
              if (_screenshotBytes == null)
                GestureDetector(
                  onTap: _isSending ? null : _pickScreenshot,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    decoration: BoxDecoration(
                      color: fillColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isDark ? Colors.white12 : AppColors.grey200,
                      ),
                    ),
                    child: Column(
                      children: [
                        const Icon(Icons.add_photo_alternate_outlined,
                            color: Color(0xFFEF4444), size: 28),
                        const SizedBox(height: 6),
                        Text(
                          widget.isRu ? 'Добавить скриншот' : 'Скриншот кошуу',
                          style: AppTextStyles.labelMedium
                              .copyWith(color: textColor),
                        ),
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
                        _screenshotBytes!,
                        width: double.infinity,
                        height: 180,
                        fit: BoxFit.cover,
                      ),
                    ),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: GestureDetector(
                        onTap: _isSending
                            ? null
                            : () => setState(() => _screenshotBytes = null),
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: const BoxDecoration(
                            color: Colors.black54,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.close,
                              color: Colors.white, size: 18),
                        ),
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 12),

              // ── Аты ──
              Text(
                widget.isRu ? 'Ваше имя' : 'Атыңыз',
                style: AppTextStyles.labelMedium.copyWith(color: subColor),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _nameCtrl,
                style: TextStyle(color: textColor),
                decoration: InputDecoration(
                  hintText: widget.isRu ? 'Имя Фамилия' : 'Атыңыз',
                  hintStyle: AppTextStyles.bodyMedium.copyWith(color: subColor),
                  filled: true,
                  fillColor: fillColor,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.all(14),
                ),
              ),
              const SizedBox(height: 12),

              // ── Email ──
              Text(
                widget.isRu ? 'Ваш email *' : 'Email дарегиңиз *',
                style: AppTextStyles.labelMedium.copyWith(color: subColor),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                style: TextStyle(color: textColor),
                decoration: InputDecoration(
                  hintText: 'example@mail.com',
                  hintStyle: AppTextStyles.bodyMedium.copyWith(color: subColor),
                  filled: true,
                  fillColor: fillColor,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.all(14),
                ),
              ),
              const SizedBox(height: 8),

              // ── Почта эскертүүсү ──
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, size: 16, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        widget.isRu
                            ? 'Ответ на жалобу придёт на вашу электронную почту.'
                            : 'Арыздын жообу почтаңызга жөнөтүлөт.',
                        style: AppTextStyles.labelSmall.copyWith(color: AppColors.primary),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // ── Жиберүү ──
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _isSending ? null : _send,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFEF4444),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                  child: _isSending
                      ? const SizedBox(
                          width: 22, height: 22,
                          child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2.5,
                          ),
                        )
                      : Text(
                          widget.isRu ? 'Отправить жалобу' : 'Арыз жөнөтүү',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
