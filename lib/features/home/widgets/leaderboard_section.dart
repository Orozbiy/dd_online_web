// ══════════════════════════════════════════════════════════════════════════════
// lib/features/home/widgets/leaderboard_section.dart
//
// Топ Алуучулар — Leaderboard блогу
// Flash Sale блогунун АСТЫНАН жайгашат.
//
// SUPABASE: жаңы таблица керек:
//   CREATE TABLE buyer_scores (
//     id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
//     user_id      uuid REFERENCES profiles(id) ON DELETE CASCADE,
//     full_name    text,
//     avatar_url   text,
//     total_score  integer DEFAULT 0,
//     orders_count integer DEFAULT 0,
//     updated_at   timestamptz DEFAULT now()
//   );
//
// БАЛЛ ЭСЕПТӨӨ (сатып алуу болгондо чакырыла турган функция):
//   UPDATE buyer_scores
//   SET total_score = total_score + <сатып алуу суммасы / 100>,
//       orders_count = orders_count + 1,
//       updated_at = now()
//   WHERE user_id = '<user_id>';
// ══════════════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import '../../../config/theme/app_colors.dart';
import '../../../config/theme/app_text_styles.dart';
import '../../../core/supabase_client.dart';

class LeaderboardSection extends StatefulWidget {
  const LeaderboardSection({super.key});

  @override
  State<LeaderboardSection> createState() => _LeaderboardSectionState();
}

class _LeaderboardSectionState extends State<LeaderboardSection> {
  List<Map<String, dynamic>> _leaders = [];
  bool _loading = true;
  // Учурдагы колдонуучунун рейтинги
  Map<String, dynamic>? _myRank;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      // Топ 10 алуучулар
      final rows = await supabase
          .from('buyer_scores')
          .select('user_id, full_name, avatar_url, total_score, orders_count')
          .order('total_score', ascending: false)
          .limit(10);

      final leaders = (rows as List)
          .map((r) => Map<String, dynamic>.from(r as Map))
          .toList();

      // Учурдагы колдонуучу
      final userId = supabase.auth.currentUser?.id;
      Map<String, dynamic>? myRank;
      if (userId != null) {
        final myRow = await supabase
            .from('buyer_scores')
            .select('user_id, full_name, total_score, orders_count')
            .eq('user_id', userId)
            .maybeSingle();
        if (myRow != null) {
          // Позицияны эсептөө — менден жогору балл барлардын саны + 1
          final aboveMe = await supabase
              .from('buyer_scores')
              .select('user_id')
              .gt('total_score', myRow['total_score'] as int);
          final rank = (aboveMe as List).length + 1;
          myRank = Map<String, dynamic>.from(myRow as Map)
            ..['rank'] = rank;
        }
      }

      if (mounted) {
        setState(() {
          _leaders = leaders;
          _myRank = myRank;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const SizedBox.shrink();
    if (_leaders.isEmpty) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Блок аталышы ──
        Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
          child: Row(
            children: [
              const Text('🏆', style: TextStyle(fontSize: 18)),
              const SizedBox(width: 8),
              Text(
                'Топ алуучулар',
                style: AppTextStyles.headingSmall.copyWith(
                  color: isDark ? Colors.white : AppColors.black,
                ),
              ),
              const Spacer(),
              // Биздин позиция
              if (_myRank != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Сениң орнуң: #${_myRank!['rank']}',
                    style: AppTextStyles.labelSmall.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
        ),

        // ── Подиум: Топ 3 ──
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: _Podium(leaders: _leaders.take(3).toList(), isDark: isDark),
        ),

        const SizedBox(height: 8),

        // ── 4-10 орун тизмеси ──
        if (_leaders.length > 3)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isDark
                    ? const Color(0xFF2C2C2C)
                    : const Color(0xFFEEEEEE),
                width: 0.5,
              ),
            ),
            child: Column(
              children: [
                for (int i = 3; i < _leaders.length; i++) ...[
                  _LeaderRow(
                    rank: i + 1,
                    item: _leaders[i],
                    isDark: isDark,
                    isLast: i == _leaders.length - 1,
                  ),
                ],
              ],
            ),
          ),

        // ── Учурдагы колдонуучу (топ 10-дон тышкары болсо) ──
        if (_myRank != null && (_myRank!['rank'] as int) > 10)
          _MyRankCard(myRank: _myRank!, isDark: isDark),

        const SizedBox(height: 12),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════
// ПОДИУМ: Топ 3
// ══════════════════════════════════════════════════════
class _Podium extends StatelessWidget {
  final List<Map<String, dynamic>> leaders;
  final bool isDark;

  const _Podium({required this.leaders, required this.isDark});

  @override
  Widget build(BuildContext context) {
    if (leaders.isEmpty) return const SizedBox.shrink();

    // Подиум тартиби: 2-орун, 1-орун, 3-орун
    final order = <int>[];
    if (leaders.length >= 2) order.add(1); // 2-орун (сол)
    order.add(0); // 1-орун (борбор)
    if (leaders.length >= 3) order.add(2); // 3-орун (оң)

    final medals = ['🥇', '🥈', '🥉'];
    final heights = [80.0, 100.0, 65.0]; // Подиум бийиктиктери
    final colors = [
      const Color(0xFFFFD700), // Алтын
      const Color(0xFFC0C0C0), // Күмүш
      const Color(0xFFCD7F32), // Коло
    ];

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A1A) : const Color(0xFFFAFAFA),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF2C2C2C) : const Color(0xFFEEEEEE),
          width: 0.5,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: order.map((idx) {
          final item = leaders[idx];
          final name = item['full_name'] as String? ?? 'Колдонуучу';
          final score = item['total_score'] as int? ?? 0;
          final avatarUrl = item['avatar_url'] as String? ?? '';
          final isFirst = idx == 0;

          return Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                // Медаль эмодзи
                Text(medals[idx], style: TextStyle(fontSize: isFirst ? 24 : 18)),
                const SizedBox(height: 4),
                // Аватар
                Container(
                  width: isFirst ? 52 : 42,
                  height: isFirst ? 52 : 42,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: colors[idx], width: 2.5),
                    color: isDark ? const Color(0xFF2C2C2C) : AppColors.grey100,
                  ),
                  child: avatarUrl.isNotEmpty
                      ? ClipOval(
                          child: Image.network(
                            avatarUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                _Initials(name: name, color: colors[idx]),
                          ),
                        )
                      : _Initials(name: name, color: colors[idx]),
                ),
                const SizedBox(height: 6),
                // Аты
                Text(
                  name.split(' ').first, // Биринчи ат гана
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: isFirst ? 13 : 11,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : AppColors.black,
                  ),
                ),
                // Балл
                Text(
                  '$score pts',
                  style: TextStyle(
                    fontSize: 10,
                    color: AppColors.grey500,
                  ),
                ),
                const SizedBox(height: 6),
                // Подиум
                Container(
                  width: double.infinity,
                  height: heights[idx],
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    color: colors[idx].withValues(alpha: 0.18),
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(8),
                    ),
                    border: Border.all(
                      color: colors[idx].withValues(alpha: 0.4),
                      width: 0.8,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      '#${idx + 1}',
                      style: TextStyle(
                        color: colors[idx],
                        fontWeight: FontWeight.w700,
                        fontSize: isFirst ? 18 : 14,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════
// 4-10 ОРУН КАТАР
// ══════════════════════════════════════════════════════
class _LeaderRow extends StatelessWidget {
  final int rank;
  final Map<String, dynamic> item;
  final bool isDark;
  final bool isLast;

  const _LeaderRow({
    required this.rank,
    required this.item,
    required this.isDark,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    final name = item['full_name'] as String? ?? 'Колдонуучу';
    final score = item['total_score'] as int? ?? 0;
    final orders = item['orders_count'] as int? ?? 0;
    final divColor =
        isDark ? const Color(0xFF2C2C2C) : const Color(0xFFEEEEEE);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              // Номер
              SizedBox(
                width: 28,
                child: Text(
                  '#$rank',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.grey400,
                  ),
                ),
              ),
              // Аватар (инициалдар)
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isDark
                      ? const Color(0xFF2C2C2C)
                      : AppColors.grey100,
                ),
                child: _Initials(
                  name: name,
                  color: AppColors.primary,
                  fontSize: 12,
                ),
              ),
              const SizedBox(width: 10),
              // Аты
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: isDark ? Colors.white : AppColors.black,
                      ),
                    ),
                    Text(
                      '$orders буюртма',
                      style: const TextStyle(
                        fontSize: 10,
                        color: AppColors.grey400,
                      ),
                    ),
                  ],
                ),
              ),
              // Балл
              Text(
                '$score pts',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        ),
        if (!isLast) Divider(height: 1, color: divColor, indent: 14),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════
// МЕНИН КАРТОЧКАМ (Топ 10-дан тышкары болсо)
// ══════════════════════════════════════════════════════
class _MyRankCard extends StatelessWidget {
  final Map<String, dynamic> myRank;
  final bool isDark;

  const _MyRankCard({required this.myRank, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final rank = myRank['rank'] as int;

    final score = myRank['total_score'] as int? ?? 0;

    return Container(
      margin: const EdgeInsets.fromLTRB(14, 8, 14, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: isDark ? 0.15 : 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.3),
          width: 0.8,
        ),
      ),
      child: Row(
        children: [
          Text(
            '#$rank',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            '📍 Сениң орнуң',
            style: TextStyle(
              fontSize: 13,
              color: isDark ? Colors.white70 : AppColors.grey600,
            ),
          ),
          const Spacer(),
          Text(
            '$score pts',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════
// ЖАРДАМЧЫ: Инициалдар виджети
// ══════════════════════════════════════════════════════
class _Initials extends StatelessWidget {
  final String name;
  final Color color;
  final double fontSize;

  const _Initials({
    required this.name,
    required this.color,
    this.fontSize = 14,
  });

  String get _initials {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        _initials,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: fontSize,
        ),
      ),
    );
  }
}
