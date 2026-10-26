import 'package:flutter/material.dart';
import '../../../config/theme/app_colors.dart';
import '../../../config/theme/app_text_styles.dart';
import '../../../core/app_localizations.dart';

class SearchBarWidget extends StatefulWidget {
  final Function(String) onChanged;
  final Function()? onClear;

  const SearchBarWidget({
    super.key,
    required this.onChanged,
    this.onClear,
  });

  @override
  State<SearchBarWidget> createState() => _SearchBarWidgetState();
}

class _SearchBarWidgetState extends State<SearchBarWidget> {
  late TextEditingController _controller;
  late FocusNode _focusNode;  // ← КОШ

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _focusNode = FocusNode();  // ← КОШ
    _controller.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();  // ← КОШ
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final loc    = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fillColor   = isDark
        ? const Color(0xFF2C2C2C).withOpacity(0.55)
        : AppColors.grey50.withOpacity(0.55);
    final borderColor = isDark ? const Color(0xFF3A3A3A) : AppColors.grey200;

    return TextFormField(
      controller: _controller,
      focusNode: _focusNode,  // ← КОШ
      onChanged: widget.onChanged,
      // ── Тышка тийгенде клавиатура жабылат ── ← КОШ
      onTapOutside: (_) {
        _focusNode.unfocus();
      },
      style: AppTextStyles.bodyMedium.copyWith(
        color: isDark ? Colors.white : AppColors.black,
      ),
      decoration: InputDecoration(
        hintText: loc.get('search_hint'),
        hintStyle: AppTextStyles.bodyMedium.copyWith(color: AppColors.grey400),
        prefixIcon: const Icon(Icons.search, color: AppColors.primary, size: 24),
        suffixIcon: _controller.text.isNotEmpty
            ? GestureDetector(
                onTap: () {
                  _controller.clear();
                  _focusNode.unfocus();  // ← KOШ: тазалагандан кийин жабылат
                  widget.onClear?.call();
                  widget.onChanged('');
                },
                child: const Icon(Icons.close, color: AppColors.grey400),
              )
            : null,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        filled: true,
        fillColor: fillColor,
      ),
    );
  }
}