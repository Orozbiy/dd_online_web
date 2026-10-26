import 'package:flutter/material.dart';
import '../../../config/theme/dd_design.dart';

// ═════════════════════════════════════════════════════════════
// DD Online — Figma стилиндеги 4 экрандын UI катмары
// (Чат тизмеси · Дүкөндөр · Тандамалар · Жөндөөлөр)
// Жарык жана караңгы режимде өзүнчө дизайн (DDPalette).
// Бул виджеттер маалыматты параметр катары алат — өзүңүздүн
// Supabase/сервис логикаңызды ушуларга туташтырасыз.
// ═════════════════════════════════════════════════════════════

/// Бирдей экран каркасы: фон + аталыш (+ оң жактагы виджет)
class DDScreen extends StatelessWidget {
  final String title;
  final Widget? trailing;
  final Widget? bottom; // аталыштын астындагы (издөө, tab ж.б.)
  final Widget child;
  const DDScreen({
    super.key,
    required this.title,
    required this.child,
    this.trailing,
    this.bottom,
  });

  @override
  Widget build(BuildContext context) {
    final p = DDPalette.of(context);
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: DDBackground(
        child: SafeArea(
          bottom: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 16, 12),
                child: Row(children: [
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        color: p.text,
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -1,
                      ),
                    ),
                  ),
                  if (trailing != null) trailing!,
                ]),
              ),
              if (bottom != null) bottom!,
              Expanded(child: child),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Жалпы: сан белгиси (мис. "12 дүкөн") ──
class DDCountBadge extends StatelessWidget {
  final String text;
  const DDCountBadge(this.text, {super.key});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: DD.accent.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(DD.rPill),
          border: Border.all(color: DD.accent.withValues(alpha: 0.35)),
        ),
        child: Text(text,
            style: const TextStyle(
                color: DD.accent, fontSize: 12, fontWeight: FontWeight.w800)),
      );
}

// ── Жалпы: издөө талаасы ──
class DDSearchField extends StatelessWidget {
  final String hint;
  final ValueChanged<String>? onChanged;
  const DDSearchField({super.key, required this.hint, this.onChanged});

  @override
  Widget build(BuildContext context) {
    final p = DDPalette.of(context);
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: p.card,
        borderRadius: BorderRadius.circular(DD.rPill),
        border: Border.all(color: p.divider),
        boxShadow: p.isDark
            ? null
            : [
                BoxShadow(
                  color: DD.ink.withValues(alpha: 0.06),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                  spreadRadius: -4,
                ),
              ],
      ),
      child: Row(children: [
        Icon(Icons.search_rounded, color: p.subText, size: 22),
        const SizedBox(width: 10),
        Expanded(
          child: TextField(
            onChanged: onChanged,
            style: TextStyle(color: p.text, fontSize: 15),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(color: p.subText, fontSize: 15),
              border: InputBorder.none,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 15),
            ),
          ),
        ),
      ]),
    );
  }
}

// ═════════════════════════════════════════════════════════════
// 1) ЧАТ ТИЗМЕСИ ("Билдирүүлөр")
// ═════════════════════════════════════════════════════════════
class DDChatItem {
  final String title; // дүкөн / сатуучу аты
  final String product; // товар аты
  final String lastMessage; // акыркы билдирүү (бош болушу мүмкүн)
  final String time; // "23:10"
  final int unread;
  const DDChatItem({
    required this.title,
    required this.product,
    required this.time,
    this.lastMessage = '',
    this.unread = 0,
  });
}

class DDChatListView extends StatelessWidget {
  final String title;
  final List<DDChatItem> items;
  final ValueChanged<int> onTap;
  final Widget? emptyState;
  const DDChatListView({
    super.key,
    required this.items,
    required this.onTap,
    this.title = 'Билдирүүлөр',
    this.emptyState,
  });

  @override
  Widget build(BuildContext context) {
    final p = DDPalette.of(context);
    return DDScreen(
      title: title,
      trailing: items.isEmpty ? null : DDCountBadge('${items.length}'),
      child: items.isEmpty
          ? (emptyState ??
              Center(
                  child: Icon(Icons.chat_bubble_outline_rounded,
                      size: 64, color: p.subText.withValues(alpha: 0.5))))
          : ListView.builder(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.only(top: 4, bottom: 110),
              itemCount: items.length,
              itemBuilder: (_, i) => _ChatTile(
                item: items[i],
                onTap: () => onTap(i),
              ),
            ),
    );
  }
}

class _ChatTile extends StatelessWidget {
  final DDChatItem item;
  final VoidCallback onTap;
  const _ChatTile({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = DDPalette.of(context);
    final letter =
        item.title.trim().isEmpty ? '?' : item.title.trim()[0].toUpperCase();
    return DDCard(
      onTap: onTap,
      padding: const EdgeInsets.all(12),
      child: Row(children: [
        Container(
          width: 52,
          height: 52,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: DD.accentGradient,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Text(letter,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w800)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(item.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color: p.text,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.3)),
              const SizedBox(height: 4),
              Row(children: [
                const Icon(Icons.inventory_2_rounded,
                    size: 13, color: DD.accent),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(item.product,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: p.subText,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600)),
                ),
              ]),
              if (item.lastMessage.isNotEmpty) ...[
                const SizedBox(height: 3),
                Text(item.lastMessage,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: p.subText, fontSize: 13)),
              ],
            ],
          ),
        ),
        const SizedBox(width: 8),
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(item.time,
                style: TextStyle(
                    color: item.unread > 0 ? DD.accent : p.subText,
                    fontSize: 12,
                    fontWeight: FontWeight.w700)),
            if (item.unread > 0) ...[
              const SizedBox(height: 6),
              Container(
                constraints: const BoxConstraints(minWidth: 20),
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  gradient: DD.accentGradient,
                  borderRadius: BorderRadius.circular(DD.rPill),
                ),
                child: Text('${item.unread}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w800)),
              ),
            ],
          ],
        ),
      ]),
    );
  }
}

// ═════════════════════════════════════════════════════════════
// 2) ДҮКӨНДӨР ТИЗМЕСИ
// ═════════════════════════════════════════════════════════════
class DDShopItem {
  final String name; // "13 катар, 1236 контейнер"
  final String location; // тексти
  final bool hasLocation; // картадагы жери белгилүүбү
  const DDShopItem({
    required this.name,
    required this.location,
    this.hasLocation = false,
  });
}

class DDShopsListView extends StatelessWidget {
  final List<DDShopItem> shops;
  final ValueChanged<int> onTap;
  final ValueChanged<int>? onLocate;
  final ValueChanged<String>? onSearch;
  final String title;
  final String searchHint;
  final String countLabel; // "12 дүкөн"
  final bool showHeader; // Тандамалар ичинде көрсөтпөө үчүн false
  const DDShopsListView({
    super.key,
    required this.shops,
    required this.onTap,
    this.onLocate,
    this.onSearch,
    this.title = 'Дүкөндөр',
    this.searchHint = 'Дүкөн же контейнер издөө...',
    this.countLabel = '',
    this.showHeader = true,
  });

  Widget _list(BuildContext context) {
    final p = DDPalette.of(context);
    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.only(top: 4, bottom: 110),
      itemCount: shops.length,
      itemBuilder: (_, i) {
        final s = shops[i];
        final letter =
            s.name.trim().isEmpty ? '?' : s.name.trim()[0].toUpperCase();
        return DDCard(
          onTap: () => onTap(i),
          padding: const EdgeInsets.all(12),
          child: Row(children: [
            Container(
              width: 52,
              height: 52,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient: DD.accentGradient,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: DD.accent.withValues(alpha: 0.30),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Text(letter,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w800)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(s.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: p.text,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.3)),
                  const SizedBox(height: 4),
                  Row(children: [
                    Icon(Icons.location_on_rounded,
                        size: 13,
                        color: s.hasLocation ? DD.accent : p.subText),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(s.location,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              color: p.subText,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600)),
                    ),
                  ]),
                ],
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: onLocate == null ? null : () => onLocate!(i),
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: s.hasLocation
                      ? DD.accent.withValues(alpha: 0.12)
                      : p.chip,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: s.hasLocation
                          ? DD.accent.withValues(alpha: 0.4)
                          : p.chipBorder),
                ),
                child: Icon(Icons.near_me_rounded,
                    size: 20, color: s.hasLocation ? DD.accent : p.subText),
              ),
            ),
          ]),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!showHeader) {
      return Column(children: [
        DDSearchField(hint: searchHint, onChanged: onSearch),
        Expanded(child: _list(context)),
      ]);
    }
    return DDScreen(
      title: title,
      trailing: countLabel.isEmpty ? null : DDCountBadge(countLabel),
      bottom: DDSearchField(hint: searchHint, onChanged: onSearch),
      child: _list(context),
    );
  }
}

// ═════════════════════════════════════════════════════════════
// 3) ТАНДАМАЛАР (Товарлар | Дүкөндөр tab'дары)
// ═════════════════════════════════════════════════════════════
class DDFavoritesView extends StatefulWidget {
  final Widget productsTab; // өзүңүздүн жактырылган товарлар виджети
  final Widget shopsTab; // өзүңүздүн жактырылган дүкөндөр виджети
  final String title;
  final String productsLabel;
  final String shopsLabel;
  const DDFavoritesView({
    super.key,
    required this.productsTab,
    required this.shopsTab,
    this.title = 'Тандамалар',
    this.productsLabel = 'Товарлар',
    this.shopsLabel = 'Дүкөндөр',
  });

  @override
  State<DDFavoritesView> createState() => _DDFavoritesViewState();
}

class _DDFavoritesViewState extends State<DDFavoritesView> {
  int _tab = 0;

  Widget _seg(String label, IconData icon, int i) {
    final p = DDPalette.of(context);
    final sel = _tab == i;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _tab = i),
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: sel ? DD.accentGradient : null,
            borderRadius: BorderRadius.circular(DD.rPill),
            boxShadow: sel
                ? [
                    BoxShadow(
                      color: DD.accent.withValues(alpha: 0.35),
                      blurRadius: 14,
                      offset: const Offset(0, 5),
                      spreadRadius: -4,
                    ),
                  ]
                : null,
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 18, color: sel ? Colors.white : p.subText),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(
                    color: sel ? Colors.white : p.subText,
                    fontSize: 14,
                    fontWeight: FontWeight.w800)),
          ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = DDPalette.of(context);
    return DDScreen(
      title: widget.title,
      bottom: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: p.card,
          borderRadius: BorderRadius.circular(DD.rPill),
          border: Border.all(color: p.divider),
        ),
        child: Row(children: [
          _seg(widget.productsLabel, Icons.favorite_rounded, 0),
          _seg(widget.shopsLabel, Icons.storefront_rounded, 1),
        ]),
      ),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        child: KeyedSubtree(
          key: ValueKey(_tab),
          child: _tab == 0 ? widget.productsTab : widget.shopsTab,
        ),
      ),
    );
  }
}

/// Тандамалар бош болгондо көрсөтүлөт
class DDEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  const DDEmptyState({
    super.key,
    this.icon = Icons.favorite_border_rounded,
    this.title = 'Тандамалар бош',
    this.subtitle = 'Жаккан товарларды ❤ басып кошуңуз',
  });

  @override
  Widget build(BuildContext context) {
    final p = DDPalette.of(context);
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 96,
          height: 96,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: DD.accent.withValues(alpha: 0.10),
            border: Border.all(color: DD.accent.withValues(alpha: 0.30)),
          ),
          child: Icon(icon, size: 46, color: DD.accent),
        ),
        const SizedBox(height: 18),
        Text(title,
            style: TextStyle(
                color: p.text,
                fontSize: 18,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.4)),
        const SizedBox(height: 6),
        Text(subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(color: p.subText, fontSize: 14)),
      ]),
    );
  }
}

// ═════════════════════════════════════════════════════════════
// 4) ЖӨНДӨӨЛӨР
// ═════════════════════════════════════════════════════════════
class DDSettingsView extends StatelessWidget {
  final String languageCode; // 'ky' | 'ru'
  final ValueChanged<String> onLanguage;
  final bool notificationsOn;
  final ValueChanged<bool> onNotifications;
  final String themeLabel; // "Ак" | "Кара" | "Системалык"
  final VoidCallback onTheme;
  final String chatBgLabel; // "Классикалык"
  final VoidCallback onChatBg;
  final String cacheLabel; // "v20.04" же кэш өлчөмү
  final VoidCallback onClearCache;
  final VoidCallback onFeedback;
  final VoidCallback onProfile;
  final String profileTitle;
  final String profileSubtitle;
  final List<Widget> extraRows; // кошумча сап (Коддор, Жөнүндө ж.б.)

  const DDSettingsView({
    super.key,
    required this.languageCode,
    required this.onLanguage,
    required this.notificationsOn,
    required this.onNotifications,
    required this.themeLabel,
    required this.onTheme,
    required this.chatBgLabel,
    required this.onChatBg,
    required this.cacheLabel,
    required this.onClearCache,
    required this.onFeedback,
    required this.onProfile,
    this.profileTitle = 'Профиль',
    this.profileSubtitle = 'Түзөтүү',
    this.extraRows = const [],
  });

  @override
  Widget build(BuildContext context) {
    final p = DDPalette.of(context);
    return DDScreen(
      title: 'Жөндөөлөр',
      child: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 120),
        children: [
          // ── Логотип ──
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(children: [
              const DDIconBadge(Icons.storefront_rounded, size: 76),
              const SizedBox(height: 10),
              ShaderMask(
                shaderCallback: (b) => DD.accentGradient.createShader(b),
                child: const Text('DD Online',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.8)),
              ),
            ]),
          ),

          // ── Профиль ──
          DDCard(
            onTap: onProfile,
            child: Row(children: [
              const DDIconBadge(Icons.person_rounded, size: 46),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(profileTitle,
                        style: TextStyle(
                            color: p.text,
                            fontSize: 16,
                            fontWeight: FontWeight.w800)),
                    Text(profileSubtitle,
                        style: TextStyle(color: p.subText, fontSize: 12.5)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: p.subText),
            ]),
          ),

          // ── Тил ──
          DDCard(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: Row(children: [
                  const Icon(Icons.language_rounded,
                      color: DD.accent, size: 20),
                  const SizedBox(width: 10),
                  Text('Тил / Язык',
                      style: TextStyle(
                          color: p.text,
                          fontSize: 16,
                          fontWeight: FontWeight.w800)),
                ]),
              ),
              _langRow(context, '🇰🇬', 'Кыргызча', 'ky'),
              Divider(height: 1, indent: 16, endIndent: 16, color: p.divider),
              _langRow(context, '🇷🇺', 'Орусча', 'ru'),
            ]),
          ),

          // ── Негизги жөндөөлөр ──
          DDCard(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(children: [
              _switchRow(context, Icons.notifications_none_rounded,
                  'Билдирмелер', notificationsOn, onNotifications),
              _divider(p),
              _row(context, Icons.contrast_rounded, 'Режим',
                  trailingText: themeLabel, onTap: onTheme),
              _divider(p),
              _row(context, Icons.wallpaper_rounded, 'Чат фону',
                  subtitle: chatBgLabel, onTap: onChatBg),
              _divider(p),
              _row(context, Icons.cleaning_services_rounded, 'Кэшти тазалоо',
                  trailingText: cacheLabel, onTap: onClearCache),
              _divider(p),
              _row(context, Icons.chat_bubble_outline_rounded, 'Чалуу суроо',
                  subtitle: 'Тиркемеге жаңы сунуштар кошуу',
                  onTap: onFeedback),
              ...extraRows,
            ]),
          ),
        ],
      ),
    );
  }

  Widget _divider(DDPalette p) =>
      Divider(height: 1, indent: 60, endIndent: 16, color: p.divider);

  Widget _langRow(BuildContext context, String flag, String name, String code) {
    final p = DDPalette.of(context);
    final sel = languageCode == code;
    return InkWell(
      onTap: () => onLanguage(code),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(children: [
          Text(flag, style: const TextStyle(fontSize: 24)),
          const SizedBox(width: 14),
          Expanded(
            child: Text(name,
                style: TextStyle(
                    color: p.text,
                    fontSize: 15,
                    fontWeight: sel ? FontWeight.w800 : FontWeight.w600)),
          ),
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: sel ? DD.accentGradient : null,
              border: sel ? null : Border.all(color: p.chipBorder, width: 2),
            ),
            child: sel
                ? const Icon(Icons.check_rounded, color: Colors.white, size: 16)
                : null,
          ),
        ]),
      ),
    );
  }

  Widget _switchRow(BuildContext context, IconData icon, String label,
      bool value, ValueChanged<bool> onChanged) {
    final p = DDPalette.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(children: [
        Icon(icon, color: DD.accent, size: 22),
        const SizedBox(width: 14),
        Expanded(
          child: Text(label,
              style: TextStyle(
                  color: p.text, fontSize: 15, fontWeight: FontWeight.w700)),
        ),
        Switch(
          value: value,
          onChanged: onChanged,
          activeColor: Colors.white,
          activeTrackColor: DD.accent,
        ),
      ]),
    );
  }

  Widget _row(BuildContext context, IconData icon, String label,
      {String? subtitle, String? trailingText, required VoidCallback onTap}) {
    final p = DDPalette.of(context);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(children: [
          Icon(icon, color: DD.accent, size: 22),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(
                        color: p.text,
                        fontSize: 15,
                        fontWeight: FontWeight.w700)),
                if (subtitle != null)
                  Text(subtitle,
                      style: TextStyle(color: p.subText, fontSize: 12.5)),
              ],
            ),
          ),
          if (trailingText != null)
            Text(trailingText,
                style: const TextStyle(
                    color: DD.accent,
                    fontSize: 13,
                    fontWeight: FontWeight.w800)),
          const SizedBox(width: 4),
          Icon(Icons.chevron_right_rounded, color: p.subText, size: 22),
        ]),
      ),
    );
  }
}
