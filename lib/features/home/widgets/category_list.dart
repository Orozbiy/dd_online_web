import 'package:flutter/material.dart';
import '../../../config/theme/app_colors.dart';
import '../../../config/theme/app_text_styles.dart';
import '../../../core/app_localizations.dart';
import '../models/category_model.dart';

enum ProductFilterMode { all, newest, popular }

class CategoryList extends StatefulWidget {
  final Function(String) onCategorySelected;
  final Function(ProductFilterMode)? onFilterModeChanged;

  const CategoryList({
    super.key,
    required this.onCategorySelected,
    this.onFilterModeChanged,
  });

  @override
  State<CategoryList> createState() => _CategoryListState();
}

class _CategoryListState extends State<CategoryList> {
  String? _selectedCategoryId;
  String? _selectedSubId;
  String? _selectedSubSubId;
  late List<CategoryModel> _categories;
  ProductFilterMode _filterMode = ProductFilterMode.all;

  @override
  void initState() {
    super.initState();
    _categories = CategoryModel.getCategories();
  }

  CategoryModel? get _selectedCategory {
    if (_selectedCategoryId == null) return null;
    try {
      return _categories.firstWhere((c) => c.id == _selectedCategoryId);
    } catch (_) {
      return null;
    }
  }

  SubCategoryModel? get _selectedSub {
    final cat = _selectedCategory;
    if (cat == null || _selectedSubId == null) return null;
    try {
      return cat.subcategories.firstWhere((s) => s.id == _selectedSubId);
    } catch (_) {
      return null;
    }
  }

  void _onCategoryTap(CategoryModel cat) {
    setState(() {
      if (_selectedCategoryId == cat.id) {
        _selectedCategoryId = null;
        _selectedSubId = null;
        _selectedSubSubId = null;
        _filterMode = ProductFilterMode.all;
        widget.onFilterModeChanged?.call(ProductFilterMode.all);
        widget.onCategorySelected('');
      } else {
        _selectedCategoryId = cat.id;
        _selectedSubId = null;
        _selectedSubSubId = null;
        widget.onCategorySelected(cat.id);
      }
    });
  }

  void _onSubCategoryTap(SubCategoryModel sub) {
    setState(() {
      if (_selectedSubId == sub.id) {
        _selectedSubId = null;
        _selectedSubSubId = null;
        widget.onCategorySelected(_selectedCategoryId ?? '');
      } else {
        _selectedSubId = sub.id;
        _selectedSubSubId = null;
        if (sub.id.endsWith('_1')) {
          widget.onCategorySelected(_selectedCategoryId ?? '');
        } else {
          widget.onCategorySelected(sub.id);
        }
      }
    });
  }

  void _onSubSubCategoryTap(SubCategoryModel subSub) {
    setState(() {
      if (_selectedSubSubId == subSub.id) {
        _selectedSubSubId = null;
        widget.onCategorySelected(_selectedSubId ?? '');
      } else {
        _selectedSubSubId = subSub.id;
        widget.onCategorySelected(subSub.id);
      }
    });
  }

  void _openCategorySheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CategoryBottomSheet(
        categories: _categories,
        selectedId: _selectedCategoryId,
        onSelected: (cat) {
          Navigator.pop(context);
          _onCategoryTap(cat);
        },
      ),
    );
  }

  void _setFilterMode(ProductFilterMode mode) {
    if (_filterMode == mode) {
      setState(() => _filterMode = ProductFilterMode.all);
      widget.onFilterModeChanged?.call(ProductFilterMode.all);
    } else {
      setState(() => _filterMode = mode);
      widget.onFilterModeChanged?.call(mode);
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc    = AppLocalizations.of(context);
    final cat    = _selectedCategory;
    final sub    = _selectedSub;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final inactiveBg   = isDark ? const Color(0xFF2C2C2C) : AppColors.grey100;
    final inactiveColor = isDark ? AppColors.grey400 : AppColors.grey600;

    // Категория тандалганда анын түсүн алабыз, болбосо primary
    final activeCatColor = cat != null
        ? Color(int.parse('0xFF${cat.color}'))
        : AppColors.primary;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // ══════════════════════════════════════════
        // 1-ДЕҢГЭЭЛ: Негизги категория + Filter pills
        // ══════════════════════════════════════════
        SizedBox(
          height: 44,
          child: ListView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            children: [
              // ── Категория pill ──
              _PillButton(
                icon: Icons.grid_view_rounded,
                emoji: cat?.icon,
                label: _selectedCategoryId != null
                    ? (cat?.localizedName(loc.locale.languageCode) ??
                        loc.get('cat_label'))
                    : loc.get('cat_label'),
                isActive: _selectedCategoryId != null,
                activeColor: activeCatColor,
                inactiveBg: inactiveBg,
                inactiveColor: inactiveColor,
                showClose: _selectedCategoryId != null,
                onTap: _openCategorySheet,
              ),
              const SizedBox(width: 8),

              // ── Жаңы pill ──
              _PillButton(
                icon: Icons.fiber_new_rounded,
                label: loc.get('cat_newest'),
                isActive: _filterMode == ProductFilterMode.newest,
                activeColor: AppColors.primary,
                inactiveBg: inactiveBg,
                inactiveColor: inactiveColor,
                onTap: () => _setFilterMode(ProductFilterMode.newest),
              ),
              const SizedBox(width: 8),

              // ── Таанымал pill ──
              _PillButton(
                icon: Icons.trending_up_rounded,
                label: loc.get('cat_popular'),
                isActive: _filterMode == ProductFilterMode.popular,
                activeColor: const Color(0xFFD97706),
                inactiveBg: inactiveBg,
                inactiveColor: inactiveColor,
                onTap: () => _setFilterMode(ProductFilterMode.popular),
              ),
            ],
          ),
        ),

        // ══════════════════════════════════════════
        // 2-ДЕҢГЭЭЛ: SubCategory тилкеси
        // ══════════════════════════════════════════
        AnimatedSize(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          child: cat != null && cat.subcategories.isNotEmpty
              ? _PillRow(
                  items: cat.subcategories,
                  selectedId: _selectedSubId ?? '${cat.id}_1',
                  activeColor: activeCatColor,
                  isDark: isDark,
                  topMargin: 8,
                  onTap: _onSubCategoryTap,
                )
              : const SizedBox.shrink(),
        ),

        // ══════════════════════════════════════════
        // 3-ДЕҢГЭЭЛ: SubSubCategory тилкеси
        // ══════════════════════════════════════════
        AnimatedSize(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          child: sub != null && sub.hasSubItems
              ? _PillRow(
                  items: sub.subItems,
                  selectedId: _selectedSubSubId ?? '',
                  activeColor: activeCatColor,
                  isDark: isDark,
                  topMargin: 4,
                  isSubSub: true,
                  onTap: _onSubSubCategoryTap,
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════
// Бирдей стилдеги Pill баскычы (1-деңгээл үчүн)
// ══════════════════════════════════════════════════════════
class _PillButton extends StatelessWidget {
  final IconData icon;
  final String? emoji;
  final String label;
  final bool isActive;
  final Color activeColor;
  final Color inactiveBg;
  final Color inactiveColor;
  final bool showClose;
  final VoidCallback onTap;

  const _PillButton({
    required this.icon,
    this.emoji,
    required this.label,
    required this.isActive,
    required this.activeColor,
    required this.inactiveBg,
    required this.inactiveColor,
    this.showClose = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 0),
        decoration: BoxDecoration(
          color: isActive ? activeColor : inactiveBg,
          borderRadius: BorderRadius.circular(22),
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: activeColor.withValues(alpha: 0.35),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  )
                ]
              : [],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Эмoji болсо — ошону, болбосо иконка
            if (isActive && emoji != null)
              Text(emoji!, style: const TextStyle(fontSize: 14))
            else
              Icon(icon,
                  size: 16,
                  color: isActive ? Colors.white : inactiveColor),
            const SizedBox(width: 6),
            Text(
              label,
              style: AppTextStyles.labelLarge.copyWith(
                color: isActive ? Colors.white : inactiveColor,
                fontSize: 13,
                fontWeight:
                    isActive ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
            if (showClose) ...[
              const SizedBox(width: 4),
              Icon(Icons.close_rounded,
                  size: 14,
                  color: Colors.white.withValues(alpha: 0.8)),
            ],
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
// Бирдей стилдеги Pill тизмеси (2 жана 3-деңгээл үчүн)
// ══════════════════════════════════════════════════════════
class _PillRow extends StatelessWidget {
  final List<SubCategoryModel> items;
  final String selectedId;
  final Color activeColor;
  final bool isDark;
  final double topMargin;
  final bool isSubSub;
  final Function(SubCategoryModel) onTap;

  const _PillRow({
    required this.items,
    required this.selectedId,
    required this.activeColor,
    required this.isDark,
    required this.topMargin,
    required this.onTap,
    this.isSubSub = false,
  });

  @override
  Widget build(BuildContext context) {
    final double rowHeight = isSubSub ? 40 : 44;
    final double fontSize  = isSubSub ? 11.5 : 12.5;
    final double iconSize  = isSubSub ? 13.0 : 14.0;
    final EdgeInsets padding = isSubSub
        ? const EdgeInsets.symmetric(horizontal: 11, vertical: 0)
        : const EdgeInsets.symmetric(horizontal: 13, vertical: 0);

    final unselBg = isDark
        ? activeColor.withValues(alpha: 0.15)
        : activeColor.withValues(alpha: 0.08);
    final unselBorder = activeColor.withValues(alpha: 0.25);
    final unselText = isDark
        ? activeColor.withValues(alpha: 0.9)
        : activeColor.withValues(alpha: 0.8);

    return SizedBox(
      height: rowHeight + topMargin,
      child: Padding(
        padding: EdgeInsets.only(top: topMargin),
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          itemCount: items.length,
          separatorBuilder: (_, __) => const SizedBox(width: 7),
          itemBuilder: (context, i) {
            final item = items[i];
            final isSelected = selectedId == item.id;

            return GestureDetector(
              onTap: () => onTap(item),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: padding,
                decoration: BoxDecoration(
                  color: isSelected ? activeColor : unselBg,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: isSelected ? activeColor : unselBorder,
                    width: 1.5,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: activeColor.withValues(alpha: 0.28),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          )
                        ]
                      : [],
                ),
                child: Builder(builder: (ctx) {
                  final loc = AppLocalizations.of(ctx);
                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(item.icon,
                          style: TextStyle(fontSize: iconSize)),
                      const SizedBox(width: 5),
                      Text(
                        item.localizedName(loc.locale.languageCode),
                        style: TextStyle(
                          fontSize: fontSize,
                          fontWeight: isSelected
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: isSelected ? Colors.white : unselText,
                        ),
                      ),
                      // SubItems бар болсо жебе
                      if (!isSubSub && item.hasSubItems) ...[
                        const SizedBox(width: 3),
                        Icon(
                          Icons.keyboard_arrow_down_rounded,
                          size: 14,
                          color: isSelected
                              ? Colors.white.withValues(alpha: 0.8)
                              : activeColor.withValues(alpha: 0.6),
                        ),
                      ],
                    ],
                  );
                }),
              ),
            );
          },
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
// Bottom Sheet — Категория тандоо
// ══════════════════════════════════════════════════════════
class _CategoryBottomSheet extends StatelessWidget {
  final List<CategoryModel> categories;
  final String? selectedId;
  final Function(CategoryModel) onSelected;

  const _CategoryBottomSheet({
    required this.categories,
    required this.selectedId,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final loc    = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final maxH   = MediaQuery.of(context).size.height * 0.85;
    final bgColor     = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final handleColor = isDark ? const Color(0xFF3A3A3A) : AppColors.grey300;
    final itemBg      = isDark ? const Color(0xFF2C2C2C) : const Color(0xFFF7F7F7);
    final textColor   = isDark ? Colors.white : AppColors.black;

    return Container(
      constraints: BoxConstraints(maxHeight: maxH),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: handleColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Text(
              loc.get('cat_select'),
              style: AppTextStyles.headingSmall.copyWith(color: textColor),
            ),
          ),
          Flexible(
            child: GridView.builder(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                mainAxisSpacing: 12,
                crossAxisSpacing: 10,
                childAspectRatio: 0.82,
              ),
              itemCount: categories.length,
              itemBuilder: (_, idx) {
                final cat = categories[idx];
                final color = Color(int.parse('0xFF${cat.color}'));
                final isSelected = selectedId == cat.id;

                return GestureDetector(
                  onTap: () => onSelected(cat),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? color.withValues(alpha: 0.15)
                          : itemBg,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected ? color : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            color: isSelected
                                ? color.withValues(alpha: 0.2)
                                : color.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(cat.icon,
                                style: const TextStyle(fontSize: 22)),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Text(
                            cat.localizedName(loc.locale.languageCode),
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: isSelected
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: isSelected ? color : textColor,
                              height: 1.2,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}