import 'package:flutter/material.dart';
import '../../../config/theme/app_colors.dart';
import '../../../config/theme/app_text_styles.dart';
import '../../../core/app_localizations.dart';

class FilterOptions {
  final RangeValues priceRange;
  final List<String> selectedSizes;
  final String sortBy;

  FilterOptions({
    required this.priceRange,
    required this.selectedSizes,
    required this.sortBy,
  });

  FilterOptions copyWith({
    RangeValues? priceRange,
    List<String>? selectedSizes,
    String? sortBy,
  }) {
    return FilterOptions(
      priceRange: priceRange ?? this.priceRange,
      selectedSizes: selectedSizes ?? this.selectedSizes,
      sortBy: sortBy ?? this.sortBy,
    );
  }
}

class FilterBottomSheet extends StatefulWidget {
  final FilterOptions initialOptions;
  final Function(FilterOptions) onApply;

  const FilterBottomSheet({
    super.key,
    required this.initialOptions,
    required this.onApply,
  });

  static Future<void> show(
    BuildContext context, {
    required FilterOptions initialOptions,
    required Function(FilterOptions) onApply,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => FilterBottomSheet(
        initialOptions: initialOptions,
        onApply: onApply,
      ),
    );
  }

  @override
  State<FilterBottomSheet> createState() => _FilterBottomSheetState();
}

class _FilterBottomSheetState extends State<FilterBottomSheet> {
  late RangeValues _priceRange;
  late List<String> _selectedSizes;
  late String _sortBy;
  late final TextEditingController _minCtrl;
  late final TextEditingController _maxCtrl;

  static const double _maxPrice = 1000000;

  final List<String> sizes = ['XS', 'S', 'M', 'L', 'XL', 'XXL'];

  final List<Map<String, String>> _sortValues = [
    {'value': 'popular',    'icon': '🔥', 'key': 'sort_popular'},
    {'value': 'price_asc',  'icon': '⬆️', 'key': 'sort_price_asc'},
    {'value': 'price_desc', 'icon': '⬇️', 'key': 'sort_price_desc'},
    {'value': 'rating',     'icon': '⭐', 'key': 'sort_rating'},
    {'value': 'newest',     'icon': '🆕', 'key': 'sort_newest'},
  ];

  @override
  void initState() {
    super.initState();
    _priceRange    = widget.initialOptions.priceRange;
    _minCtrl       = TextEditingController(text: _priceRange.start.toInt().toString());
    _maxCtrl       = TextEditingController(text: _priceRange.end.toInt().toString());
    _selectedSizes = List.from(widget.initialOptions.selectedSizes);
    _sortBy        = widget.initialOptions.sortBy;
  }

  @override
  void dispose() {
    _minCtrl.dispose();
    _maxCtrl.dispose();
    super.dispose();
  }

  void _reset() {
    setState(() {
      _priceRange    = const RangeValues(0, _maxPrice);
      _selectedSizes = [];
      _sortBy        = 'popular';
      _minCtrl.text  = '0';
      _maxCtrl.text  = _maxPrice.toInt().toString();
    });
  }

  int get _activeFilterCount {
    int count = 0;
    if (_priceRange.start > 0 || _priceRange.end < _maxPrice) count++;
    if (_selectedSizes.isNotEmpty) count++;
    if (_sortBy != 'popular') count++;
    return count;
  }

  String _formatPrice(double price) {
    if (price >= _maxPrice) return '1 000 000+ с';
    final str = price.toInt().toString();
    final buf = StringBuffer();
    for (int i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) buf.write(' ');
      buf.write(str[i]);
    }
    return '${buf.toString()} с';
  }

  Widget _priceField({
    required TextEditingController controller,
    required String hint,
    required ValueChanged<String> onChanged,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2C2C2C) : const Color(0xFFF7F7F7),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isDark ? const Color(0xFF3A3A3A) : AppColors.grey200),
      ),
      child: TextField(
        controller: controller,
        keyboardType: TextInputType.number,
        style: AppTextStyles.bodyMedium.copyWith(
          color: isDark ? Colors.white : AppColors.black,
        ),
        onChanged: onChanged,
        decoration: InputDecoration(
          hintText: hint,
          suffixText: 'с',
          suffixStyle: TextStyle(color: isDark ? AppColors.grey400 : AppColors.grey500),
          border: InputBorder.none,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc    = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor      = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final dividerColor = isDark ? const Color(0xFF2C2C2C) : AppColors.grey100;
    final sortItemBg   = isDark ? const Color(0xFF2C2C2C) : AppColors.grey50;
    final textColor    = isDark ? Colors.white : AppColors.black;
    final sizeUnselBg  = isDark ? const Color(0xFF2C2C2C) : AppColors.grey50;
    final sizeUnselBorder = isDark ? const Color(0xFF3A3A3A) : AppColors.grey200;

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Жогорку сызык ──
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40, height: 4,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF3A3A3A) : AppColors.grey300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // ── Баш сөз ──
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text(loc.get('filter'), style: AppTextStyles.headingMedium.copyWith(color: textColor)),
                    if (_activeFilterCount > 0) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text('$_activeFilterCount', style: AppTextStyles.labelSmall.copyWith(color: Colors.white)),
                      ),
                    ],
                  ],
                ),
                TextButton(
                  onPressed: _reset,
                  child: Text(loc.get('filter_reset'), style: AppTextStyles.labelLarge.copyWith(color: AppColors.grey500)),
                ),
              ],
            ),
          ),

          Divider(color: dividerColor, height: 24),

          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  // ── 1. БААСЫ ──
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(loc.get('price'), style: AppTextStyles.headingSmall.copyWith(color: textColor)),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${_formatPrice(_priceRange.start)} — ${_formatPrice(_priceRange.end)}',
                          style: AppTextStyles.labelMedium.copyWith(color: AppColors.primary),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      activeTrackColor:   AppColors.primary,
                      inactiveTrackColor: isDark ? const Color(0xFF3A3A3A) : AppColors.grey200,
                      thumbColor:  AppColors.primary,
                      overlayColor: AppColors.primary.withValues(alpha: 0.1),
                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 12),
                      trackHeight: 4,
                    ),
                    child: RangeSlider(
                      values: _priceRange,
                      min: 0,
                      max: _maxPrice,
                      divisions: 200,
                      onChanged: (values) {
                        setState(() {
                          _priceRange   = values;
                          _minCtrl.text = values.start.toInt().toString();
                          _maxCtrl.text = values.end.toInt().toString();
                        });
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _priceField(
                          controller: _minCtrl,
                          hint: '0',
                          isDark: isDark,
                          onChanged: (val) {
                            final v = double.tryParse(val) ?? 0;
                            setState(() {
                              final clamped = v.clamp(0, _priceRange.end);
                              _priceRange = RangeValues(clamped.toDouble(), _priceRange.end);
                            });
                          },
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: Text('—', style: AppTextStyles.bodyMedium.copyWith(color: textColor)),
                      ),
                      Expanded(
                        child: _priceField(
                          controller: _maxCtrl,
                          hint: '1000000',
                          isDark: isDark,
                          onChanged: (val) {
                            final v = double.tryParse(val) ?? _maxPrice;
                            setState(() {
                              final clamped = v.clamp(_priceRange.start, _maxPrice);
                              _priceRange = RangeValues(_priceRange.start, clamped.toDouble());
                            });
                          },
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),
                  Divider(color: dividerColor),
                  const SizedBox(height: 20),

                  // ── 2. СОРТТОО ──
                  Text(loc.get('filter_sort'), style: AppTextStyles.headingSmall.copyWith(color: textColor)),
                  const SizedBox(height: 12),
                  ..._sortValues.map((option) {
                    final isSelected = _sortBy == option['value'];
                    return GestureDetector(
                      onTap: () => setState(() => _sortBy = option['value']!),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          color: isSelected ? AppColors.primary.withValues(alpha: 0.08) : sortItemBg,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected ? AppColors.primary : Colors.transparent,
                            width: 1.5,
                          ),
                        ),
                        child: Row(
                          children: [
                            Text(option['icon']!, style: const TextStyle(fontSize: 18)),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                loc.get(option['key']!),
                                style: AppTextStyles.bodyMedium.copyWith(
                                  color: isSelected ? AppColors.primary : textColor,
                                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                                ),
                              ),
                            ),
                            if (isSelected)
                              const Icon(Icons.check_circle, color: AppColors.primary, size: 20),
                          ],
                        ),
                      ),
                    );
                  }),

                  const SizedBox(height: 20),
                  Divider(color: dividerColor),
                  const SizedBox(height: 20),

                  // ── 3. РАЗМЕР ──
                  Text(loc.get('size_label'), style: AppTextStyles.headingSmall.copyWith(color: textColor)),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: sizes.map((size) {
                      final isSelected = _selectedSizes.contains(size);
                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            if (isSelected) {
                              _selectedSizes.remove(size);
                            } else {
                              _selectedSizes.add(size);
                            }
                          });
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: 60, height: 48,
                          decoration: BoxDecoration(
                            color: isSelected ? AppColors.primary : sizeUnselBg,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isSelected ? AppColors.primary : sizeUnselBorder,
                              width: 1.5,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              size,
                              style: AppTextStyles.labelLarge.copyWith(
                                color: isSelected ? Colors.white : textColor,
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),

          // ── Колдонуу баскычы ──
          Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            decoration: BoxDecoration(
              color: bgColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 12,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: ElevatedButton(
              onPressed: () {
                widget.onApply(FilterOptions(
                  priceRange:    _priceRange,
                  selectedSizes: _selectedSizes,
                  sortBy:        _sortBy,
                ));
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 56),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
              child: Text(
                _activeFilterCount > 0
                    ? '${loc.get('filter_apply')} ($_activeFilterCount ${loc.get('filter_count_suffix')})'
                    : loc.get('filter_apply'),
                style: AppTextStyles.headingSmall.copyWith(color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}