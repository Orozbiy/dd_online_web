// lib/features/seller/screens/seller_rules_screen.dart

import 'package:flutter/material.dart';
import '../../../core/app_localizations.dart';

class SellerRulesScreen extends StatelessWidget {
  const SellerRulesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final loc        = AppLocalizations.of(context);
    final isDark     = Theme.of(context).brightness == Brightness.dark;
    final bgColor    = isDark ? const Color(0xFF121212) : const Color(0xFFF4F5F7);
    final cardBg     = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final titleColor = isDark ? Colors.white : Colors.black;
    final bodyColor  = isDark ? Colors.white : Colors.black;

    final rules = [
      _Rule(number: '1', emoji: '🔐', tag: loc.get('rules_1_tag'), title: loc.get('rules_1_title'), desc: loc.get('rules_1_desc'), tip: loc.get('rules_1_tip'), accentColor: const Color(0xFFD97706)),
      _Rule(number: '2', emoji: '🤝', tag: loc.get('rules_2_tag'), title: loc.get('rules_2_title'), desc: loc.get('rules_2_desc'), tip: loc.get('rules_2_tip'), accentColor: const Color(0xFF22C55E)),
      _Rule(number: '3', emoji: '📲', tag: loc.get('rules_3_tag'), title: loc.get('rules_3_title'), desc: loc.get('rules_3_desc'), tip: loc.get('rules_3_tip'), accentColor: const Color(0xFF3B82F6)),
      _Rule(number: '4', emoji: '📸', tag: loc.get('rules_4_tag'), title: loc.get('rules_4_title'), desc: loc.get('rules_4_desc'), tip: loc.get('rules_4_tip'), accentColor: const Color(0xFFF59E0B)),
      _Rule(number: '5', emoji: '📝', tag: loc.get('rules_5_tag'), title: loc.get('rules_5_title'), desc: loc.get('rules_5_desc'), tip: loc.get('rules_5_tip'), accentColor: const Color(0xFF8B5CF6)),
      _Rule(number: '6', emoji: '⚡', tag: loc.get('rules_6_tag'), title: loc.get('rules_6_title'), desc: loc.get('rules_6_desc'), tip: loc.get('rules_6_tip'), accentColor: const Color(0xFFEF4444)),
    ];

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Icon(Icons.arrow_back, color: titleColor),
        ),
        title: Text(
          loc.get('rules_screen_title'),
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: titleColor),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        children: [
          // ── Башкы баннер ──
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFFD97706),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('🏆', style: TextStyle(fontSize: 34)),
                const SizedBox(height: 10),
                Text(
                  loc.get('rules_banner_title'),
                  style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700, color: Colors.white),
                ),
                const SizedBox(height: 8),
                Text(
                  loc.get('rules_banner_sub'),
                  style: const TextStyle(fontSize: 14, color: Colors.white, height: 1.55),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          ...rules.map((rule) => _buildRuleCard(
            rule: rule,
            cardBg: cardBg,
            titleColor: titleColor,
            bodyColor: bodyColor,
            isDark: isDark,
          )),

          const SizedBox(height: 16),

          // ── Жыйынтык ──
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF0FFF4),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFF22C55E).withValues(alpha: 0.4)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('💡', style: TextStyle(fontSize: 22)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    loc.get('rules_footer'),
                    style: TextStyle(fontSize: 14, color: bodyColor, height: 1.6),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildRuleCard({
    required _Rule rule,
    required Color cardBg,
    required Color titleColor,
    required Color bodyColor,
    required bool isDark,
  }) {
    // Кара режимде: фон өтө жарык болбосун, текст ак
    final tipBg = isDark
        ? rule.accentColor.withValues(alpha: 0.18)
        : rule.accentColor.withValues(alpha: 0.10);
    final tipTextColor = isDark ? Colors.white : Colors.black;
    final tagBg = isDark
        ? rule.accentColor.withValues(alpha: 0.22)
        : rule.accentColor.withValues(alpha: 0.12);
    final tagTextColor = isDark ? Colors.white : Colors.black;
    final numBg = isDark
        ? rule.accentColor.withValues(alpha: 0.25)
        : rule.accentColor.withValues(alpha: 0.15);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        boxShadow: isDark
            ? []
            : [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Баш катар ──
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Row(
              children: [
                // Номер
                Container(
                  width: 38, height: 38,
                  decoration: BoxDecoration(color: numBg, borderRadius: BorderRadius.circular(10)),
                  alignment: Alignment.center,
                  child: Text(
                    rule.number,
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: isDark ? Colors.white : Colors.black),
                  ),
                ),
                const SizedBox(width: 10),
                // Тег
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: tagBg, borderRadius: BorderRadius.circular(20)),
                  child: Text(
                    rule.tag,
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: tagTextColor),
                  ),
                ),
                const SizedBox(width: 8),
                Text(rule.emoji, style: const TextStyle(fontSize: 19)),
              ],
            ),
          ),

          // ── Аталыш ──
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Text(
              rule.title,
              style: TextStyle(fontSize: 19, fontWeight: FontWeight.w600, color: titleColor, height: 1.4),
            ),
          ),

          // ── Сүрөттөмө ──
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Text(
              rule.desc,
              style: TextStyle(fontSize: 14, color: bodyColor, height: 1.65),
            ),
          ),

          // ── Кеңеш ──
          Container(
            margin: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(color: tipBg, borderRadius: BorderRadius.circular(10)),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('💬', style: TextStyle(fontSize: 15)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    rule.tip,
                    style: TextStyle(fontSize: 14, color: tipTextColor, height: 1.55, fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Rule {
  final String number;
  final String emoji;
  final String tag;
  final String title;
  final String desc;
  final String tip;
  final Color accentColor;

  const _Rule({
    required this.number,
    required this.emoji,
    required this.tag,
    required this.title,
    required this.desc,
    required this.tip,
    required this.accentColor,
  });
}