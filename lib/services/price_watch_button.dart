import 'package:flutter/material.dart';
import '../../../config/theme/app_colors.dart';
import '../../../config/theme/app_text_styles.dart';
import '../../../core/supabase_client.dart';

class PriceWatchButton extends StatefulWidget {
  final String productId;
  const PriceWatchButton({super.key, required this.productId});

  @override
  State<PriceWatchButton> createState() => _PriceWatchButtonState();
}

class _PriceWatchButtonState extends State<PriceWatchButton> {
  bool _watching = false;
  bool _loading  = true;

  @override
  void initState() {
    super.initState();
    _checkStatus();
  }

  Future<void> _checkStatus() async {
    final user = supabase.auth.currentUser;
    if (user == null) { setState(() => _loading = false); return; }
    try {
      final rows = await supabase
          .from('price_watch')
          .select('id')
          .eq('product_id', widget.productId)
          .eq('user_id', user.id);
      setState(() {
        _watching = (rows as List).isNotEmpty;
        _loading  = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  Future<void> _toggle() async {
    final user = supabase.auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Кирүү керек!')),
      );
      return;
    }
    setState(() => _loading = true);
    try {
      if (_watching) {
        await supabase
            .from('price_watch')
            .delete()
            .eq('product_id', widget.productId)
            .eq('user_id', user.id);
        setState(() => _watching = false);
      } else {
        await supabase.from('price_watch').insert({
          'product_id': widget.productId,
          'user_id':    user.id,
        });
        setState(() => _watching = true);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('🔔 Баа түшсө кабарлама келет!'),
              backgroundColor: Color(0xFF16A34A),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ката: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _loading ? null : _toggle,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: _watching
              ? const Color(0xFFEFF6FF)
              : const Color(0xFFFFF8F0),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _watching ? Colors.blue : AppColors.primary,
          ),
        ),
        child: _loading
            ? const SizedBox(
                width: 18, height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(
                  _watching ? Icons.notifications_active : Icons.notifications_none,
                  size: 18,
                  color: _watching ? Colors.blue : AppColors.primary,
                ),
                const SizedBox(width: 6),
                Text(
                  _watching ? 'Күтүүдө 🔔' : 'Баа түшсө кабарла',
                  style: AppTextStyles.labelSmall.copyWith(
                    color: _watching ? Colors.blue : AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ]),
      ),
    );
  }
}