import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart' as latlong;

import '../../core/constants/app_colors.dart';

/// نتيجة اختيار الموقع
class PickedLocation {
  const PickedLocation({required this.latitude, required this.longitude});

  final double latitude;
  final double longitude;
}

/// مركز افتراضي (الرياض) حين يتعذّر تحديد موقع الجهاز ولم يُمرَّر موقع أولي
const _defaultCenter = latlong.LatLng(24.7136, 46.6753);

/// شاشة تحديد الموقع على خريطة — خريطة مجانية (OpenStreetMap عبر
/// flutter_map) بلا أي مفتاح API أو حساب فوترة، بعكس Google Maps SDK.
///
/// العميل يحرّك الخريطة تحت دبّوس ثابت في المنتصف (نمط شائع يتفادى تعارض
/// سحب الدبّوس مع تحريك الخريطة)، أو يضغط "استخدام موقعي الحالي" لجلب
/// إحداثيات GPS الجهاز فعلياً. عند التأكيد تُعاد الإحداثيات فقط —
/// الإدارة تفتحها لاحقاً في خرائط جوجل عبر رابط عادي (لا حاجة لأي SDK
/// خرائط على جهة العرض أيضاً).
class LocationPickerScreen extends StatefulWidget {
  const LocationPickerScreen({super.key, this.initialLatitude, this.initialLongitude});

  final double? initialLatitude;
  final double? initialLongitude;

  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  final MapController _mapController = MapController();
  latlong.LatLng _center = _defaultCenter;
  bool _locating = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.initialLatitude != null && widget.initialLongitude != null) {
      _center = latlong.LatLng(widget.initialLatitude!, widget.initialLongitude!);
    } else {
      _useCurrentLocation(silent: true);
    }
  }

  Future<void> _useCurrentLocation({bool silent = false}) async {
    setState(() {
      _locating = true;
      _error = null;
    });
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception('خدمة الموقع غير مفعّلة على جهازك');
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw Exception('لم تُمنح صلاحية الوصول للموقع');
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
      if (!mounted) return;
      final target = latlong.LatLng(position.latitude, position.longitude);
      setState(() => _center = target);
      _mapController.move(target, 16);
    } catch (e) {
      if (!mounted) return;
      // بصمت عند المحاولة التلقائية أول فتح للشاشة — الخريطة تبقى على
      // المركز الافتراضي بدل عرض خطأ فوري قبل أي تفاعل من المستخدم
      if (!silent) {
        setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  void _confirm() {
    Navigator.pop(
      context,
      PickedLocation(latitude: _center.latitude, longitude: _center.longitude),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('تحديد موقع التوصيل')),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _center,
              initialZoom: 14,
              onPositionChanged: (position, hasGesture) {
                if (hasGesture) _center = position.center;
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.alarabi.alarabi_crystal',
              ),
            ],
          ),
          // دبّوس ثابت بمنتصف الشاشة — الخريطة هي التي تتحرك تحته
          const IgnorePointer(
            child: Center(
              child: Padding(
                padding: EdgeInsets.only(bottom: 36),
                child: Icon(Icons.location_on, size: 44, color: AppColors.secondary),
              ),
            ),
          ),
          if (_error != null)
            Positioned(
              top: 12,
              left: 12,
              right: 12,
              child: Material(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(_error!, style: TextStyle(color: Colors.red.shade900)),
                ),
              ),
            ),
          Positioned(
            bottom: 90,
            left: 12,
            child: FloatingActionButton.small(
              heroTag: 'use-current-location',
              backgroundColor: Colors.white,
              foregroundColor: AppColors.secondary,
              onPressed: _locating ? null : () => _useCurrentLocation(),
              child: _locating
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.my_location),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: ElevatedButton.icon(
            onPressed: _confirm,
            icon: const Icon(Icons.check),
            label: const Text('تأكيد هذا الموقع'),
          ),
        ),
      ),
    );
  }
}
