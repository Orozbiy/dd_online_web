import 'package:flutter/material.dart';
import '../../../config/theme/app_colors.dart';
import '../../../config/theme/app_text_styles.dart';
import '../../../core/app_localizations.dart';
import '../../../core/seller_auth_service.dart';
import '../services/seller_service.dart';
import 'seller_login_screen.dart';
import 'seller_pending_screen.dart';

class SellerRegisterScreen extends StatefulWidget {
  const SellerRegisterScreen({super.key});

  @override
  State<SellerRegisterScreen> createState() => _SellerRegisterScreenState();
}

class _SellerRegisterScreenState extends State<SellerRegisterScreen> {
  final _nameCtrl            = TextEditingController();
  final _ageCtrl             = TextEditingController();
  final _shopNameCtrl        = TextEditingController();
  final _containerCtrl       = TextEditingController();
  final _phoneCtrl           = TextEditingController();
  final _passwordCtrl        = TextEditingController();
  final _passwordConfirmCtrl = TextEditingController();
  
  String _storeType   = 'market'; // 'market' | 'private'
  String? _marketName = 'Дордой базары';

  static const List<String> _markets = [
    'Дордой базары',
    'Ош базары',
    'Азиз базары',
    'Мадина базары',
    'Орто-Сай базары',
    'Аламүдүн базары',
    'Кара-Суу базары',
    'Птичий рынок',
  ];
  bool _obscure1  = true;
  bool _obscure2  = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _ageCtrl.dispose();
    _shopNameCtrl.dispose();
    _containerCtrl.dispose();
    _phoneCtrl.dispose();
    _passwordCtrl.dispose();
    _passwordConfirmCtrl.dispose();
    super.dispose();
  }

  void _showSnack(String msg, {bool isError = true}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? AppColors.error : AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      ),
    );
  }

  Future<void> _register() async {
    final loc             = AppLocalizations.of(context);
    final name            = _nameCtrl.text.trim();
    final ageText         = _ageCtrl.text.trim();
    final shopName        = _shopNameCtrl.text.trim();
    final containerNumber = _containerCtrl.text.trim();
    final localPhone      = _phoneCtrl.text.trim();
    final password        = _passwordCtrl.text;
    final passwordConfirm = _passwordConfirmCtrl.text;

    if (name.isEmpty) { _showSnack(loc.get('reg_err_name')); return; }
    final age = int.tryParse(ageText);
    if (age == null || age < 14 || age > 100) { _showSnack(loc.get('reg_err_age')); return; }
    if (_storeType == 'market' && (_marketName == null || _marketName!.isEmpty)) {
      _showSnack('Рынок тандаңыз'); return;
    }
    if (shopName.isEmpty && containerNumber.isEmpty) { _showSnack(loc.get('reg_err_container')); return; }
    if (localPhone.length < 9) { _showSnack(loc.get('reg_err_phone')); return; }

    final passError = SellerService.validatePassword(password);
    if (passError != null) { _showSnack(passError); return; }
    if (password != passwordConfirm) { _showSnack(loc.get('reg_err_pass_mismatch')); return; }

    setState(() => _isLoading = true);
    try {
      final formattedPhone = SellerAuthService.formatPhone(localPhone);
      await SellerAuthService.instance.register(
        phone: formattedPhone,
        password: password,
        fullName: name,
        age: age,
       containerNumber: containerNumber,
        shopName: shopName,
        storeType: _storeType,
        marketName: _storeType == 'market' ? _marketName : null,
      );
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const SellerPendingScreen()),
        (route) => false,
      );
    } catch (e) {
      debugPrint('SellerRegister error: $e');
      if (e is SellerPhoneTakenException) {
        if (mounted) _showSnack(e.toString());
      } else {
        if (mounted) _showSnack('${AppLocalizations.of(context).get('error')}: $e');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  InputDecoration _decoration(BuildContext context, {
    String? hint,
    String? prefixText,
    TextStyle? prefixStyle,
    Widget? suffixIcon,
  }) {
    final isDark   = Theme.of(context).brightness == Brightness.dark;
    final fillColor = isDark ? const Color(0xFF2C2C2C) : const Color(0xFFF7F7F7);
    return InputDecoration(
      hintText:    hint,
      prefixText:  prefixText,
      prefixStyle: prefixStyle,
      suffixIcon:  suffixIcon,
      filled:      true,
      fillColor:   fillColor,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
      ),
    );
  }

  Widget _label(BuildContext context, String text) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: AppTextStyles.labelLarge.copyWith(
          color: isDark ? const Color(0xFFCCCCCC) : AppColors.grey600,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc    = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final bgColor      = isDark ? const Color(0xFF121212) : Colors.white;
    final appBarColor  = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final arrowColor   = isDark ? Colors.white : AppColors.black;
    final titleColor   = isDark ? Colors.white : AppColors.black;
    final headingColor = isDark ? Colors.white : AppColors.black;
    final subColor     = isDark ? const Color(0xFFAAAAAA) : AppColors.grey500;
    final textColor    = isDark ? Colors.white : AppColors.black;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: appBarColor,
        elevation: 0,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Icon(Icons.arrow_back, color: arrowColor),
        ),
        title: Text(loc.get('reg_title'),
            style: AppTextStyles.headingMedium.copyWith(color: titleColor)),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 8),
              Text(loc.get('reg_heading'),
                  style: AppTextStyles.headingLarge.copyWith(color: headingColor)),
              const SizedBox(height: 8),
              Text(loc.get('reg_subheading'),
                  style: AppTextStyles.bodyMedium.copyWith(color: subColor)),
              const SizedBox(height: 28),

              // ── АТЫ-ЖӨНҮ ──
              _label(context, loc.get('reg_label_name')),
              TextField(
                controller: _nameCtrl,
                style: AppTextStyles.bodyMedium.copyWith(color: textColor),
                decoration: _decoration(context, hint: loc.get('reg_hint_name')),
              ),
              const SizedBox(height: 20),

              // ── ЖАШЫ ──
              _label(context, loc.get('reg_label_age')),
              TextField(
                controller: _ageCtrl,
                keyboardType: TextInputType.number,
                style: AppTextStyles.bodyMedium.copyWith(color: textColor),
                decoration: _decoration(context, hint: loc.get('reg_hint_age')),
              ),
              const SizedBox(height: 20),

              // ── КОНТЕЙНЕР ──
              _label(context, loc.get('reg_label_container')),
              TextField(
                controller: _containerCtrl,
                style: AppTextStyles.bodyMedium.copyWith(color: textColor),
                decoration: _decoration(context, hint: loc.get('reg_hint_container')),
              ),
              const SizedBox(height: 20),

              // ── ДҮКӨН АТЫ ──
              _label(context, loc.get('reg_label_shop')),
              TextField(
                controller: _shopNameCtrl,
                style: AppTextStyles.bodyMedium.copyWith(color: textColor),
                decoration: _decoration(context, hint: loc.get('reg_hint_shop')),
              ),
              const SizedBox(height: 20),



              // ── ДҮКӨН ТҮРҮ ──
              _label(context, 'Дүкөн түрүңүздү тандаңыз'),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() {
                        _storeType = 'market';
                        _marketName = 'Дордой базары';
                      }),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: _storeType == 'market'
                              ? AppColors.primary
                              : (isDark ? const Color(0xFF2C2C2C) : const Color(0xFFF7F7F7)),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          children: [
                            const Text('🏪', style: TextStyle(fontSize: 24)),
                            const SizedBox(height: 4),
                            Text(
                              'Рынок/Базар',
                              style: AppTextStyles.labelLarge.copyWith(
                                color: _storeType == 'market' ? Colors.white : textColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() {
                        _storeType = 'private';
                        _marketName = null;
                      }),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: _storeType == 'private'
                              ? AppColors.primary
                              : (isDark ? const Color(0xFF2C2C2C) : const Color(0xFFF7F7F7)),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          children: [
                            const Text('🏬', style: TextStyle(fontSize: 24)),
                            const SizedBox(height: 4),
                            Text(
                              'Жеке дүкөн',
                              style: AppTextStyles.labelLarge.copyWith(
                                color: _storeType == 'private' ? Colors.white : textColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // ── РЫНОК ТАНДОО (market болсо гана) ──
              if (_storeType == 'market') ...[
                _label(context, 'Рынок тандаңыз'),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF2C2C2C) : const Color(0xFFF7F7F7),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _marketName,
                      isExpanded: true,
                      dropdownColor: isDark ? const Color(0xFF2C2C2C) : Colors.white,
                      style: AppTextStyles.bodyMedium.copyWith(color: textColor),
                      items: _markets.map((m) => DropdownMenuItem(
                        value: m,
                        child: Text(m),
                      )).toList(),
                      onChanged: (val) => setState(() => _marketName = val),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],

              // ── ТЕЛЕФОН ──
              _label(context, loc.get('reg_label_phone')),
              TextField(
                controller: _phoneCtrl,
                keyboardType: TextInputType.phone,
                style: AppTextStyles.bodyMedium.copyWith(color: textColor),
                decoration: _decoration(context,
                  hint: '700123456',
                  prefixText: '+996  ',
                  prefixStyle: AppTextStyles.bodyMedium.copyWith(
                    fontWeight: FontWeight.w700,
                    color: textColor,
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // ── ПАРОЛЬ ──
              _label(context, loc.get('reg_label_pass')),
              TextField(
                controller: _passwordCtrl,
                obscureText: _obscure1,
                style: AppTextStyles.bodyMedium.copyWith(color: textColor),
                decoration: _decoration(context,
                  hint: loc.get('reg_hint_pass'),
                  suffixIcon: GestureDetector(
                    onTap: () => setState(() => _obscure1 = !_obscure1),
                    child: Icon(
                      _obscure1 ? Icons.visibility_off : Icons.visibility,
                      color: AppColors.grey400,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // ── ПАРОЛЬ КАЙТАЛОО ──
              _label(context, loc.get('reg_label_pass_confirm')),
              TextField(
                controller: _passwordConfirmCtrl,
                obscureText: _obscure2,
                onSubmitted: (_) => _register(),
                style: AppTextStyles.bodyMedium.copyWith(color: textColor),
                decoration: _decoration(context,
                  hint: '••••••••',
                  suffixIcon: GestureDetector(
                    onTap: () => setState(() => _obscure2 = !_obscure2),
                    child: Icon(
                      _obscure2 ? Icons.visibility_off : Icons.visibility,
                      color: AppColors.grey400,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // ── БАСКЫЧ ──
              SizedBox(
                height: 54,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _register,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    disabledBackgroundColor: AppColors.grey200,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 22, height: 22,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2.5),
                        )
                      : Text(
                          loc.get('reg_btn_open'),
                          style: AppTextStyles.labelLarge
                              .copyWith(color: Colors.white, fontSize: 16),
                        ),
                ),
              ),
              const SizedBox(height: 16),

              // ── КИРҮҮГӨ ӨТҮҮ ──
              Center(
                child: TextButton(
                  onPressed: () => Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => const SellerLoginScreen()),
                  ),
                  child: Text(
                    loc.get('reg_have_account'),
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}