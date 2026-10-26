// ignore_for_file: unnecessary_import

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import '../../../config/theme/dd_design.dart';
import '../../../core/app_localizations.dart';
import '../widgets/fav_badge.dart';

const int tabHome      = 0;
const int tabChat      = 1;
const int tabMap       = 2;
const int tabFavorites = 3;
const int tabSettings  = 4;
const int _tabCount    = 5;

/// Төмөнкү 5 баскыч — Figma стили: сүзүп жүрүүчү айнек панель.
///
/// ✦ Бардык 5 баскыч бирдей кендикте, бирдей аралыкта.
/// ✦ Жөнөкөй басуу — дароо тандалат.
/// ✦ 0.3 секунд кармап туруп, манжаны ошол эле тилкедеги башка
///   баскычтарга жылдырсаң — манжа үстүндө турган баскыч
///   дароо активдүү болуп тандала берет (Telegram/iOS-стилиндей
///   "кармап-сүрүп тандоо").
/// ✦ Активдүү баскыч кызгылт сары градиент пилюля.
/// ✦ Жарык/караңгы режимде өзүнчө көрүнөт (DDPalette).
class HomeBottomNav extends StatefulWidget {
  final int currentTab;
  final bool isVisible;
  final int totalUnreadChat;
  final int favCount;
  final double bottomPadding;
  final ValueChanged<int> onTabSelected;

  const HomeBottomNav({
    super.key,
    required this.currentTab,
    required this.isVisible,
    required this.totalUnreadChat,
    required this.favCount,
    required this.bottomPadding,
    required this.onTabSelected,
  });

  static const double navHeight = 68.0;

  @override
  State<HomeBottomNav> createState() => _HomeBottomNavState();
}

class _HomeBottomNavState extends State<HomeBottomNav> {
  // ── Учурда манжа/басуу астында турган индекс (визуалдык гана) ──
  int? _touchedIndex;

  int _indexAtDx(double dx, double totalWidth) {
    if (totalWidth <= 0) return widget.currentTab;
    final segment = totalWidth / _tabCount;
    final idx = (dx / segment).floor();
    return idx.clamp(0, _tabCount - 1);
  }

  void _selectFromDx(double dx, double totalWidth, {bool haptic = true}) {
    final idx = _indexAtDx(dx, totalWidth);
    final changed = _touchedIndex != idx;
    setState(() {
      _touchedIndex = idx;
    });
    if (changed) {
      if (haptic) HapticFeedback.selectionClick();
      if (widget.currentTab != idx) widget.onTabSelected(idx);
    }
  }

  void _endTouch() {
    if (_touchedIndex != null) {
      setState(() {
        _touchedIndex = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final p = DDPalette.of(context);

    return AnimatedPositioned(
      duration: widget.isVisible
          ? const Duration(milliseconds: 300)
          : const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      left: 0,
      right: 0,
      bottom: widget.isVisible
          ? 0
          : -(HomeBottomNav.navHeight + widget.bottomPadding),
      child: Padding(
        padding: EdgeInsets.fromLTRB(14, 0, 14, widget.bottomPadding),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
            child: Container(
              decoration: BoxDecoration(
                color: p.isDark
                    ? const Color(0xFF15120F).withValues(alpha: 0.80)
                    : Colors.white.withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: p.isDark
                      ? DD.accent2.withValues(alpha: 0.22)
                      : Colors.white,
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: p.isDark
                        ? DD.accent.withValues(alpha: 0.16)
                        : DD.ink.withValues(alpha: 0.10),
                    blurRadius: 22,
                    offset: const Offset(0, 8),
                    spreadRadius: -6,
                  ),
                ],
              ),
              child: SizedBox(
                height: HomeBottomNav.navHeight,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final totalWidth = constraints.maxWidth;

                    return RawGestureDetector(
                      behavior: HitTestBehavior.opaque,
                      gestures: {
                        // ── Жөнөкөй тийүү/басуу: дароо тандайт ──
                        TapGestureRecognizer:
                            GestureRecognizerFactoryWithHandlers<
                                TapGestureRecognizer>(
                          () => TapGestureRecognizer(),
                          (TapGestureRecognizer instance) {
                            instance.onTapDown = (d) {
                              _selectFromDx(
                                  d.localPosition.dx, totalWidth,
                                  haptic: true);
                            };
                            instance.onTapUp = (_) {
                              _endTouch();
                            };
                            instance.onTapCancel = _endTouch;
                          },
                        ),
                        // ── 0.3 сек кармап туруп сүрүп тандоо ──
                        LongPressGestureRecognizer:
                            GestureRecognizerFactoryWithHandlers<
                                LongPressGestureRecognizer>(
                          () => LongPressGestureRecognizer(
                            duration: const Duration(milliseconds: 20),
                          ),
                          (LongPressGestureRecognizer instance) {
                            instance.onLongPressStart = (d) {
                              HapticFeedback.mediumImpact();
                              _selectFromDx(
                                  d.localPosition.dx, totalWidth,
                                  haptic: false);
                            };
                            instance.onLongPressMoveUpdate = (d) {
                              _selectFromDx(d.localPosition.dx, totalWidth);
                            };
                            instance.onLongPressEnd = (_) {
                              _endTouch();
                            };
                            instance.onLongPressCancel = _endTouch;
                          },
                        ),
                      },
                      child: Row(
                        children: [
                          _NavButton(
                            icon: Icon(
                              widget.currentTab == tabHome
                                  ? Icons.home_rounded
                                  : Icons.home_outlined,
                              size: 23,
                              color: widget.currentTab == tabHome
                                  ? Colors.white
                                  : p.subText,
                            ),
                            label: loc.get('home'),
                            isActive: widget.currentTab == tabHome,
                            isTouched: _touchedIndex == tabHome,
                            palette: p,
                          ),
                          _NavButton(
                            icon: _ChatBadgeIcon(
                              unreadCount: widget.totalUnreadChat,
                              isActive: widget.currentTab == tabChat,
                              palette: p,
                            ),
                            label: loc.get('chat'),
                            isActive: widget.currentTab == tabChat,
                            isTouched: _touchedIndex == tabChat,
                            palette: p,
                          ),
                          _NavButton(
                            icon: Icon(
                              widget.currentTab == tabMap
                                  ? Icons.storefront_rounded
                                  : Icons.storefront_outlined,
                              size: 23,
                              color: widget.currentTab == tabMap
                                  ? Colors.white
                                  : p.subText,
                            ),
                            label: loc.get('map_title'),
                            isActive: widget.currentTab == tabMap,
                            isTouched: _touchedIndex == tabMap,
                            palette: p,
                          ),
                          _NavButton(
                            icon: FavBadge(
                              count: widget.favCount,
                              active: widget.currentTab == tabFavorites,
                            ),
                            label: loc.get('favorites'),
                            isActive: widget.currentTab == tabFavorites,
                            isTouched: _touchedIndex == tabFavorites,
                            palette: p,
                          ),
                          _NavButton(
                            icon: Icon(
                              widget.currentTab == tabSettings
                                  ? Icons.settings_rounded
                                  : Icons.settings_outlined,
                              size: 23,
                              color: widget.currentTab == tabSettings
                                  ? Colors.white
                                  : p.subText,
                            ),
                            label: loc.get('settings'),
                            isActive: widget.currentTab == tabSettings,
                            isTouched: _touchedIndex == tabSettings,
                            palette: p,
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════
// БИРДИКТЕЙ БАСКЫЧ — таза көрсөтмө гана (gesture жогорудан
// RawGestureDetector аркылуу башкарылат). Ар бири бирдей
// Expanded flex=1 менен бирдей кендикте.
// ══════════════════════════════════════════════════════
class _NavButton extends StatelessWidget {
  final Widget icon;
  final String label;
  final bool isActive;
  final bool isTouched;
  final DDPalette palette;

  const _NavButton({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.isTouched,
    required this.palette,
  });

  @override
  Widget build(BuildContext context) {
    final p = palette;

    return Expanded(
      child: IgnorePointer(
        // ── gesture жогорку RawGestureDetector аркылуу иштейт,
        // ошондуктан бул блок өзү тийүүгө жооп бербейт ──
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Center(
            child: AnimatedScale(
              scale: isTouched ? 0.88 : 1.0,
              duration: const Duration(milliseconds: 140),
              curve: Curves.easeOutCubic,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 240),
                curve: Curves.easeOutCubic,
                width: double.infinity,
                padding: EdgeInsets.symmetric(
                  horizontal: isActive ? 10 : 4,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  gradient: isActive ? DD.accentGradient : null,
                  color: !isActive && isTouched
                      ? (p.isDark
                          ? Colors.white.withValues(alpha: 0.06)
                          : Colors.black.withValues(alpha: 0.05))
                      : null,
                  borderRadius: BorderRadius.circular(DD.rPill),
                  boxShadow: isActive
                      ? [
                          BoxShadow(
                            color: DD.accent.withValues(alpha: 0.40),
                            blurRadius: 14,
                            offset: const Offset(0, 5),
                            spreadRadius: -4,
                          ),
                        ]
                      : null,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    icon,
                    const SizedBox(height: 3),
                    AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 200),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight:
                            isActive ? FontWeight.w800 : FontWeight.w600,
                        color: isActive ? Colors.white : p.subText,
                      ),
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.clip,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════
// Чат иконкасы + окулбаган санагыч
// ══════════════════════════════════════════════════════
class _ChatBadgeIcon extends StatelessWidget {
  final int unreadCount;
  final bool isActive;
  final DDPalette palette;

  const _ChatBadgeIcon({
    required this.unreadCount,
    required this.isActive,
    required this.palette,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Icon(
          isActive
              ? Icons.chat_bubble_rounded
              : Icons.chat_bubble_outline_rounded,
          size: 23,
          color: isActive ? Colors.white : palette.subText,
        ),
        if (unreadCount > 0)
          Positioned(
            top: -6,
            right: -8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
              decoration: BoxDecoration(
                color: isActive ? Colors.white : DD.accent,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: palette.isDark
                      ? const Color(0xFF15120F)
                      : Colors.white,
                  width: 1.5,
                ),
              ),
              child: Text(
                unreadCount > 99 ? '99+' : '$unreadCount',
                style: TextStyle(
                  color: isActive ? DD.accent : Colors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  height: 1.2,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }
}