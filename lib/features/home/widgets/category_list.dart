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
  String? _selectedSubItemId; // ← 3-деңгээл
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

  // Тандалган subcategory (subItems бар-жогун текшерүү үчүн)
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
        _selectedSubId      = null;
        _selectedSubItemId  = null;
        _filterMode = ProductFilterMode.all;
        widget.onFilterModeChanged?.call(ProductFilterMode.all);
        widget.onCategorySelected('');
      } else {
        _selectedCategoryId = cat.id;
        _selectedSubId      = null;
        _selectedSubItemId  = null;
        widget.onCategorySelected(cat.id);
      }
    });
  }

  void _onSubCategoryTap(SubCategoryModel sub) {
    setState(() {
      _selectedSubItemId = null; // 3-деңгээлди тазалайт
      if (_selectedSubId == sub.id) {
        _selectedSubId = null;
        widget.onCategorySelected(_selectedCategoryId ?? '');
      } else {
        _selectedSubId = sub.id;
        if (sub.id.endsWith('_1')) {
          widget.onCategorySelected(_selectedCategoryId ?? '');
        } else {
          widget.onCategorySelected(sub.id);
        }
      }
    });
  }

  void _onSubItemTap(SubCategoryModel subItem) {
    setState(() {
      if (_selectedSubItemId == subItem.id) {
        _selectedSubItemId = null;
        widget.onCategorySelected(_selectedSubId ?? _selectedCategoryId ?? '');
      } else {
        _selectedSubItemId = subItem.id;
        widget.onCategorySelected(subItem.id);
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
        // ── 1-сап: Категория / Жаңы / Таанымал ──────────────────────────
        SizedBox(
          height: 52,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onTap: _openCategorySheet,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                    decoration: BoxDecoration(
                      color: _selectedCategoryId != null ? AppColors.primary : inactiveBg,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: _selectedCategoryId != null
                          ? [BoxShadow(color: AppColors.primary.withValues(alpha: 0.35), blurRadius: 8, offset: const Offset(0, 3))]
                          : [],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.grid_view_rounded, size: 17,
                            color: _selectedCategoryId != null ? Colors.white : inactiveIcon),
                        const SizedBox(width: 6),
                        Text(
                          _selectedCategoryId != null
                              ? (cat?.localizedName(loc.locale.languageCode) ?? loc.get('cat_label'))
                              : loc.get('cat_label'),
                          style: AppTextStyles.labelLarge.copyWith(
                            color: _selectedCategoryId != null ? Colors.white : inactiveIcon,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(width: 3),
                        Icon(Icons.keyboard_arrow_down_rounded, size: 16,
                            color: _selectedCategoryId != null ? Colors.white : inactiveIcon),
                      ],
                    ),
                  ),
                ),

                GestureDetector(
                  onTap: () => _setFilterMode(ProductFilterMode.newest),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                    decoration: BoxDecoration(
                      color: _filterMode == ProductFilterMode.newest
                          ? const Color(0xFF16A34A) : inactiveBg,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: _filterMode == ProductFilterMode.newest
                          ? [BoxShadow(color: const Color(0xFF16A34A).withValues(alpha: 0.35), blurRadius: 8, offset: const Offset(0, 3))]
                          : [],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.fiber_new_rounded, size: 16,
                            color: _filterMode == ProductFilterMode.newest ? Colors.white : inactiveIcon),
                        const SizedBox(width: 5),
                        Text(loc.get('cat_newest'),
                            style: AppTextStyles.labelLarge.copyWith(
                              color: _filterMode == ProductFilterMode.newest ? Colors.white : inactiveIcon,
                              fontSize: 13,
                            )),
                      ],
                    ),
                  ),
                ),

                GestureDetector(
                  onTap: () => _setFilterMode(ProductFilterMode.popular),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                    decoration: BoxDecoration(
                      color: _filterMode == ProductFilterMode.popular
                          ? const Color(0xFFD97706) : inactiveBg,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: _filterMode == ProductFilterMode.popular
                          ? [BoxShadow(color: const Color(0xFFD97706).withValues(alpha: 0.35), blurRadius: 8, offset: const Offset(0, 3))]
                          : [],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.trending_up_rounded, size: 16,
                            color: _filterMode == ProductFilterMode.popular ? Colors.white : inactiveIcon),
                        const SizedBox(width: 5),
                        Text(loc.get('cat_popular'),
                            style: AppTextStyles.labelLarge.copyWith(
                              color: _filterMode == ProductFilterMode.popular ? Colors.white : inactiveIcon,
                              fontSize: 13,
                            )),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // ── 2-сап: SubCategory (Эркектер / Аялдар / Балдар ...) ──────────
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

        // ── 3-сап: SubItems (Жазкы / Жайкы / Күзгү ...) ─────────────────
        AnimatedSize(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          child: sub != null && sub.hasSubItems
              ? _SubItemBar(
                  subCategory: sub,
                  categoryColor: Color(int.parse('0xFF${cat!.color}')),
                  selectedSubItemId: _selectedSubItemId,
                  onSubItemTap: _onSubItemTap,
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }
}

// ── 2-деңгээл бар (SubCategoryBar) ──────────────────────────────────────────
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
          final sub        = category.subcategories[i];
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
                    ? [BoxShadow(color: color.withValues(alpha: 0.3), blurRadius: 6, offset: const Offset(0, 2))]
                    : [],
              ),
              child: Builder(builder: (context) {
                final loc = AppLocalizations.of(context);
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // subItems бар болсо жебе кошот
                    Text(sub.icon, style: const TextStyle(fontSize: 14)),
                    const SizedBox(width: 5),
                    Text(
                      sub.localizedName(loc.locale.languageCode),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                        color: isSelected
                            ? Colors.white
                            : color.withValues(alpha: isDark ? 1.0 : 0.85),
                      ),
                    ),
                    if (sub.hasSubItems) ...[
                      const SizedBox(width: 3),
                      Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: 14,
                        color: isSelected ? Colors.white : color.withValues(alpha: 0.7),
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

// ── 3-деңгээл бар (SubItemBar) ───────────────────────────────────────────────
class _SubItemBar extends StatelessWidget {
  final SubCategoryModel subCategory;
  final Color categoryColor;
  final String? selectedSubItemId;
  final Function(SubCategoryModel) onSubItemTap;

  const _SubItemBar({
    required this.subCategory,
    required this.categoryColor,
    required this.selectedSubItemId,
    required this.onSubItemTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // 3-деңгээл бир аз ачыкыраак түс менен айырмаланат
    final color = HSLColor.fromColor(categoryColor)
        .withLightness((HSLColor.fromColor(categoryColor).lightness + 0.1).clamp(0.0, 1.0))
        .toColor();

    return Container(
      height: 44,
      margin: const EdgeInsets.only(top: 4),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: isDark ? const Color(0xFF2C2C2C) : AppColors.grey200,
            width: 1,
          ),
        ),
      ),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        itemCount: subCategory.subItems.length,
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemBuilder: (context, i) {
          final item       = subCategory.subItems[i];
          final isSelected = selectedSubItemId == item.id;
          final unselBg    = isDark
              ? color.withValues(alpha: 0.12)
              : color.withValues(alpha: 0.07);

          return GestureDetector(
            onTap: () => onSubItemTap(item),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: isSelected ? color : unselBg,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected ? color : color.withValues(alpha: 0.2),
                  width: 1.5,
                ),
              ),
              child: Builder(builder: (context) {
                final loc = AppLocalizations.of(context);
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(item.icon, style: const TextStyle(fontSize: 12)),
                    const SizedBox(width: 4),
                    Text(
                      item.localizedName(loc.locale.languageCode),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                        color: isSelected
                            ? Colors.white
                            : color.withValues(alpha: isDark ? 1.0 : 0.8),
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

// ── Bottom Sheet ─────────────────────────────────────────────────────────────
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
    final loc         = AppLocalizations.of(context);
    final isDark      = Theme.of(context).brightness == Brightness.dark;
    final maxH        = MediaQuery.of(context).size.height * 0.85;
    final bgColor     = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final handleColor = isDark ? const Color(0xFF3A3A3A) : AppColors.grey300;
    final itemBg      = isDark ? const Color(0xFF2C2C2C) : const Color(0xFFF7F7F7);
    final textColor   = isDark ? AppColors.grey400 : AppColors.grey600;

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxH),
      child: Container(
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(color: handleColor, borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(loc.get('cat_select'), style: AppTextStyles.headingSmall),
              ),
            ),
            const SizedBox(height: 12),
            Flexible(
              child: GridView.builder(
                shrinkWrap: true,
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  childAspectRatio: 0.82,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemCount: categories.length,
                itemBuilder: (context, index) {
                  final cat        = categories[index];
                  final isSelected = selectedId == cat.id;
                  final color      = Color(int.parse('0xFF${cat.color}'));

                  return GestureDetector(
                    onTap: () => onSelected(cat),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      decoration: BoxDecoration(
                        color: isSelected ? color.withValues(alpha: 0.15) : itemBg,
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
                              child: Text(cat.icon, style: const TextStyle(fontSize: 22)),
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
                                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
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
      ),
    );
  }
}