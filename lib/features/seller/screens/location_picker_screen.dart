import 'package:flutter/material.dart';
import '../../../config/theme/app_colors.dart';
import '../../../config/theme/app_text_styles.dart';
import '../../../core/app_localizations.dart';
import '../services/seller_service.dart';
import '../../../core/supabase_client.dart';

class LocationPickerScreen extends StatefulWidget {
  final String shopName;
  final String sellerUid;
  final double? initialLat;
  final double? initialLng;

  const LocationPickerScreen({
    super.key,
    required this.shopName,
    required this.sellerUid,
    this.initialLat,
    this.initialLng,
  });

  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  final _service = SellerService();
  late TextEditingController _latCtrl;
  late TextEditingController _lngCtrl;
  bool _saving   = false;
  bool _editMode = false;

  double? _savedLat;
  double? _savedLng;

  bool get _hasSaved => _savedLat != null && _savedLng != null;

  @override
  void initState() {
    super.initState();
    _savedLat = widget.initialLat;
    _savedLng = widget.initialLng;
    _latCtrl  = TextEditingController(text: widget.initialLat?.toString() ?? '');
    _lngCtrl  = TextEditingController(text: widget.initialLng?.toString() ?? '');
    _editMode = !_hasSaved;
  }

  @override
  void dispose() {
    _latCtrl.dispose();
    _lngCtrl.dispose();
    super.dispose();
  }

  bool get _isValid {
    final lat = double.tryParse(_latCtrl.text.trim());
    final lng = double.tryParse(_lngCtrl.text.trim());
    return lat != null && lng != null &&
        lat >= -90 && lat <= 90 &&
        lng >= -180 && lng <= 180;
  }

  Future<void> _saveLocation() async {
    final loc = AppLocalizations.of(context);
    if (!_isValid) return;
    setState(() => _saving = true);
    try {
      final uid = supabase.auth.currentUser!.id;
      final lat = double.parse(_latCtrl.text.trim());
      final lng = double.parse(_lngCtrl.text.trim());
      await _service.updateLocation(uid, lat, lng);
      setState(() { _savedLat = lat; _savedLng = lng; _editMode = false; });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(loc.get('loc_saved')),
          backgroundColor: const Color(0xFF16A34A),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('${AppLocalizations.of(context).get('error')}: $e'),
          backgroundColor: AppColors.error,
        ));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc       = AppLocalizations.of(context);
    final isDark    = Theme.of(context).brightness == Brightness.dark;
    final bottomPad = MediaQuery.of(context).padding.bottom;

    final bgColor      = isDark ? const Color(0xFF121212) : Colors.white;
    final appBarColor  = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final arrowColor   = isDark ? Colors.white : AppColors.black;
    final titleColor   = isDark ? Colors.white : AppColors.black;
    final subColor     = isDark ? const Color(0xFF888888) : AppColors.grey400;
    final labelColor   = isDark ? const Color(0xFFAAAAAA) : AppColors.grey500;
    final textColor    = isDark ? Colors.white : AppColors.black;
    final fieldFill    = isDark ? const Color(0xFF2C2C2C) : Colors.white;

    // Сакталган локация карточкасы
    final savedBg     = isDark ? const Color(0xFF0D2B1A) : const Color(0xFFF0FFF4);
    final savedBorder = const Color(0xFF22C55E).withValues(alpha: isDark ? 0.5 : 0.4);

    // Нускамалар карточкасы
    final instrBg     = AppColors.primary.withValues(alpha: isDark ? 0.12 : 0.08);
    final instrBorder = AppColors.primary.withValues(alpha: isDark ? 0.3 : 0.2);
    final instrText   = isDark ? const Color(0xFFCCCCCC) : AppColors.grey600;

    // Longitude label — мурда катуу кара болчу
    final lngLabelColor = isDark ? const Color(0xFFAAAAAA) : const Color(0xFF2A4264);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: appBarColor,
        elevation: 0,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Icon(Icons.arrow_back, color: arrowColor),
        ),
        title: Column(children: [
          Text(widget.shopName,
              style: AppTextStyles.headingSmall.copyWith(color: titleColor)),
          Text(loc.get('dash_location'),
              style: AppTextStyles.bodySmall.copyWith(color: subColor)),
        ]),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // ── САКТАЛГАН ЛОКАЦИЯ ──
            if (_hasSaved) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: savedBg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: savedBorder),
                ),
                child: Row(children: [
                  const Text('✅', style: TextStyle(fontSize: 22)),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(loc.get('loc_saved_label'),
                        style: AppTextStyles.labelLarge.copyWith(color: const Color(0xFF16A34A))),
                    const SizedBox(height: 4),
                    Text(
                      'Lat: ${_savedLat!.toStringAsFixed(6)}\nLng: ${_savedLng!.toStringAsFixed(6)}',
                      style: AppTextStyles.bodySmall.copyWith(color: AppColors.grey500),
                    ),
                  ])),
                ]),
              ),
              const SizedBox(height: 16),
            ],

            // ── ФОРМА ──
            if (_editMode) ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: instrBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: instrBorder),
                ),
                child: Text(loc.get('loc_instructions'),
                    style: AppTextStyles.bodySmall.copyWith(color: instrText, height: 1.6)),
              ),
              const SizedBox(height: 20),

              Text('Latitude', style: AppTextStyles.labelMedium.copyWith(color: labelColor)),
              const SizedBox(height: 8),
              TextField(
                controller: _latCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                style: AppTextStyles.bodyMedium.copyWith(color: textColor),
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: '42.895300',
                  hintStyle: TextStyle(color: isDark ? const Color(0xFF555555) : AppColors.grey400),
                  filled: true,
                  fillColor: fieldFill,
                  prefixIcon: const Icon(Icons.north, color: AppColors.primary),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: isDark ? const Color(0xFF3A3A3A) : AppColors.grey300),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: isDark ? const Color(0xFF3A3A3A) : AppColors.grey300),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.primary, width: 2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              Text('Longitude', style: AppTextStyles.labelMedium.copyWith(color: lngLabelColor)),
              const SizedBox(height: 8),
              TextField(
                controller: _lngCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                style: AppTextStyles.bodyMedium.copyWith(color: textColor),
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: '74.597500',
                  hintStyle: TextStyle(color: isDark ? const Color(0xFF555555) : AppColors.grey400),
                  filled: true,
                  fillColor: fieldFill,
                  prefixIcon: const Icon(Icons.east, color: AppColors.primary),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: isDark ? const Color(0xFF3A3A3A) : AppColors.grey300),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: isDark ? const Color(0xFF3A3A3A) : AppColors.grey300),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.primary, width: 2),
                  ),
                ),
              ),
              const Spacer(),

              if (_hasSaved)
                TextButton(
                  onPressed: () => setState(() => _editMode = false),
                  child: Text(loc.get('cancel'),
                      style: AppTextStyles.labelMedium.copyWith(color: AppColors.grey500)),
                ),

              SizedBox(
                width: double.infinity, height: 54,
                child: ElevatedButton(
                  onPressed: (_isValid && !_saving) ? _saveLocation : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    disabledBackgroundColor: AppColors.grey200,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  child: _saving
                      ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                      : Text('📍  ${loc.get('save')}',
                          style: AppTextStyles.labelLarge.copyWith(color: Colors.white, fontSize: 16)),
                ),
              ),
              SizedBox(height: bottomPad + 8),
            ],

            // ── ӨЗГӨРТҮҮ БАСКЫЧЫ ──
            if (!_editMode) ...[
              const Spacer(),
              SizedBox(
                width: double.infinity, height: 52,
                child: OutlinedButton.icon(
                  onPressed: () => setState(() => _editMode = true),
                  icon: const Icon(Icons.edit_location_alt_outlined, color: AppColors.primary),
                  label: Text(loc.get('loc_edit'),
                      style: AppTextStyles.labelLarge.copyWith(color: AppColors.primary)),
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    side: const BorderSide(color: AppColors.primary, width: 1.5),
                  ),
                ),
              ),
              SizedBox(height: bottomPad + 8),
            ],
          ],
        ),
      ),
    );
  }
}