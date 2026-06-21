import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../config/theme/app_colors.dart';
import '../../../config/theme/app_text_styles.dart';
import 'admin_panel_screen.dart';

const String _adminPassword = 'meninapam_65';
const String _kFailCount    = 'admin_login_fail_count';
const String _kBlockedUntil = 'admin_login_blocked_until';
const String _kEscalated    = 'admin_login_escalated';

class AdminLoginScreen extends StatefulWidget {
  const AdminLoginScreen({super.key});

  @override
  State<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends State<AdminLoginScreen> {
  final _passwordController = TextEditingController();
  bool _isLoading    = false;
  bool _obscure      = true;
  int  _wrongAttempts = 0;
  DateTime? _blockedUntil;
  bool _checkingBlock = true;

  @override
  void initState() {
    super.initState();
    _loadBlockState();
  }

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _loadBlockState() async {
    final prefs = await SharedPreferences.getInstance();
    final ms = prefs.getInt(_kBlockedUntil);
    if (ms != null) {
      final until = DateTime.fromMillisecondsSinceEpoch(ms);
      if (until.isAfter(DateTime.now())) {
        setState(() { _blockedUntil = until; _checkingBlock = false; });
        return;
      } else {
        await prefs.remove(_kBlockedUntil);
      }
    }
    setState(() => _checkingBlock = false);
  }

  Future<void> _registerFailure() async {
    final prefs     = await SharedPreferences.getInstance();
    final escalated = prefs.getBool(_kEscalated) ?? false;
    final failCount = (prefs.getInt(_kFailCount) ?? 0) + 1;

    if (escalated) {
      final until = DateTime.now().add(const Duration(hours: 24));
      await prefs.setInt(_kBlockedUntil, until.millisecondsSinceEpoch);
      await prefs.setInt(_kFailCount, 0);
      await prefs.setBool(_kEscalated, false);
      if (mounted) setState(() => _blockedUntil = until);
      return;
    }

    if (failCount >= 3) {
      final until = DateTime.now().add(const Duration(hours: 1));
      await prefs.setInt(_kBlockedUntil, until.millisecondsSinceEpoch);
      await prefs.setInt(_kFailCount, 0);
      await prefs.setBool(_kEscalated, true);
      if (mounted) setState(() => _blockedUntil = until);
    } else {
      await prefs.setInt(_kFailCount, failCount);
    }
  }

  Future<void> _registerSuccess() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kFailCount);
    await prefs.remove(_kBlockedUntil);
    await prefs.remove(_kEscalated);
  }

  String _formatRemaining(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes % 60;
    final s = d.inSeconds % 60;
    if (h > 0) return '${h}с ${m}мүн';
    if (m > 0) return '${m}мүн ${s}сек';
    return '${s}сек';
  }

  void _login() async {
    if (_blockedUntil != null) {
      if (_blockedUntil!.isAfter(DateTime.now())) {
        _showSnack('Бул бет блокголду. ${_formatRemaining(_blockedUntil!.difference(DateTime.now()))} күтүңүз.', AppColors.error);
        return;
      } else {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove(_kBlockedUntil);
        if (mounted) setState(() => _blockedUntil = null);
      }
    }

    final password = _passwordController.text.trim();
    if (password.isEmpty) { _showSnack('Паролду жазыңыз!', AppColors.error); return; }

    setState(() => _isLoading = true);
    await Future.delayed(const Duration(milliseconds: 600));
    setState(() => _isLoading = false);

    if (password == _adminPassword) {
      await _registerSuccess();
      if (!mounted) return;
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const AdminPanelScreen()));
    } else {
      _wrongAttempts++;
      _passwordController.clear();
      await _registerFailure();
      if (_blockedUntil != null) {
        _showSnack('Пароль туура эмес! Бет блокголду. ${_formatRemaining(_blockedUntil!.difference(DateTime.now()))} күтүңүз.', AppColors.error);
      } else {
        _showSnack(_wrongAttempts >= 3 ? 'Пароль туура эмес! $_wrongAttempts жолу туура эмес киргиздиңиз.' : 'Пароль туура эмес!', AppColors.error);
      }
    }
  }

  void _showSnack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: color));
  }

  @override
  Widget build(BuildContext context) {
    final isDark    = Theme.of(context).brightness == Brightness.dark;
    final isBlocked = _blockedUntil != null && _blockedUntil!.isAfter(DateTime.now());

    // ── Адаптивдүү түстөр ──
    final bgColor       = isDark ? const Color(0xFF121212) : Colors.white;
    final appBarColor   = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final arrowColor    = isDark ? Colors.white : AppColors.black;
    final titleColor    = isDark ? Colors.white : AppColors.black;        // "Admin панели" жазуусу
    final subtitleColor = isDark ? const Color(0xFFAAAAAA) : AppColors.grey500;
    final labelColor    = isDark ? const Color(0xFFCCCCCC) : AppColors.grey600;
    final fieldFill     = isDark ? const Color(0xFF2C2C2C) : const Color(0xFFF7F7F7);
    final fieldText     = isDark ? Colors.white : AppColors.black;        // пароль тексти
    final hintColor     = isDark ? const Color(0xFF666666) : AppColors.grey400;
    final warnBg        = isDark ? const Color(0xFF1A2744) : const Color(0xFFEFF6FF);
    final warnBorder    = const Color(0xFF1E40AF).withValues(alpha: isDark ? 0.5 : 0.2);
    final warnText      = isDark ? const Color(0xFF93C5FD) : const Color(0xFF1E40AF);
    final blockBg       = isDark ? const Color(0xFF2A1515) : const Color(0xFFFFEEEE);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: appBarColor,
        elevation: 0,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Icon(Icons.arrow_back, color: arrowColor),
        ),
        title: Text('Admin кириш',
            style: AppTextStyles.headingMedium.copyWith(color: titleColor)),
        centerTitle: true,
      ),
      body: SafeArea(
        child: _checkingBlock
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(height: 40),

                    // ── Логотип ──
                    Container(
                      width: 110,
                      height: 110,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF1E40AF), Color(0xFF7C3AED)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(28),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF1E40AF).withValues(alpha: 0.3),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Text('🛡️', style: TextStyle(fontSize: 52)),
                      ),
                    ),

                    const SizedBox(height: 28),

                    // ── "Admin панели" — АДАПТИВДҮҮ ──
                    Text(
                      'Admin панели',
                      style: AppTextStyles.headingLarge.copyWith(color: titleColor),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Жашыруун пароль менен кириңиз',
                      style: AppTextStyles.bodyMedium.copyWith(color: subtitleColor),
                    ),

                    const SizedBox(height: 48),

                    if (isBlocked)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: blockBg,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Text('🔒', style: TextStyle(fontSize: 18)),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Бул бет убактынча блокголду',
                                    style: AppTextStyles.labelLarge.copyWith(color: AppColors.error),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '${_formatRemaining(_blockedUntil!.difference(DateTime.now()))} кийин кайра аракет кылыңыз.',
                              style: AppTextStyles.bodyMedium.copyWith(color: AppColors.error),
                            ),
                          ],
                        ),
                      )
                    else ...[
                      // ── Пароль жазуусу ──
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          '🔐  Пароль',
                          style: AppTextStyles.labelLarge.copyWith(color: labelColor),
                        ),
                      ),
                      const SizedBox(height: 8),

                      // ── Пароль талаасы — АДАПТИВДҮҮ ──
                      TextField(
                        controller: _passwordController,
                        obscureText: _obscure,
                        style: AppTextStyles.bodyMedium.copyWith(color: fieldText),
                        onSubmitted: (_) => _login(),
                        decoration: InputDecoration(
                          hintText: '••••••••',
                          hintStyle: AppTextStyles.bodyMedium.copyWith(color: hintColor),
                          filled: true,
                          fillColor: fieldFill,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFF1E40AF), width: 1.5),
                          ),
                          suffixIcon: GestureDetector(
                            onTap: () => setState(() => _obscure = !_obscure),
                            child: Icon(
                              _obscure ? Icons.visibility_off : Icons.visibility,
                              color: hintColor,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 32),

                      // ── Кириш баскычы ──
                      SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _login,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1E40AF),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            elevation: 0,
                          ),
                          child: _isLoading
                              ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                              : Text('🛡️  Кирүү',
                                  style: AppTextStyles.labelLarge.copyWith(color: Colors.white, fontSize: 16)),
                        ),
                      ),
                    ],

                    const SizedBox(height: 24),

                    // ── Эскертүү ──
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: warnBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: warnBorder),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('⚠️', style: TextStyle(fontSize: 18)),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Бул бет жалгыз Admin үчүн.\nБашка адамдар кирүүгө тыюуу салынат!',
                              style: AppTextStyles.labelMedium.copyWith(color: warnText, height: 1.5),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}