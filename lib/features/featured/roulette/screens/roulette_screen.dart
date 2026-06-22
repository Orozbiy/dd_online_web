// ══════════════════════════════════════════════════════════════════════════════
// lib/features/featured/roulette/screens/roulette_screen.dart
// ══════════════════════════════════════════════════════════════════════════════

import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../config/theme/app_colors.dart';
import '../../../../core/supabase_client.dart';
import '../../../../core/app_localizations.dart';

// ─── Модель ────────────────────────────────────────────────────────────────
class _RouletteEntry {
  final String userId;
  final String fullName;
  final String? avatarUrl;
  final int totalPts;
  final int rank;
  const _RouletteEntry({
    required this.userId,
    required this.fullName,
    this.avatarUrl,
    required this.totalPts,
    required this.rank,
  });
}

// ══════════════════════════════════════════════════════════════════════════════
// Сектор логикасы — жебе жогору (12 саат) карайт
// ══════════════════════════════════════════════════════════════════════════════
const _kSectorCount  = 5;
const _kSectorValues = [1, 2, 3, 4, 5];
const _kSweep        = 2 * pi / _kSectorCount;

int _sectorAtArrow(double angle) {
  final normalized = ((-angle) % (2 * pi) + 2 * pi) % (2 * pi);
  final shifted    = (normalized + _kSweep / 2) % (2 * pi);
  final idx        = (shifted / _kSweep).floor() % _kSectorCount;
  return _kSectorValues[idx];
}

// ══════════════════════════════════════════════════════════════════════════════
class RouletteScreen extends StatefulWidget {
  const RouletteScreen({super.key});
  @override
  State<RouletteScreen> createState() => _RouletteScreenState();
}

class _RouletteScreenState extends State<RouletteScreen>
    with TickerProviderStateMixin {

  // ── Wheel animation ──
  late AnimationController _wheelCtrl;
  late Animation<double>   _wheelAnim;

  // ── Свеча / жаркыроо анимациясы ──
  late AnimationController _glowCtrl;
  late Animation<double>   _glowAnim;



  // ── Маалыматтар ──
  List<_RouletteEntry> _top100  = [];
  _RouletteEntry?      _myEntry;
  bool   _loading    = true;
  bool   _canSpin    = false;
  bool   _spinning   = false;
  double _wheelAngle = 0;

  @override
  void initState() {
    super.initState();

    // Wheel
    _wheelCtrl = AnimationController(vsync: this);

    // Свеча — дем алгандай жаркыроо (looping)
    _glowCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
    _glowAnim = CurvedAnimation(parent: _glowCtrl, curve: Curves.easeInOut);

    _load();
  }

  @override
  void dispose() {
    _wheelCtrl.dispose();
    _glowCtrl.dispose();
    super.dispose();
  }

  // ── Жүктөө ───────────────────────────────────────────────────────────────
  Future<void> _load() async {
    try {
      final rows = await supabase
          .from('roulette_scores')
          .select('user_id, full_name, avatar_url, total_pts')
          .order('total_pts', ascending: false)
          .limit(100);

      final list = (rows as List).asMap().entries.map((e) => _RouletteEntry(
        userId:    e.value['user_id']    as String,
        fullName:  e.value['full_name']  as String? ?? 'Колдонуучу',
        avatarUrl: e.value['avatar_url'] as String?,
        totalPts:  (e.value['total_pts'] as num?)?.toInt() ?? 0,
        rank: e.key + 1,
      )).toList();

      final uid = supabase.auth.currentUser?.id;
      _RouletteEntry? myEntry;
      bool canSpin = false;

      if (uid != null) {
        final myRow = await supabase
            .from('roulette_scores')
            .select('user_id, full_name, avatar_url, total_pts, last_spin')
            .eq('user_id', uid)
            .maybeSingle();

        if (myRow != null) {
          final above = await supabase
              .from('roulette_scores')
              .select('user_id')
              .gt('total_pts', myRow['total_pts'] as int);
          final rank = (above as List).length + 1;
          myEntry = _RouletteEntry(
            userId:    uid,
            fullName:  myRow['full_name']  as String? ?? 'Мен',
            avatarUrl: myRow['avatar_url'] as String?,
            totalPts:  (myRow['total_pts'] as num?)?.toInt() ?? 0,
            rank: rank,
          );
          canSpin = (myRow['last_spin'] as String?) != _todayStr();
        } else {
          canSpin = true;
        }
      }

      if (mounted) {
        setState(() {
          _top100  = list;
          _myEntry = myEntry;
          _canSpin = canSpin && uid != null;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _todayStr() {
    final n = DateTime.now();
    return '${n.year}-${n.month.toString().padLeft(2,'0')}-${n.day.toString().padLeft(2,'0')}';
  }

  // ── Айлануу ──────────────────────────────────────────────────────────────
  Future<void> _spin() async {
    if (_spinning || !_canSpin) return;
    final uid = supabase.auth.currentUser?.id;
    if (uid == null) {
      _showMsg(AppLocalizations.of(context).get('roulette_login_required'));
      return;
    }

    setState(() => _spinning = true);

    final extraSpins    = 8 + Random().nextInt(5); // 8–12 айлануу
    final randomStop    = Random().nextDouble() * 2 * pi;
    final totalRotation = 2 * pi * extraSpins + randomStop;

    _wheelCtrl.reset();
    _wheelAnim = Tween<double>(
      begin: _wheelAngle,
      end:   _wheelAngle + totalRotation,
    ).animate(CurvedAnimation(
      parent: _wheelCtrl,
      // easeOutQuart — башында тез, акырында абдан жай токтойт
      curve: const Cubic(0.25, 0.46, 0.45, 0.94),
    ));
    _wheelCtrl.duration = const Duration(milliseconds: 7500); // 7.5 сек
    await _wheelCtrl.forward();

    final finalAngle = _wheelAngle + totalRotation;
    _wheelAngle = finalAngle % (2 * pi);

    final pts = _sectorAtArrow(finalAngle);

    // Сактоо
    try {
      final profile = await supabase
          .from('profiles')
          .select('full_name, avatar_url')
          .eq('id', uid)
          .maybeSingle();
      await supabase.from('roulette_scores').upsert({
        'user_id':    uid,
        'full_name':  profile?['full_name']  as String? ?? 'Колдонуучу',
        'avatar_url': profile?['avatar_url'] as String?,
        'total_pts':  (_myEntry?.totalPts ?? 0) + pts,
        'last_spin':  _todayStr(),
      }, onConflict: 'user_id');
    } catch (_) {}

    if (mounted) {
      setState(() { _spinning = false; _canSpin = false; });
      _showWinDialog(pts);
      _load();
    }
  }

  void _showWinDialog(int pts) {
    final loc = AppLocalizations.of(context);
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF1a1a2e), Color(0xFF16213e)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: const Color(0xFFFFD700).withValues(alpha: 0.6),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFFD700).withValues(alpha: 0.3),
                blurRadius: 30,
                spreadRadius: 5,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Жылдыздар
              const Text('✨', style: TextStyle(fontSize: 20)),
              const SizedBox(height: 4),
              const Text('🎉', style: TextStyle(fontSize: 56)),
              const SizedBox(height: 12),
              ShaderMask(
                shaderCallback: (b) => const LinearGradient(
                  colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
                ).createShader(b),
                child: Text(
                  '+$pts ${loc.get('roulette_pts')}!',
                  style: const TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                loc.get('roulette_win_body'),
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFFD700),
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  child: Text(
                    loc.get('roulette_win_close'),
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showMsg(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), duration: const Duration(seconds: 2)));
  }

  // ══════════════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final loc           = AppLocalizations.of(context);
    final isDark        = Theme.of(context).brightness == Brightness.dark;
    final subtitleColor = isDark ? Colors.white60 : AppColors.grey500;

    return Scaffold(
      backgroundColor: const Color(0xFF0f0f1a),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0f0f1a),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: ShaderMask(
          shaderCallback: (b) => const LinearGradient(
            colors: [Color(0xFFFFD700), Color(0xFFFFA500), Color(0xFFFFD700)],
          ).createShader(b),
          child: Text(
            loc.get('roulette_screen_title'),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
        ),
        centerTitle: true,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFFFD700)))
          : Column(
              children: [
                _buildRouletteCard(loc, subtitleColor),
                Expanded(child: _buildLeaderboard(isDark, loc)),
                if (_myEntry != null) _buildMyRow(loc),
              ],
            ),
    );
  }

  // ── Рулетка карточкасы ───────────────────────────────────────────────────
  Widget _buildRouletteCard(AppLocalizations loc, Color subtitleColor) {
    return Container(
      color: const Color(0xFF0f0f1a),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
      child: Column(
        children: [
          // ── Свеча жаркыроо + тегерек ──
          AnimatedBuilder(
            animation: Listenable.merge([_glowCtrl, _wheelCtrl]),
            builder: (_, __) {
              final glowVal  = _glowAnim.value;
              final wheelVal = _wheelCtrl.isAnimating
                  ? _wheelAnim.value
                  : _wheelAngle;

              return Stack(
                alignment: Alignment.center,
                children: [
                  // ── Тышкы жаркыроо (свеча) ──
                  Container(
                    width:  260 + glowVal * 20,
                    height: 260 + glowVal * 20,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFFD700)
                              .withValues(alpha: 0.08 + glowVal * 0.12),
                          blurRadius:   60 + glowVal * 40,
                          spreadRadius: 10 + glowVal * 15,
                        ),
                        BoxShadow(
                          color: const Color(0xFFFFA500)
                              .withValues(alpha: 0.05 + glowVal * 0.08),
                          blurRadius:   100 + glowVal * 50,
                          spreadRadius: 20,
                        ),
                      ],
                    ),
                  ),

                  // ── Орто жаркыроо (жылдыз сымал) ──
                  Container(
                    width:  240,
                    height: 240,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          const Color(0xFFFFD700)
                              .withValues(alpha: 0.05 + glowVal * 0.08),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),

                  // ── Жебе + тегерек ──
                  _buildWheelWithArrow(wheelVal),
                ],
              );
            },
          ),

          const SizedBox(height: 20),

          // ── Айлант баскычы ──
          AnimatedBuilder(
            animation: _glowAnim,
            builder: (_, child) {
              return Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: _canSpin
                      ? [
                          BoxShadow(
                            color: const Color(0xFFFFD700)
                                .withValues(alpha: 0.2 + _glowAnim.value * 0.25),
                            blurRadius:   20 + _glowAnim.value * 15,
                            spreadRadius: 2,
                          ),
                        ]
                      : [],
                ),
                child: child,
              );
            },
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _canSpin && !_spinning ? _spin : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _canSpin
                      ? const Color(0xFFFFD700)
                      : const Color(0xFF2a2a3e),
                  foregroundColor:
                      _canSpin ? Colors.black : Colors.white38,
                  disabledBackgroundColor: const Color(0xFF2a2a3e),
                  disabledForegroundColor: Colors.white38,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
                child: _spinning
                    ? const SizedBox(
                        width: 22, height: 22,
                        child: CircularProgressIndicator(
                            color: Colors.black, strokeWidth: 2.5),
                      )
                    : Text(
                        _canSpin
                            ? AppLocalizations.of(context).get('roulette_spin_btn')
                            : AppLocalizations.of(context).get('roulette_wait_btn'),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                          color: _canSpin ? Colors.black : Colors.white38,
                        ),
                      ),
              ),
            ),
          ),

          if (!_canSpin && !_spinning) ...[
            const SizedBox(height: 10),
            Text(
              AppLocalizations.of(context).get('roulette_used_today'),
              style: TextStyle(color: subtitleColor, fontSize: 12),
            ),
            const SizedBox(height: 6),
            // ── Жакында белек жөнүндө кабар ──
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFFFFD700).withValues(alpha: 0.08),
                    const Color(0xFFFFA500).withValues(alpha: 0.05),
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFFFFD700).withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                children: [
                  const Text('🎁', style: TextStyle(fontSize: 18)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      AppLocalizations.of(context).get('roulette_coming_soon'),
                      style: TextStyle(
                        color: const Color(0xFFFFD700).withValues(alpha: 0.85),
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Тегерек + жебе ───────────────────────────────────────────────────────
  Widget _buildWheelWithArrow(double angle) {
    const double wheelSize   = 230;
    const double arrowH      = 30;
    const double totalHeight = wheelSize + arrowH + 4;

    return SizedBox(
      width:  wheelSize,
      height: totalHeight,
      child: Stack(
        alignment: Alignment.topCenter,
        children: [
          // ── Жебе ──
          Positioned(
            top: 0,
            child: CustomPaint(
              size: const Size(32, arrowH),
              painter: _ArrowPainter(),
            ),
          ),

          // ── Тегерек ──
          Positioned(
            bottom: 0,
            child: Transform.rotate(
              angle: angle,
              child: SizedBox(
                width: wheelSize, height: wheelSize,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CustomPaint(
                      size: const Size(wheelSize, wheelSize),
                      painter: _WheelPainter(),
                    ),
                    // Ортодогу ак чекит
                    Container(
                      width: 22, height: 22,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.3),
                            blurRadius: 8,
                          )
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Топ 100 ──────────────────────────────────────────────────────────────
  Widget _buildLeaderboard(bool isDark, AppLocalizations loc) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 10, 12, 0),
      decoration: BoxDecoration(
        color: const Color(0xFF1a1a2e),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFFFD700).withValues(alpha: 0.15),
        ),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(children: [
              const Text('🏆', style: TextStyle(fontSize: 20)),
              const SizedBox(width: 8),
              ShaderMask(
                shaderCallback: (b) => const LinearGradient(
                  colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
                ).createShader(b),
                child: Text(
                  loc.get('roulette_top100'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ]),
          ),
          Divider(height: 1,
              color: const Color(0xFFFFD700).withValues(alpha: 0.15)),
          Expanded(
            child: _top100.isEmpty
                ? Center(
                    child: Text(loc.get('roulette_empty'),
                        style: const TextStyle(color: Colors.white38)))
                : ListView.builder(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.only(bottom: 8),
                    itemCount: _top100.length,
                    itemBuilder: (_, i) =>
                        _buildLeaderRow(_top100[i], loc),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildLeaderRow(_RouletteEntry e, AppLocalizations loc) {
    final isMe  = e.userId == supabase.auth.currentUser?.id;
    final medal = e.rank == 1 ? '🥇' : e.rank == 2 ? '🥈' : e.rank == 3 ? '🥉' : null;

    return Container(
      decoration: BoxDecoration(
        color: isMe
            ? const Color(0xFFFFD700).withValues(alpha: 0.07)
            : Colors.transparent,
        border: isMe
            ? Border(
                left: BorderSide(
                  color: const Color(0xFFFFD700).withValues(alpha: 0.5),
                  width: 2,
                ),
              )
            : null,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(children: [
        SizedBox(
          width: 36,
          child: medal != null
              ? Text(medal,
                  style: const TextStyle(fontSize: 20),
                  textAlign: TextAlign.center)
              : Text('#${e.rank}',
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.white38),
                  textAlign: TextAlign.center),
        ),
        _avatar(e.avatarUrl, e.fullName, 36),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            isMe ? '${e.fullName} (${loc.get('roulette_me')})' : e.fullName,
            style: TextStyle(
              color: isMe ? const Color(0xFFFFD700) : Colors.white,
              fontWeight: isMe ? FontWeight.bold : FontWeight.normal,
              fontSize: 14,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: isMe
                ? const Color(0xFFFFD700).withValues(alpha: 0.15)
                : Colors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(20),
            border: isMe
                ? Border.all(
                    color: const Color(0xFFFFD700).withValues(alpha: 0.4))
                : null,
          ),
          child: Text(
            '${e.totalPts} ${loc.get('roulette_pts')}',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isMe
                  ? const Color(0xFFFFD700)
                  : Colors.white60,
            ),
          ),
        ),
      ]),
    );
  }

  // ── Менин упайым ─────────────────────────────────────────────────────────
  Widget _buildMyRow(AppLocalizations loc) {
    final e = _myEntry!;
    return AnimatedBuilder(
      animation: _glowAnim,
      builder: (_, child) => Container(
        margin: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF1a1500), Color(0xFF2a2200)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: const Color(0xFFFFD700)
                .withValues(alpha: 0.3 + _glowAnim.value * 0.3),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFFD700)
                  .withValues(alpha: 0.08 + _glowAnim.value * 0.12),
              blurRadius: 20 + _glowAnim.value * 10,
              spreadRadius: 2,
            ),
          ],
        ),
        child: child,
      ),
      child: Row(children: [
        _avatar(e.avatarUrl, e.fullName, 42),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(e.fullName,
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
              Text('${loc.get('roulette_my_rank')}: #${e.rank}',
                  style: TextStyle(
                      color: const Color(0xFFFFD700).withValues(alpha: 0.7),
                      fontSize: 12)),
            ],
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            ShaderMask(
              shaderCallback: (b) => const LinearGradient(
                colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
              ).createShader(b),
              child: Text('${e.totalPts}',
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 26)),
            ),
            Text(loc.get('roulette_pts'),
                style: TextStyle(
                    color: const Color(0xFFFFD700).withValues(alpha: 0.6),
                    fontSize: 11)),
          ],
        ),
      ]),
    );
  }

  // ── Аватар ───────────────────────────────────────────────────────────────
  Widget _avatar(String? url, String name, double size) {
    if (url != null && url.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(size / 2),
        child: CachedNetworkImage(
          imageUrl: url,
          width: size, height: size, fit: BoxFit.cover,
          errorWidget: (_, __, ___) => _avatarFallback(name, size),
        ),
      );
    }
    return _avatarFallback(name, size);
  }

  Widget _avatarFallback(String name, double size) {
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
        ),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        name.isNotEmpty ? name[0].toUpperCase() : '?',
        style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: size * 0.4),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// ▼ Жебе — кыймылсыз, кызыл үч бурчтук
// ══════════════════════════════════════════════════════════════════════════════
class _ArrowPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Көлөкө
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.4)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    final shadowPath = Path()
      ..moveTo(size.width / 2, size.height + 2)
      ..lineTo(2, 2)
      ..lineTo(size.width - 2, 2)
      ..close();
    canvas.drawPath(shadowPath, shadowPaint);

    // Негизги үч бурчтук
    final fillPaint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFFFF4444), Color(0xFFCC0000)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.fill;

    final path = Path()
      ..moveTo(size.width / 2, size.height) // учу (ылдый)
      ..lineTo(0,              0)            // сол жогору
      ..lineTo(size.width,     0)            // оң жогору
      ..close();

    canvas.drawPath(path, fillPaint);

    // Ак чек
    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.8)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ══════════════════════════════════════════════════════════════════════════════
// Рулетка тегерек
// ══════════════════════════════════════════════════════════════════════════════
class _WheelPainter extends CustomPainter {
  static const _colors = [
    Color(0xFFEF4444),
    Color(0xFFF97316),
    Color(0xFFEAB308),
    Color(0xFF22C55E),
    Color(0xFF3B82F6),
  ];
  static const _labels = ['1', '2', '3', '4', '5'];

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    const sectorCount = 5;
    const sweepAngle  = 2 * pi / sectorCount;
    double startAngle  = -pi / 2 - sweepAngle / 2;

    final paint = Paint()..style = PaintingStyle.fill;

    for (int i = 0; i < sectorCount; i++) {
      // Сектор
      paint.color = _colors[i];
      canvas.drawArc(
          Rect.fromCircle(center: center, radius: radius),
          startAngle, sweepAngle, true, paint);

      // Ак чек
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle, sweepAngle, true,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.9)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );

      // Сан
      final textAngle  = startAngle + sweepAngle / 2;
      final textRadius = radius * 0.64;
      final textOffset = Offset(
        center.dx + textRadius * cos(textAngle),
        center.dy + textRadius * sin(textAngle),
      );

      final tp = TextPainter(
        text: TextSpan(
          text: _labels[i],
          style: const TextStyle(
            color: Colors.white,
            fontSize: 26,
            fontWeight: FontWeight.bold,
            shadows: [Shadow(color: Colors.black45, blurRadius: 6)],
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      canvas.save();
      canvas.translate(textOffset.dx, textOffset.dy);
      canvas.rotate(textAngle + pi / 2);
      tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
      canvas.restore();

      startAngle += sweepAngle;
    }

    // Тышкы алтын чек
    canvas.drawCircle(
      center, radius,
      Paint()
        ..color = const Color(0xFFFFD700).withValues(alpha: 0.8)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.5,
    );

    // Ички нур (шайнеген чек)
    canvas.drawCircle(
      center, radius - 4,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.15)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
