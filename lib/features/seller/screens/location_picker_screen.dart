import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
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

  bool _saving     = false;
  bool _editMode   = false;
  bool _gpsLoading = false;
  int  _countdown  = 0;
  Timer? _countdownTimer;
  double? _gpsLat;
  double? _gpsLng;

  double? _savedLat;
  double? _savedLng;

  bool get _hasSaved => _savedLat != null && _savedLng != null;

  @override
  void initState() {
    super.initState();
    _savedLat = widget.initialLat;
    _savedLng = widget.initialLng;
    _latCtrl  = TextEditingController(
        text: widget.initialLat?.toString() ?? '');
    _lngCtrl  = TextEditingController(
        text: widget.initialLng?.toString() ?? '');
    _editMode = !_hasSaved;
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _latCtrl.dispose();
    _lngCtrl.dispose();
    super.dispose();
  }

  bool get _isValid {
    final lat = double.tryParse(_latCtrl.text.trim());
    final lng = double.tryParse(_lngCtrl.text.trim());
    return lat != null &&
        lng != null &&
        lat >= -90 &&
        lat <= 90 &&
        lng >= -180 &&
        lng <= 180;
  }

  // ══════════════════════════════════════════════════════
  // GPS МЕНЕН АНЫКТОО
  // ══════════════════════════════════════════════════════
  Future<void> _detectGpsLocation() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }
    if (permission == LocationPermission.deniedForever) {
      await Geolocator.openAppSettings();
      return;
    }

    setState(() {
      _gpsLoading = true;
      _countdown  = 5;
      _editMode   = false; // GPS иштеп жатканда форманы жашыр
    });

    try {
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );
      _gpsLat = pos.latitude;
      _gpsLng = pos.longitude;
    } catch (e) {
      if (mounted) {
        setState(() => _gpsLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ GPS аныктоодо ката чыкты'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    _countdownTimer =
        Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() => _countdown--);

      if (_countdown <= 0) {
        timer.cancel();

        try {
          final finalPos = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.high,
            timeLimit: const Duration(seconds: 5),
          );
          _gpsLat = finalPos.latitude;
          _gpsLng = finalPos.longitude;
        } catch (_) {}

        if (mounted) {
          setState(() {
            _latCtrl.text = _gpsLat!.toStringAsFixed(6);
            _lngCtrl.text = _gpsLng!.toStringAsFixed(6);
            _gpsLoading   = false;
            _editMode     = false;
          });
        }

        await _saveLocation();
      }
    });
  }

  // ══════════════════════════════════════════════════════
  // КОЛ МЕНЕН САКТОО
  // ══════════════════════════════════════════════════════
  Future<void> _saveLocation() async {
    final loc = AppLocalizations.of(context);
    if (!_isValid) return;
    setState(() => _saving = true);
    try {
      final uid = supabase.auth.currentUser!.id;
      final lat = double.parse(_latCtrl.text.trim());
      final lng = double.parse(_lngCtrl.text.trim());
      await _service.updateLocation(uid, lat, lng);
      setState(() {
        _savedLat = lat;
        _savedLng = lng;
        _editMode = false;
      });
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

    final bgColor     = isDark ? const Color(0xFF121212) : Colors.white;
    final appBarColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final arrowColor  = isDark ? Colors.white : AppColors.black;
    final titleColor  = isDark ? Colors.white : AppColors.black;
    final subColor    = isDark ? const Color(0xFF888888) : AppColors.grey400;
    final labelColor  = isDark ? const Color(0xFFAAAAAA) : AppColors.grey500;
    final textColor   = isDark ? Colors.white : AppColors.black;
    final fieldFill   = isDark ? const Color(0xFF2C2C2C) : Colors.white;
    final lngLabelColor =
        isDark ? const Color(0xFFAAAAAA) : const Color(0xFF2A4264);

    final savedBg =
        isDark ? const Color(0xFF0D2B1A) : const Color(0xFFF0FFF4);
    final savedBorder =
        const Color(0xFF22C55E).withValues(alpha: isDark ? 0.5 : 0.4);

    final instrBg =
        AppColors.primary.withValues(alpha: isDark ? 0.12 : 0.08);
    final instrBorder =
        AppColors.primary.withValues(alpha: isDark ? 0.3 : 0.2);
    final instrText =
        isDark ? const Color(0xFFCCCCCC) : AppColors.grey600;

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
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(loc.get('loc_saved_label'),
                            style: AppTextStyles.labelLarge
                                .copyWith(color: const Color(0xFF16A34A))),
                        const SizedBox(height: 4),
                        Text(
                          'Lat: ${_savedLat!.toStringAsFixed(6)}\n'
                          'Lng: ${_savedLng!.toStringAsFixed(6)}',
                          style: AppTextStyles.bodySmall
                              .copyWith(color: AppColors.grey500),
                        ),
                      ],
                    ),
                  ),
                ]),
              ),
              const SizedBox(height: 16),
            ],

            // ── GPS САНАК ИНДИКАТОРУ (ар дайым жогорудо) ──
            if (_gpsLoading) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF16A34A).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: const Color(0xFF16A34A).withValues(alpha: 0.3)),
                ),
                child: Column(children: [
                  if (_countdown > 0) ...[
                    Text(
                      '$_countdown',
                      style: const TextStyle(
                        fontSize: 56,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF16A34A),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '📍 Жылбаңыз!',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF16A34A),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Телефонду кармап, бир жерде туруңуз',
                      style: AppTextStyles.bodySmall
                          .copyWith(color: AppColors.grey500),
                      textAlign: TextAlign.center,
                    ),
                  ] else ...[
                    const CircularProgressIndicator(
                        color: Color(0xFF16A34A)),
                    const SizedBox(height: 12),
                    Text(
                      '📍 Жайгашкан жер аныкталууда...',
                      style: AppTextStyles.labelLarge
                          .copyWith(color: const Color(0xFF16A34A)),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ]),
              ),
              const SizedBox(height: 16),
            ],

            // ── GPS БАСКЫЧЫ (gpsLoading жок болгондо ар дайым көрүнөт) ──
            if (!_gpsLoading) ...[
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton.icon(
                  onPressed: _detectGpsLocation,
                  icon: const Icon(Icons.my_location_rounded,
                      color: Colors.white),
                  label: const Text(
                    '📍  GPS менен аныктоо',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF16A34A),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],

            // ── ФОРМА (кол менен жазуу) ──
            if (_editMode && !_gpsLoading) ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: instrBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: instrBorder),
                ),
                child: Text(loc.get('loc_instructions'),
                    style: AppTextStyles.bodySmall
                        .copyWith(color: instrText, height: 1.6)),
              ),
              const SizedBox(height: 20),

              Text('Latitude',
                  style: AppTextStyles.labelMedium
                      .copyWith(color: labelColor)),
              const SizedBox(height: 8),
              TextField(
                controller: _latCtrl,
                keyboardType: const TextInputType.numberWithOptions(
                    decimal: true, signed: true),
                style: AppTextStyles.bodyMedium.copyWith(color: textColor),
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: '42.895300',
                  hintStyle: TextStyle(
                      color: isDark
                          ? const Color(0xFF555555)
                          : AppColors.grey400),
                  filled: true,
                  fillColor: fieldFill,
                  prefixIcon:
                      const Icon(Icons.north, color: AppColors.primary),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                        color: isDark
                            ? const Color(0xFF3A3A3A)
                            : AppColors.grey300),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                        color: isDark
                            ? const Color(0xFF3A3A3A)
                            : AppColors.grey300),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        const BorderSide(color: AppColors.primary, width: 2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              Text('Longitude',
                  style: AppTextStyles.labelMedium
                      .copyWith(color: lngLabelColor)),
              const SizedBox(height: 8),
              TextField(
                controller: _lngCtrl,
                keyboardType: const TextInputType.numberWithOptions(
                    decimal: true, signed: true),
                style: AppTextStyles.bodyMedium.copyWith(color: textColor),
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: '74.597500',
                  hintStyle: TextStyle(
                      color: isDark
                          ? const Color(0xFF555555)
                          : AppColors.grey400),
                  filled: true,
                  fillColor: fieldFill,
                  prefixIcon:
                      const Icon(Icons.east, color: AppColors.primary),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                        color: isDark
                            ? const Color(0xFF3A3A3A)
                            : AppColors.grey300),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                        color: isDark
                            ? const Color(0xFF3A3A3A)
                            : AppColors.grey300),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        const BorderSide(color: AppColors.primary, width: 2),
                  ),
                ),
              ),
              const Spacer(),

              if (_hasSaved)
                TextButton(
                  onPressed: () => setState(() => _editMode = false),
                  child: Text(loc.get('cancel'),
                      style: AppTextStyles.labelMedium
                          .copyWith(color: AppColors.grey500)),
                ),

              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: (_isValid && !_saving) ? _saveLocation : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    disabledBackgroundColor: AppColors.grey200,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  child: _saving
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2.5))
                      : Text('📍  ${loc.get('save')}',
                          style: AppTextStyles.labelLarge
                              .copyWith(color: Colors.white, fontSize: 16)),
                ),
              ),
              SizedBox(height: bottomPad + 8),
            ],

            // ── КОЛ МЕНЕН ӨЗГӨРТҮҮ БАСКЫЧЫ (editMode жок болгондо) ──
            if (!_editMode && !_gpsLoading) ...[
              const Spacer(),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: OutlinedButton.icon(
                  onPressed: () => setState(() => _editMode = true),
                  icon: const Icon(Icons.edit_location_alt_outlined,
                      color: AppColors.primary),
                  label: Text(loc.get('loc_edit'),
                      style: AppTextStyles.labelLarge
                          .copyWith(color: AppColors.primary)),
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    side: const BorderSide(
                        color: AppColors.primary, width: 1.5),
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