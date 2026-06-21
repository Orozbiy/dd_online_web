// ═══════════════════════════════════════════════════════════════
// lib/features/seller/widgets/negotiation_toggle.dart
// SellerDashboardScreen'ге кошулат
// ═══════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import '../../../config/theme/app_colors.dart';
import '../../../config/theme/app_text_styles.dart';
import '../../../core/supabase_client.dart';

class NegotiationToggle extends StatefulWidget {
  final String ownerUid;   // сатуучунун uid'и

  const NegotiationToggle({super.key, required this.ownerUid});

  @override
  State<NegotiationToggle> createState() => _NegotiationToggleState();
}

class _NegotiationToggleState extends State<NegotiationToggle> {
  bool _hasNegotiation = false;
  bool _loading        = true;
  bool _saving         = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final row = await supabase
          .from('stores')
          .select('has_negotiation')
          .eq('owner_id', widget.ownerUid)
          .maybeSingle();

      if (mounted) {
        setState(() {
          _hasNegotiation = (row?['has_negotiation'] as bool?) ?? false;
          _loading        = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _toggle(bool value) async {
    if (_saving) return;
    setState(() {
      _hasNegotiation = value;
      _saving         = true;
    });

    try {
      // stores таблицасы
      await supabase
          .from('stores')
          .update({'has_negotiation': value})
          .eq('owner_id', widget.ownerUid);

      // profiles таблицасы (sellers = profiles)
      await supabase
          .from('profiles')
          .update({'has_negotiation': value})
          .eq('id', widget.ownerUid);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              value ? '🤝 Соодалашуу белгиси коюлду!' : '❌ Соодалашуу белгиси алынды',
            ),
            backgroundColor: value ? AppColors.success : AppColors.grey500,
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      // Ката болсо — кайтарабыз
      if (mounted) {
        setState(() => _hasNegotiation = !value);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('❌ Ката чыкты, кайра аракет кылыңыз'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark     = Theme.of(context).brightness == Brightness.dark;
    final cardBg     = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final titleColor = isDark ? Colors.white : AppColors.black;

    if (_loading) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Center(
          child: SizedBox(
            height: 20,
            width: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.primary,
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                )
              ],
        border: _hasNegotiation
            ? Border.all(color: AppColors.primary.withValues(alpha: 0.4), width: 1.5)
            : null,
      ),
      child: Row(
        children: [
          // Иконка
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: _hasNegotiation
                  ? AppColors.primary.withValues(alpha: 0.12)
                  : (isDark ? const Color(0xFF2C2C2C) : AppColors.grey100),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                '🤝',
                style: TextStyle(
                  fontSize: _hasNegotiation ? 24 : 22,
                ),
              ),
            ),
          ),

          const SizedBox(width: 14),

          // Текст
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Соодалашуу бар',
                  style: AppTextStyles.labelLarge.copyWith(color: titleColor),
                ),
                const SizedBox(height: 2),
                Text(
                  _hasNegotiation
                      ? '✅ Кардарлар баа түшүрүүнү билет'
                      : 'Баа боюнча макулдашса болот',
                  style: AppTextStyles.labelSmall.copyWith(
                    color: _hasNegotiation ? AppColors.success : AppColors.grey500,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),

          // Toggle
          _saving
              ? const SizedBox(
                  width: 36,
                  height: 20,
                  child: Center(
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                )
              : Switch(
                  value: _hasNegotiation,
                  onChanged: _toggle,
                  activeColor: AppColors.primary,
                ),
        ],
      ),
    );
  }
}
