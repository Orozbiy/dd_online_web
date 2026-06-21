import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../../../config/theme/app_colors.dart';
import '../../../config/theme/app_text_styles.dart';
import '../../../core/supabase_client.dart';

/// Сатуучу дүкөнүнүн картадагы жайгашкан жерин (latitude/longitude)
/// учурдагы GPS позиция боюнча сактоо экраны.
class StoreLocationScreen extends StatefulWidget {
  final String storeId;
  final double? initialLat;
  final double? initialLng;

  const StoreLocationScreen({
    super.key,
    required this.storeId,
    this.initialLat,
    this.initialLng,
  });

  @override
  State<StoreLocationScreen> createState() => _StoreLocationScreenState();
}

class _StoreLocationScreenState extends State<StoreLocationScreen> {
  bool _loading = false;
  double? _lat;
  double? _lng;

  @override
  void initState() {
    super.initState();
    _lat = widget.initialLat;
    _lng = widget.initialLng;
  }

  Future<void> _detectAndSave() async {
    setState(() => _loading = true);

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      _showSnack('Жайгашкан жерге уруксат бериңиз', isError: true);
      setState(() => _loading = false);
      return;
    }

    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _showSnack('GPS өчүк, аны күйгүзүңүз', isError: true);
      setState(() => _loading = false);
      return;
    }

    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      await supabase.from('stores').update({
        'latitude': position.latitude,
        'longitude': position.longitude,
      }).eq('id', widget.storeId);

      if (!mounted) return;
      setState(() {
        _lat = position.latitude;
        _lng = position.longitude;
      });
      _showSnack('Жайгашкан жер сакталды!');
    } catch (e) {
      _showSnack('Ката: $e', isError: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? AppColors.error : AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasLocation = _lat != null && _lng != null;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F5F7),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text('Дүкөндүн жайгашкан жери', style: AppTextStyles.headingSmall),
        iconTheme: const IconThemeData(color: AppColors.black),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.grey200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.location_on, color: AppColors.primary),
                      const SizedBox(width: 8),
                      Text('Учурдагы координат', style: AppTextStyles.labelLarge),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (hasLocation) ...[
                    Text('Latitude: ${_lat!.toStringAsFixed(6)}',
                        style: AppTextStyles.bodyMedium),
                    Text('Longitude: ${_lng!.toStringAsFixed(6)}',
                        style: AppTextStyles.bodyMedium),
                  ] else
                    Text('Жайгашкан жер али сакталган эмес',
                        style: AppTextStyles.bodyMedium
                            .copyWith(color: AppColors.grey500)),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Дүкөнүңүздө туруп, төмөнкү баскычты басыңыз. '
              'Учурдагы GPS позицияңыз дүкөндүн жайгашкан жери катары сакталат.',
              style: AppTextStyles.bodyMedium.copyWith(color: AppColors.grey500),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _loading ? null : _detectAndSave,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                icon: _loading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.my_location, color: Colors.white),
                label: Text(
                  hasLocation ? 'Жайгашкан жерди жаңыртуу' : 'Жайгашкан жерди сактоо',
                  style: AppTextStyles.headingSmall.copyWith(color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}