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
        // Эгер эле тандалган болсо — баарын тазала
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
        // Эгер эле тандалган болсо — sub тазала, негизги категория калсын
        _selectedSubId = null;
        _selectedSubSubId = null;
        widget.onCategorySelected(_selectedCategoryId ?? '');
      } else {
        _selectedSubId = sub.id;
        _selectedSubSubId = null;
        // "Баары" болсо — негизги категория ID жибер
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
    final inactiveIcon = isDark ? AppColors.grey400 : AppColors.grey600;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── 1-ДЕҢГЭЭЛ: Негизги категория + Filter баскычтары ──
        SizedBox(
          height: 52,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Категория баскычы
                GestureDetector(
                  onTap: _openCategorySheet,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                    decoration: BoxDecoration(
                      color: _selectedCategoryId != null
                          ? AppColors.primary
                          : inactiveBg,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: _selectedCategoryId != null
                          ? [BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.35),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            )]
                          : [],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.grid_view_rounded,
                          size: 17,
                          color: _selectedCategoryId != null
                              ? Colors.white
                              : inactiveIcon,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _selectedCategoryId != null
                              ? (cat?.localizedName(loc.locale.languageCode) ??
                                  loc.get('cat_label'))
                              : loc.get('cat_label'),
                          style: AppTextStyles.labelLarge.copyWith(
                            color: _selectedCategoryId != null
                                ? Colors.white
                                : inactiveIcon,
                            fontSize: 13,
                          ),
                        ),
                        if (_selectedCategoryId != null) ...[
                          const SizedBox(width: 4),
                          Icon(Icons.close_rounded,
                              size: 15,
                              color: Colors.white.withValues(alpha: 0.8)),
                        ],
                      ],
                    ),
                  ),
                ),

                // Жаңы
                GestureDetector(
                  onTap: () => _setFilterMode(ProductFilterMode.newest),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                    decoration: BoxDecoration(
                      color: _filterMode == ProductFilterMode.newest
                          ? AppColors.primary
                          : inactiveBg,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: _filterMode == ProductFilterMode.newest
                          ? [BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.35),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            )]
                          : [],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.fiber_new_rounded,
                            size: 17,
                            color: _filterMode == ProductFilterMode.newest
                                ? Colors.white
                                : inactiveIcon),
                        const SizedBox(width: 5),
                        Text(
                          loc.get('cat_newest'),
                          style: AppTextStyles.labelLarge.copyWith(
                            color: _filterMode == ProductFilterMode.newest
                                ? Colors.white
                                : inactiveIcon,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Таанымал
                GestureDetector(
                  onTap: () => _setFilterMode(ProductFilterMode.popular),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                    decoration: BoxDecoration(
                      color: _filterMode == ProductFilterMode.popular
                          ? const Color(0xFFD97706)
                          : inactiveBg,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: _filterMode == ProductFilterMode.popular
                          ? [BoxShadow(
                              color: const Color(0xFFD97706).withValues(alpha: 0.35),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            )]
                          : [],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.trending_up_rounded,
                            size: 16,
                            color: _filterMode == ProductFilterMode.popular
                                ? Colors.white
                                : inactiveIcon),
                        const SizedBox(width: 5),
                        Text(
                          loc.get('cat_popular'),
                          style: AppTextStyles.labelLarge.copyWith(
                            color: _filterMode == ProductFilterMode.popular
                                ? Colors.white
                                : inactiveIcon,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // ── 2-ДЕҢГЭЭЛ: Subcategory тилкеси ──
        AnimatedSize(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          child: cat != null && cat.subcategories.isNotEmpty
              ? _SubCategoryBar(
                  category: cat,
                  selectedSubId: _selectedSubId,
                  onSubTap: _onSubCategoryTap,
                )
              : const SizedBox.shrink(),
        ),

        // ── 3-ДЕҢГЭЭЛ: SubSubCategory тилкеси (subItems болгондо гана) ──
        AnimatedSize(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          child: sub != null && sub.hasSubItems
              ? _SubSubCategoryBar(
                  parentSub: sub,
                  categoryColor: Color(int.parse('0xFF${cat!.color}')),
                  selectedSubSubId: _selectedSubSubId,
                  onSubSubTap: _onSubSubCategoryTap,
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════
// 2-ДЕҢГЭЭЛ — SubCategory тилкеси
// ══════════════════════════════════════════════════════════
class _SubCategoryBar extends StatelessWidget {
  final CategoryModel category;
  final String? selectedSubId;
  final Function(SubCategoryModel) onSubTap;

  const _SubCategoryBar({
    required this.category,
    required this.selectedSubId,
    required this.onSubTap,
  });

  @override
  Widget build(BuildContext context) {
    final color  = Color(int.parse('0xFF${category.color}'));
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      height: 48,
      margin: const EdgeInsets.only(top: 6),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: category.subcategories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final sub = category.subcategories[i];
          final isSelected = selectedSubId == sub.id ||
              (selectedSubId == null && sub.id.endsWith('_1'));
          final unselBg = isDark
              ? color.withValues(alpha: 0.15)
              : color.withValues(alpha: 0.08);

          return GestureDetector(
            onTap: () => onSubTap(sub),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? color : unselBg,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: isSelected ? color : color.withValues(alpha: 0.25),
                  width: 1.5,
                ),
                boxShadow: isSelected
                    ? [BoxShadow(
                        color: color.withValues(alpha: 0.3),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      )]
                    : [],
              ),
              child: Builder(builder: (ctx) {
                final loc = AppLocalizations.of(ctx);
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(sub.icon, style: const TextStyle(fontSize: 14)),
                    const SizedBox(width: 5),
                    Text(
                      sub.localizedName(loc.locale.languageCode),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight:
                            isSelected ? FontWeight.w700 : FontWeight.w500,
                        color: isSelected
                            ? Colors.white
                            : color.withValues(
                                alpha: isDark ? 1.0 : 0.85),
                      ),
                    ),
                    // subItems бар болсо жебе көрсөт
                    if (sub.hasSubItems) ...[
                      const SizedBox(width: 3),
                      Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: 14,
                        color: isSelected
                            ? Colors.white.withValues(alpha: 0.8)
                            : color.withValues(alpha: 0.6),
                      ),
                    ],
                  ],
                );
              }),
            ),
          );
        },
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
// 3-ДЕҢГЭЭЛ — SubSubCategory тилкеси
// ══════════════════════════════════════════════════════════
class _SubSubCategoryBar extends StatelessWidget {
  final SubCategoryModel parentSub;
  final Color categoryColor;
  final String? selectedSubSubId;
  final Function(SubCategoryModel) onSubSubTap;

  const _SubSubCategoryBar({
    required this.parentSub,
    required this.categoryColor,
    required this.selectedSubSubId,
    required this.onSubSubTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // 3-деңгээл үчүн бир аз башка түс (категория түсүнүн жеңилирээк варианты)
    final color = HSLColor.fromColor(categoryColor)
        .withLightness(
            (HSLColor.fromColor(categoryColor).lightness - 0.1).clamp(0.0, 1.0))
        .toColor();

    return Container(
      height: 44,
      margin: const EdgeInsets.only(top: 4),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: categoryColor.withValues(alpha: 0.15),
            width: 1,
          ),
        ),
      ),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: parentSub.subItems.length,
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemBuilder: (context, i) {
          final subSub = parentSub.subItems[i];
          final isSelected = selectedSubSubId == subSub.id;
          final unselBg = isDark
              ? color.withValues(alpha: 0.12)
              : color.withValues(alpha: 0.06);

          return GestureDetector(
            onTap: () => onSubSubTap(subSub),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: isSelected ? color : unselBg,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected
                      ? color
                      : color.withValues(alpha: 0.2),
                  width: 1,
                ),
                boxShadow: isSelected
                    ? [BoxShadow(
                        color: color.withValues(alpha: 0.25),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      )]
                    : [],
              ),
              child: Builder(builder: (ctx) {
                final loc = AppLocalizations.of(ctx);
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(subSub.icon,
                        style: const TextStyle(fontSize: 12)),
                    const SizedBox(width: 4),
                    Text(
                      subSub.localizedName(loc.locale.languageCode),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: isSelected
                            ? FontWeight.w600
                            : FontWeight.w400,
                        color: isSelected
                            ? Colors.white
                            : color.withValues(
                                alpha: isDark ? 0.9 : 0.8),
                      ),
                    ),
                  ],
                );
              }),
            ),
          );
        },
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
                          width: 46, height: 46,
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