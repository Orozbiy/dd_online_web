import 'package:flutter/material.dart';
import '../../../config/theme/app_colors.dart';
import '../../../config/theme/app_text_styles.dart';
import '../../../core/app_localizations.dart';
import '../../../core/supabase_client.dart';

class WorkingHoursSheet extends StatefulWidget {
  final String sellerUid;
  final String? initialStart;
  final String? initialEnd;
  final String? initialDays;

  const WorkingHoursSheet({
    super.key,
    required this.sellerUid,
    this.initialStart,
    this.initialEnd,
    this.initialDays,
  });

  @override
  State<WorkingHoursSheet> createState() => _WorkingHoursSheetState();
}

class _WorkingHoursSheetState extends State<WorkingHoursSheet> {
  late TimeOfDay _start;
  late TimeOfDay _end;
  late String    _days;
  bool _saving = false;

  static const _dayKeys = [
    'hours_mon_fri', 'hours_mon_sat', 'hours_mon_sun', 'hours_no_sun', 'hours_daily',
  ];
  static const _dayValues = [
    'Дш-Жм', 'Дш-Шб', 'Дш-Жк', 'Жк күн эмес', 'Күн сайын',
  ];

  @override
  void initState() {
    super.initState();
    _start = _parseTime(widget.initialStart ?? '09:00');
    _end   = _parseTime(widget.initialEnd   ?? '18:00');
    _days  = widget.initialDays ?? _dayValues[0];
  }

  TimeOfDay _parseTime(String t) {
    final parts = t.split(':');
    return TimeOfDay(hour: int.tryParse(parts[0]) ?? 9, minute: int.tryParse(parts[1]) ?? 0);
  }

  String _fmt(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  Future<void> _pickTime({required bool isStart}) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: isStart ? _start : _end,
      builder: (ctx, child) => MediaQuery(
        data: MediaQuery.of(ctx).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (picked == null) return;
    setState(() { if (isStart) _start = picked; else _end = picked; });
  }

  Future<void> _save() async {
    final loc = AppLocalizations.of(context);
    setState(() => _saving = true);
    try {
      await supabase.from('stores').update({
        'work_start': _fmt(_start),
        'work_end':   _fmt(_end),
        'work_days':  _days,
      }).eq('owner_id', widget.sellerUid);

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(loc.get('hours_saved')), backgroundColor: AppColors.success),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ ${loc.get('error')}: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc    = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final sheetBg    = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final headColor  = isDark ? Colors.white : AppColors.black;
    final chipUnsel  = isDark ? const Color(0xFF2C2C2C) : AppColors.grey100;
    final chipText   = isDark ? Colors.white70 : AppColors.grey600;
    final previewBg  = AppColors.primary.withValues(alpha: isDark ? 0.12 : 0.07);
    final previewBdr = AppColors.primary.withValues(alpha: isDark ? 0.3 : 0.2);

    return Container(
      decoration: BoxDecoration(
        color: sheetBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(context).padding.bottom + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Ручка ──
          Center(child: Container(
            width: 40, height: 4,
            decoration: BoxDecoration(color: AppColors.grey300, borderRadius: BorderRadius.circular(2)),
          )),
          const SizedBox(height: 16),

          Text('🕐 ${loc.get('dash_hours')}',
              style: AppTextStyles.headingSmall.copyWith(color: headColor)),
          const SizedBox(height: 20),

          // ── Башталуу — Аяктоо ──
          Row(children: [
            Expanded(child: _TimeCard(label: loc.get('hours_start'), time: _fmt(_start), onTap: () => _pickTime(isStart: true))),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text('—', style: TextStyle(fontSize: 22, color: isDark ? Colors.white38 : AppColors.grey400)),
            ),
            Expanded(child: _TimeCard(label: loc.get('hours_end'), time: _fmt(_end), onTap: () => _pickTime(isStart: false))),
          ]),
          const SizedBox(height: 20),

          // ── Жумуш күндөрү ──
          Text(loc.get('hours_workdays'),
              style: AppTextStyles.labelLarge.copyWith(color: headColor)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8, runSpacing: 8,
            children: List.generate(_dayKeys.length, (i) {
              final value    = _dayValues[i];
              final label    = loc.get(_dayKeys[i]);
              final selected = _days == value;
              return GestureDetector(
                onTap: () => setState(() => _days = value),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: selected ? AppColors.primary : chipUnsel,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: selected ? AppColors.primary : Colors.transparent),
                  ),
                  child: Text(label, style: AppTextStyles.labelSmall.copyWith(
                    color: selected ? Colors.white : chipText,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                  )),
                ),
              );
            }),
          ),
          const SizedBox(height: 24),

          // ── Алдын ала көрүнүш ──
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: previewBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: previewBdr),
            ),
            child: Row(children: [
              const Icon(Icons.access_time_rounded, color: AppColors.primary, size: 18),
              const SizedBox(width: 8),
              Text(
                '${loc.get(_dayKeys[_dayValues.indexOf(_days)])}  ${_fmt(_start)} — ${_fmt(_end)}',
                style: AppTextStyles.labelLarge.copyWith(color: AppColors.primary),
              ),
            ]),
          ),
          const SizedBox(height: 20),

          // ── Сактоо баскычы ──
          SizedBox(
            width: double.infinity, height: 52,
            child: ElevatedButton(
              onPressed: _saving ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
              child: _saving
                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Text(loc.get('save'), style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Убакыт карточкасы ──
class _TimeCard extends StatelessWidget {
  final String label;
  final String time;
  final VoidCallback onTap;

  const _TimeCard({required this.label, required this.time, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark    = Theme.of(context).brightness == Brightness.dark;
    final cardBg    = isDark ? const Color(0xFF2C2C2C) : AppColors.grey100;
    final cardBdr   = isDark ? const Color(0xFF3A3A3A) : AppColors.grey200;
    final timeColor = isDark ? Colors.white : AppColors.black;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: cardBdr),
        ),
        child: Column(children: [
          Text(label, style: AppTextStyles.labelSmall.copyWith(color: AppColors.grey500)),
          const SizedBox(height: 6),
          Text(time, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: timeColor)),
          const SizedBox(height: 4),
          const Icon(Icons.edit_outlined, size: 14, color: AppColors.grey400),
        ]),
      ),
    );
  }
}