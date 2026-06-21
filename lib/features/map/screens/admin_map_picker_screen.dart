import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../config/theme/app_colors.dart';
import '../../../config/theme/app_text_styles.dart';
import '../../seller/models/seller_model.dart';
import '../../seller/services/seller_service.dart';

class AdminMapPickerScreen extends StatefulWidget {
  final SellerModel seller;

  const AdminMapPickerScreen({super.key, required this.seller});

  @override
  State<AdminMapPickerScreen> createState() => _AdminMapPickerScreenState();
}

class _AdminMapPickerScreenState extends State<AdminMapPickerScreen> {
  final _service = SellerService();
  bool _isSaving = false;

  final _latController = TextEditingController();
  final _lngController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.seller.hasLocation) {
      _latController.text = widget.seller.lat!.toStringAsFixed(6);
      _lngController.text = widget.seller.lng!.toStringAsFixed(6);
    }
  }

  @override
  void dispose() {
    _latController.dispose();
    _lngController.dispose();
    super.dispose();
  }

  Future<void> _openIn2GIS() async {
    // Дордой борборун 2ГИСте ачат — жайгашкан жерди тапкан соң
    // координаталарды кол менен киргизишет
    final uri = Uri.parse(
      'https://2gis.kg/bishkek/geo/74.5975,42.8953',
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _save() async {
    final latText = _latController.text.trim();
    final lngText = _lngController.text.trim();

    final lat = double.tryParse(latText);
    final lng = double.tryParse(lngText);

    if (lat == null || lng == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Координаталарды туура киргизиңиз'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    // Дордойдун чегинде экенин текшерүү
    if (lat < 42.88 || lat > 42.91 || lng < 74.58 || lng > 74.62) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ Координаталар Дордойдон алыс сыяктуу. Текшерип коюңуз.'),
          backgroundColor: AppColors.warning,
        ),
      );
    }

    setState(() => _isSaving = true);
    try {
      await _service.updateLocation(widget.seller.uid, lat, lng);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ ${widget.seller.shopName} локациясы сакталды!'),
            backgroundColor: AppColors.success,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      setState(() => _isSaving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Ката: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _removeLocation() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Локацияны өчүрүү',
            style: AppTextStyles.headingSmall),
        content: Text(
          '${widget.seller.shopName} дүкөнүнүн локациясын өчүрөсүзбү?',
          style: AppTextStyles.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Жок',
                style: TextStyle(color: AppColors.grey500)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Өчүрүү',
                style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    setState(() => _isSaving = true);
    try {
      await _service.removeLocation(widget.seller.uid);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🗑️ Локация өчүрүлдү'),
            backgroundColor: AppColors.error,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F5F7),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.grey100,
              borderRadius: BorderRadius.circular(10),
            ),
            child:
                const Icon(Icons.arrow_back, size: 20, color: Colors.black),
          ),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.seller.shopName,
                style: AppTextStyles.headingSmall,
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
            Text(
              widget.seller.containerNumber.isNotEmpty
                  ? 'Контейнер: ${widget.seller.containerNumber}'
                  : 'Локация кошуу',
              style: AppTextStyles.labelSmall
                  .copyWith(color: AppColors.grey500),
            ),
          ],
        ),
        actions: [
          if (widget.seller.hasLocation)
            GestureDetector(
              onTap: _isSaving ? null : _removeLocation,
              child: Container(
                margin: const EdgeInsets.only(right: 12),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.location_off,
                    color: AppColors.error, size: 20),
              ),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Нускама ──
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.info_outline,
                          color: AppColors.primary, size: 18),
                      SizedBox(width: 8),
                      Text('Координата кантип алынат?',
                          style: AppTextStyles.headingSmall),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _step('1',
                      'Төмөндөгү "2ГИС ачуу" баскычын басыңыз'),
                  const SizedBox(height: 8),
                  _step('2',
                      'Дүкөндүн жайгашкан жерин картадан табыңыз'),
                  const SizedBox(height: 8),
                  _step('3',
                      'Ошол жерге узак басып туруңуз (long press)'),
                  const SizedBox(height: 8),
                  _step('4',
                      'Координаталарды көчүрүп, төмөнкү талааларга чаптаңыз'),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ── 2ГИС баскычы ──
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton.icon(
                onPressed: _openIn2GIS,
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.primary),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.map_rounded,
                    color: AppColors.primary, size: 18),
                label: Text('2ГИС ачуу — Дордой',
                    style: AppTextStyles.labelLarge
                        .copyWith(color: AppColors.primary)),
              ),
            ),

            const SizedBox(height: 20),

            // ── Координата киргизүү ──
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Координаталарды киргизиңиз',
                      style: AppTextStyles.headingSmall),
                  const SizedBox(height: 16),

                  // Latitude
                  Text('Latitude (Кеңдик)',
                      style: AppTextStyles.labelMedium
                          .copyWith(color: AppColors.grey600)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _latController,
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true, signed: true),
                    style: AppTextStyles.bodyMedium,
                    decoration: InputDecoration(
                      hintText: 'Мисалы: 42.893456',
                      hintStyle: AppTextStyles.bodyMedium
                          .copyWith(color: AppColors.grey400),
                      filled: true,
                      fillColor: AppColors.grey100,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(
                            color: AppColors.primary, width: 1.5),
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Longitude
                  Text('Longitude (Узундук)',
                      style: AppTextStyles.labelMedium
                          .copyWith(color: AppColors.grey600)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _lngController,
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true, signed: true),
                    style: AppTextStyles.bodyMedium,
                    decoration: InputDecoration(
                      hintText: 'Мисалы: 74.612345',
                      hintStyle: AppTextStyles.bodyMedium
                          .copyWith(color: AppColors.grey400),
                      filled: true,
                      fillColor: AppColors.grey100,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(
                            color: AppColors.primary, width: 1.5),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ── Сактоо баскычы ──
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _isSaving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  disabledBackgroundColor: AppColors.grey300,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                icon: _isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.save_rounded,
                        size: 18, color: Colors.white),
                label: Text(
                  _isSaving ? 'Сакталып жатат...' : 'Локацияны сактоо',
                  style: AppTextStyles.headingSmall
                      .copyWith(color: Colors.white),
                ),
              ),
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _step(String num, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 22,
          height: 22,
          decoration: const BoxDecoration(
            color: AppColors.primary,
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Text(num,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.bold)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(text, style: AppTextStyles.bodyMedium),
        ),
      ],
    );
  }
}
