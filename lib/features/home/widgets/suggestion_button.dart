import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../config/theme/app_colors.dart';
import '../../../config/theme/app_text_styles.dart';
import '../../../core/supabase_client.dart';

class SuggestionButton extends StatefulWidget {
  const SuggestionButton({super.key});

  @override
  State<SuggestionButton> createState() => _SuggestionButtonState();
}

class _SuggestionButtonState extends State<SuggestionButton> {
  static const _kCount = 'suggestion_count';
  static const _kDate = 'suggestion_date';
  static const _maxPerDay = 3;

  int _todayCount = 0;
  String? _selectedType;
  final _ctrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadCount();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _loadCount() async {
    final prefs = await SharedPreferences.getInstance();
    final savedDate = prefs.getString(_kDate) ?? '';
    final today = DateTime.now().toIso8601String().substring(0, 10);

    if (savedDate != today) {
      await prefs.setInt(_kCount, 0);
      await prefs.setString(_kDate, today);
    }

    if (mounted) setState(() => _todayCount = prefs.getInt(_kCount) ?? 0);
  }

  Future<void> _sendSuggestion() async {
    final user = supabase.auth.currentUser;
    final profile = await supabase
        .from('profiles')
        .select('full_name')
        .eq('id', user!.id)
        .maybeSingle();

    await supabase.from('buyer_suggestions').insert({
      'user_id': user.id,
      'user_name': profile?['full_name'] ?? 'Белгисиз',
      'type': _selectedType ?? 'general', // тип тандалбаса 'general' болот
      'message': _ctrl.text.trim(),
    });

    final prefs = await SharedPreferences.getInstance();
    final newCount = _todayCount + 1;
    await prefs.setInt(_kCount, newCount);
    if (mounted) setState(() => _todayCount = newCount);
  }

  Widget _typeChip(String label, String value) {
    final isSelected = _selectedType == value;
    return GestureDetector(
      onTap: () => setState(() {
        // Эгер эле тандалган болсо — тандоону алып салат (toggle)
        _selectedType = isSelected ? null : value;
      }),
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color.fromARGB(255, 217, 186, 151).withValues(alpha: 0.1)
              : Colors.grey.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? AppColors.primary : Colors.transparent,
          ),
        ),
        child: Text(
          label,
          style: AppTextStyles.labelLarge.copyWith(
            color: isSelected
                ? AppColors.primary
                : const Color.fromARGB(221, 224, 157, 11),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLocked = _todayCount >= _maxPerDay;

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: isLocked
          ? Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('🔒', style: TextStyle(fontSize: 40)),
                const SizedBox(height: 12),
                Text('Бүгүн лимит толду / Лимит исчерпан',
                    style: AppTextStyles.headingSmall,
                    textAlign: TextAlign.center),
                const SizedBox(height: 6),
                Text(
                  'Түнкү 00:00 дан кийин кайра жөнөтө аласыз\nПосле 00:00 можно отправить снова',
                  style: AppTextStyles.bodyMedium.copyWith(color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
              ],
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('💬 Сурануу / Предложение',
                        style: AppTextStyles.headingSmall),
                    const Spacer(),
                    Text(
                      'Бүгүн: $_todayCount/$_maxPerDay',
                      style:
                          AppTextStyles.labelSmall.copyWith(color: Colors.grey),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // Кичинекей эскертме — тип тандоо милдеттүү эмес
                Text(
                  '💡 Категория тандоо милдеттүү эмес',
                  style: AppTextStyles.labelSmall.copyWith(color: Colors.grey),
                ),
                const SizedBox(height: 12),
                _typeChip('🆕 Жаңы товар / Новый товар', 'new_feature'),
                _typeChip(
                    '📂 Категория жок / Нет категории', 'missing_category'),
                _typeChip('📦 Товар аз / Мало товаров', 'low_stock'),
                const SizedBox(height: 14),
                TextField(
                  controller: _ctrl,
                  maxLines: 3,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: 'Жазыңыз / Напишите...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color.fromARGB(255, 49, 208, 38),
                      disabledBackgroundColor:
                          Colors.grey.withValues(alpha: 0.3),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    // ✅ Эми текст жазылган болсо жетиштүү — тип тандабай жөнөтсө болот
                    onPressed: _ctrl.text.trim().isEmpty
                        ? null
                        : () async {
                            Navigator.pop(context);
                            await _sendSuggestion();
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('✅ Билдирүү жөнөтүлдү!'),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            }
                          },
                    child: const Text('Жөнөт / Отправить',
                        style: TextStyle(color: Colors.white)),
                  ),
                ),
              ],
            ),
    );
  }
}