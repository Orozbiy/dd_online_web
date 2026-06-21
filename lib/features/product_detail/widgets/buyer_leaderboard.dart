// ═══════════════════════════════════════════════════════════════
// lib/features/product_detail/widgets/buyer_leaderboard.dart
//
// ProductDetailScreen'де баскыч аркылуу ачылат:
//   BuyerLeaderboard(productId: _product.id)
// ═══════════════════════════════════════════════════════════════

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../config/theme/app_colors.dart';
import '../../../config/theme/app_text_styles.dart';
import '../../../core/supabase_client.dart';

class BuyerLeaderboard extends StatefulWidget {
  final String productId;
  const BuyerLeaderboard({super.key, required this.productId});

  @override
  State<BuyerLeaderboard> createState() => _BuyerLeaderboardState();
}

class _BuyerLeaderboardState extends State<BuyerLeaderboard> {
  List<Map<String, dynamic>> _topBuyers = [];
  Map<String, dynamic>?      _myEntry;
  bool _loading = true;
  Timer? _refreshTimer;

  // Учурдагы колдонуучу
  final _myUid = supabase.auth.currentUser?.id;

  @override
  void initState() {
    super.initState();
    _load();
    // 5 саат сайын жаңылоо
    _refreshTimer = Timer.periodic(
      const Duration(hours: 5),
      (_) => _refreshRankings(),
    );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      // Рейтинг жаңылоо
      await supabase.rpc('refresh_buyer_rankings', params: {
        'p_product_id': widget.productId,
      });

      // Топ 150
      final top = await supabase.rpc('get_top_buyers', params: {
        'p_product_id': widget.productId,
      });

      // Менин жазуум (топ 150де болбосо да)
      Map<String, dynamic>? myEntry;
      if (_myUid != null) {
        final myRow = await supabase
            .from('buyer_keys')
            .select('keys_count, rank, views_count')
            .eq('user_id', _myUid!)
            .eq('product_id', widget.productId)
            .maybeSingle();
        myEntry = myRow;
      }

      if (mounted) {
        setState(() {
          _topBuyers = List<Map<String, dynamic>>.from(top as List);
          _myEntry   = myEntry;
          _loading   = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _refreshRankings() async {
    try {
      await supabase.rpc('refresh_buyer_rankings', params: {
        'p_product_id': widget.productId,
      });
      await _load();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final isDark     = Theme.of(context).brightness == Brightness.dark;
    final bgColor    = isDark ? const Color(0xFF121212) : const Color(0xFFF4F5F7);
    final cardColor  = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final titleColor = isDark ? Colors.white : AppColors.black;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: cardColor,
        elevation: 0,
        centerTitle: true,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Icon(Icons.arrow_back,
              color: isDark ? Colors.white : AppColors.black),
        ),
        title: Text('🏆 Алуучулар тизмеги',
            style: AppTextStyles.headingMedium.copyWith(color: titleColor)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: AppColors.primary),
            onPressed: () {
              setState(() => _loading = true);
              _load();
            },
          ),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary))
          : Column(
              children: [
                // ── Менин ачкычым (жогорку карточка) ──
                if (_myUid != null) _buildMyCard(isDark, cardColor, titleColor),

                // ── Маалымат ──
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.fromLTRB(14, 8, 14, 4),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.2)),
                  ),
                  child: Row(children: [
                    const Text('🔑', style: TextStyle(fontSize: 18)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Товарды ар 3 жолу көргөндө 1 ачкыч берилет. '
                        'Рейтинг 5 саат сайын жаңыланат.',
                        style: AppTextStyles.labelSmall
                            .copyWith(color: AppColors.primary, fontSize: 11),
                      ),
                    ),
                  ]),
                ),

                // ── Тизме ──
                Expanded(
                  child: _topBuyers.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text('🏆',
                                  style: TextStyle(fontSize: 64)),
                              const SizedBox(height: 16),
                              Text('Азырынча тизме бош',
                                  style: AppTextStyles.headingSmall
                                      .copyWith(color: AppColors.grey400)),
                              const SizedBox(height: 8),
                              Text('Товарды карап ачкыч жыйна!',
                                  style: AppTextStyles.bodyMedium
                                      .copyWith(color: AppColors.grey500)),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(14, 4, 14, 20),
                          itemCount: _topBuyers.length,
                          itemBuilder: (ctx, i) =>
                              _buildRow(_topBuyers[i], i, isDark, cardColor, titleColor),
                        ),
                ),
              ],
            ),
    );
  }

  // ── Менин карточкам ──
  Widget _buildMyCard(bool isDark, Color cardColor, Color titleColor) {
    final myRank   = _myEntry?['rank'] as int?;
    final myKeys   = (_myEntry?['keys_count'] as int?) ?? 0;
    final myViews  = (_myEntry?['views_count'] as int?) ?? 0;
    final inTop150 = myRank != null && myRank <= 150;

    return Container(
      margin: const EdgeInsets.fromLTRB(14, 12, 14, 0),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.4), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(children: [
        // Ачкыч иконкасы
        Container(
          width: 48, height: 48,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: const Center(
            child: Text('🔑', style: TextStyle(fontSize: 22)),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Менин ачкычтарым',
                style: AppTextStyles.labelMedium.copyWith(color: titleColor)),
            const SizedBox(height: 4),
            Row(children: [
              _statChip('🔑 $myKeys ачкыч', AppColors.primary),
              const SizedBox(width: 8),
              _statChip('👁 $myViews көрүү', AppColors.grey500),
            ]),
          ]),
        ),
        // Орун
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(
            inTop150 ? '#$myRank' : 'Топ 150 сыртында',
            style: AppTextStyles.headingSmall.copyWith(
              color: inTop150 ? AppColors.primary : AppColors.grey400,
              fontSize: inTop150 ? 20 : 12,
            ),
          ),
          if (!inTop150)
            Text('$myKeys ачкыч',
                style: AppTextStyles.labelSmall
                    .copyWith(color: AppColors.grey500)),
        ]),
      ]),
    );
  }

  // ── Тизме катары ──
  Widget _buildRow(
    Map<String, dynamic> entry,
    int index,
    bool isDark,
    Color cardColor,
    Color titleColor,
  ) {
    final rank      = (entry['rank'] as int?) ?? (index + 1);
    final keys      = (entry['keys_count'] as int?) ?? 0;
    final name      = (entry['full_name'] as String?) ?? 'Колдонуучу';
    final avatar    = entry['avatar_url'] as String?;
    final uid       = entry['user_id'] as String?;
    final isMe      = uid == _myUid;

    Color rankColor;
    String rankEmoji;
    if (rank == 1) { rankColor = const Color(0xFFFFD700); rankEmoji = '🥇'; }
    else if (rank == 2) { rankColor = const Color(0xFFC0C0C0); rankEmoji = '🥈'; }
    else if (rank == 3) { rankColor = const Color(0xFFCD7F32); rankEmoji = '🥉'; }
    else { rankColor = AppColors.grey400; rankEmoji = ''; }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isMe
            ? AppColors.primary.withValues(alpha: isDark ? 0.15 : 0.07)
            : cardColor,
        borderRadius: BorderRadius.circular(14),
        border: isMe
            ? Border.all(color: AppColors.primary.withValues(alpha: 0.4), width: 1.5)
            : null,
        boxShadow: isDark
            ? []
            : [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 6)],
      ),
      child: Row(children: [
        // Орун
        SizedBox(
          width: 40,
          child: rankEmoji.isNotEmpty
              ? Text(rankEmoji, style: const TextStyle(fontSize: 22))
              : Text(
                  '#$rank',
                  style: AppTextStyles.labelMedium.copyWith(color: rankColor),
                ),
        ),

        // Аватар
        CircleAvatar(
          radius: 20,
          backgroundColor: AppColors.primary.withValues(alpha: 0.1),
          backgroundImage:
              avatar != null ? CachedNetworkImageProvider(avatar) : null,
          child: avatar == null
              ? Text(
                  name.isNotEmpty ? name[0].toUpperCase() : '?',
                  style: AppTextStyles.labelMedium
                      .copyWith(color: AppColors.primary),
                )
              : null,
        ),
        const SizedBox(width: 10),

        // Аты
        Expanded(
          child: Text(
            isMe ? '$name (Сиз)' : name,
            style: AppTextStyles.labelMedium.copyWith(
              color: isMe ? AppColors.primary : titleColor,
              fontWeight: isMe ? FontWeight.w700 : FontWeight.normal,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),

        // Ачкычтар
        Row(children: [
          const Text('🔑', style: TextStyle(fontSize: 14)),
          const SizedBox(width: 4),
          Text(
            '$keys',
            style: AppTextStyles.labelMedium.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ]),
      ]),
    );
  }

  Widget _statChip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(text,
          style: AppTextStyles.labelSmall
              .copyWith(color: color, fontSize: 11)),
    );
  }
}
