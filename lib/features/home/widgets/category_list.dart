import 'package:flutter/material.dart';
import '../../../config/theme/app_colors.dart';
import '../../../config/theme/app_text_styles.dart';
import '../../../core/app_localizations.dart';
import '../models/category_model.dart';
import 'dart:ui';

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
      barrierColor: Colors.black.withValues(alpha: 0.1),
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
    final inactiveBg    = isDark ? const Color(0xFF2C2C2C) : AppColors.grey100;
    final inactiveColor = isDark ? AppColors.grey400 : AppColors.grey600;

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
              _PillButton(
                icon: Icons.grid_view_rounded,
                emoji: cat?.icon,
                imageAsset: 'assets/icons/icon_category_3d.png',
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
              _PillButton(
                icon: Icons.fiber_new_rounded,
                imageAsset: 'assets/icons/icon_new_products_3d.png',
                label: loc.get('cat_newest'),
                isActive: _filterMode == ProductFilterMode.newest,
                activeColor: AppColors.primary,
                inactiveBg: inactiveBg,
                inactiveColor: inactiveColor,
                onTap: () => _setFilterMode(ProductFilterMode.newest),
              ),
              const SizedBox(width: 8),
              _PillButton(
                icon: Icons.trending_up_rounded,
                imageAsset: 'assets/icons/icon_popular_3d.png',
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
// Pill баскычы (1-деңгээл)
// ══════════════════════════════════════════════════════════
class _PillButton extends StatelessWidget {
  final IconData icon;
  final String? emoji;
  // 3D-стилдеги өзүнчө PNG иконка (берилсе, icon/emoji ордуна ушул көрсөтүлөт)
  final String? imageAsset;
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
    this.imageAsset,
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Нейтрал көгүш — бардык pill бирдей стилде
    const neutralBlue = Color(0xFF3B82F6);
    final activeBg     = neutralBlue.withOpacity(isDark ? 0.30 : 0.18);
    final activeBorder = neutralBlue.withOpacity(isDark ? 0.60 : 0.45);
    final inactiveBgC  = neutralBlue.withOpacity(isDark ? 0.08 : 0.06);
    final inactiveBorderC = neutralBlue.withOpacity(isDark ? 0.20 : 0.15);
    final activeTextC  = isDark ? Colors.white : const Color(0xFF1E3A5F);
    final inactiveTextC = isDark
        ? Colors.white.withOpacity(0.75)
        : const Color(0xFF1E3A5F).withOpacity(0.70);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 40,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: isActive ? activeBg : inactiveBgC,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: isActive ? activeBorder : inactiveBorderC,
            width: isActive ? 1.5 : 1.0,
          ),
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: neutralBlue.withOpacity(0.20),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  )
                ]
              : [],
        ),
        child: Stack(
          alignment: Alignment.centerLeft,
          clipBehavior: Clip.none,
          children: [
            // ── Сүрөт — баскычтын арткы фонунда чоң, жарым-өткөрүмдүү ──
            if (!(isActive && emoji != null) && imageAsset != null)
              Positioned(
                left: -6,
                top: -10,
                bottom: -10,
                child: Opacity(
                  opacity: isActive ? 0.55 : 0.40,
                  child: Image.asset(imageAsset!, fit: BoxFit.contain),
                ),
              ),
            Padding(
              padding: EdgeInsets.only(
                left: imageAsset != null && !(isActive && emoji != null)
                    ? 34
                    : 14,
                right: 14,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isActive && emoji != null)
                    Text(emoji!, style: const TextStyle(fontSize: 14))
                  else if (imageAsset == null)
                    Icon(icon,
                        size: 16,
                        color: isActive ? activeTextC : inactiveTextC),
                  if (isActive && emoji != null || imageAsset == null)
                    const SizedBox(width: 6),
                  Text(
                    label,
                    style: AppTextStyles.labelLarge.copyWith(
                      color: isActive ? activeTextC : inactiveTextC,
                      fontSize: 13,
                      fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                  if (showClose) ...[
                    const SizedBox(width: 4),
                    Icon(Icons.close_rounded,
                        size: 14,
                        color: activeTextC.withOpacity(0.8)),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
// Pill тизмеси (2 жана 3-деңгээл)
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

    // Нейтрал көгүш — ар башка категория түсү эмес, бирдей стил
    const neutralBlue = Color(0xFF3B82F6);
    final unselBg     = isDark
        ? neutralBlue.withValues(alpha: 0.08)
        : neutralBlue.withValues(alpha: 0.06);
    final unselBorder = neutralBlue.withValues(alpha: isDark ? 0.20 : 0.15);
    final unselText   = isDark
        ? Colors.white.withOpacity(0.75)
        : const Color(0xFF1E3A5F).withOpacity(0.70);

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
            final item       = items[i];
            final isSelected = selectedId == item.id;

            return GestureDetector(
              onTap: () => onTap(item),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: padding,
                decoration: BoxDecoration(
                  color: isSelected
                      ? neutralBlue.withValues(alpha: isDark ? 0.30 : 0.18)
                      : unselBg,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: isSelected
                        ? neutralBlue.withValues(alpha: isDark ? 0.60 : 0.45)
                        : unselBorder,
                    width: isSelected ? 1.5 : 1.0,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: neutralBlue.withValues(alpha: 0.20),
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
                      Text(item.icon, style: TextStyle(fontSize: iconSize)),
                      const SizedBox(width: 5),
                      Text(
                        item.localizedName(loc.locale.languageCode),
                        style: TextStyle(
                          fontSize: fontSize,
                          fontWeight:
                              isSelected ? FontWeight.w700 : FontWeight.w500,
                          color: isSelected
                              ? (isDark ? Colors.white : const Color(0xFF1E3A5F))
                              : unselText,
                        ),
                      ),
                      if (!isSubSub && item.hasSubItems) ...[
                        const SizedBox(width: 3),
                        Icon(
                          Icons.keyboard_arrow_down_rounded,
                          size: 14,
                          color: isSelected
                              ? (isDark
                                  ? Colors.white.withOpacity(0.8)
                                  : const Color(0xFF1E3A5F).withOpacity(0.8))
                              : neutralBlue.withValues(alpha: 0.50),
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
    final loc      = AppLocalizations.of(context);
    final isDark   = Theme.of(context).brightness == Brightness.dark;
    final maxH     = MediaQuery.of(context).size.height * 0.85;
    final bgColor  = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final handleColor = isDark ? const Color(0xFF3A3A3A) : AppColors.grey300;
    final textColor   = isDark ? Colors.white : AppColors.black;

    // ── Бардык item үчүн бирдей: өтө аз көгүш прозрачный фон ──
    // Тандалган: категориянын түсү, тандалбаган: жарым-өткөрүмдүү нейтрал
    const neutralBg      = Color(0xFF3B82F6); // нейтрал көгүш

    const borderAlpha    = 0.18;             // border жакшы көрүнсүн

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          constraints: BoxConstraints(maxHeight: maxH),
          decoration: BoxDecoration(
            color: bgColor.withValues(alpha: 0.70),
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
                    childAspectRatio: 0.75,
                  ),
                  itemCount: categories.length,
                  itemBuilder: (_, idx) {
                    final cat        = categories[idx];
                    final catColor   = Color(int.parse('0xFF${cat.color}'));
                    final isSelected = selectedId == cat.id;

                    return GestureDetector(
                      onTap: () => onSelected(cat),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isSelected
                                ? catColor.withValues(alpha: 0.85)
                                : neutralBg.withValues(alpha: borderAlpha),
                            width: isSelected ? 2.5 : 1.0,
                          ),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: catColor.withValues(alpha: 0.35),
                                    blurRadius: 12,
                                    offset: const Offset(0, 3),
                                  )
                                ]
                              : [],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: Column(
                            children: [
                              // ── Жогору: сүрөт толук ──
                              Expanded(
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    cat.imagePath != null
                                        ? Image.asset(
                                            cat.imagePath!,
                                            fit: BoxFit.cover,
                                            errorBuilder: (_, __, ___) =>
                                                _catFallback(catColor, cat.icon),
                                          )
                                        : _catFallback(catColor, cat.icon),
                                    if (isSelected)
                                      Container(
                                        color: catColor.withValues(alpha: 0.20),
                                      ),
                                  ],
                                ),
                              ),
                              // ── Ылдый: категория аты ──
                              Container(
                                width: double.infinity,
                                color: isDark
                                    ? const Color(0xFF1A1A2E)
                                    : const Color(0xFFF0F0F0),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 3, vertical: 5),
                                child: Text(
                                  cat.localizedName(loc.locale.languageCode),
                                  textAlign: TextAlign.center,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: isSelected
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                    color: isSelected
                                        ? catColor
                                        : (isDark ? Colors.white70 : Colors.black87),
                                    height: 1.2,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _catFallback(Color color, String icon) {
    return Container(
      width: double.infinity,
      height: 60,
      color: color.withValues(alpha: 0.12),
      child: Center(
        child: Text(icon, style: const TextStyle(fontSize: 26)),
      ),
    );
  }
}