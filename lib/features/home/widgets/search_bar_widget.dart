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

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _controller.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final loc    = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fillColor   = isDark ? const Color(0xFF2C2C2C) : AppColors.grey50;
    final borderColor = isDark ? const Color(0xFF3A3A3A) : AppColors.grey200;

    return TextFormField(
      controller: _controller,
      onChanged: widget.onChanged,
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