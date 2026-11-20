import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart' as ll;

import '../../../l10n/app_localizations.dart';

/// Full-screen map picker for onboarding step 1 ("Lokasi kantor" in figma —
/// "Pilih di peta" pill). Center-pin pattern: the marker stays fixed in the
/// middle of the screen and the map pans underneath it, so the picked point
/// is always exactly the camera center — no marker-drag gesture to get wrong.
class OfficeLocationPicker extends StatefulWidget {
  const OfficeLocationPicker({super.key, this.initial});

  final ll.LatLng? initial;

  @override
  State<OfficeLocationPicker> createState() => _OfficeLocationPickerState();
}

class _OfficeLocationPickerState extends State<OfficeLocationPicker> {
  final _mapController = MapController();
  late ll.LatLng _center = widget.initial ?? const ll.LatLng(-6.2088, 106.8456); // Jakarta default

  @override
  void initState() {
    super.initState();
    if (widget.initial == null) _useCurrentLocation();
  }

  Future<void> _useCurrentLocation() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return;
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return;
      }
      final position = await Geolocator.getCurrentPosition();
      if (!mounted) return;
      final point = ll.LatLng(position.latitude, position.longitude);
      setState(() => _center = point);
      _mapController.move(point, 16);
    } catch (_) {
      // Lokasi device gagal diambil — biarkan default Jakarta, pengguna
      // tetap bisa geser peta manual.
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(t.mapPickerTitle)),
      body: Stack(
        alignment: Alignment.center,
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _center,
              initialZoom: 16,
              onPositionChanged: (position, hasGesture) {
                if (hasGesture) setState(() => _center = position.center);
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.talvio.talvio_mobile',
              ),
            ],
          ),
          // Pin tetap di tengah layar — bukan Marker di layer peta, supaya
          // posisinya selalu persis titik tengah berapa pun peta digeser.
          Icon(Icons.location_on, size: 44, color: Theme.of(context).colorScheme.error),
          Positioned(
            right: 16,
            bottom: 96,
            child: FloatingActionButton.small(
              heroTag: 'office-location-my-location',
              onPressed: _useCurrentLocation,
              child: const Icon(Icons.my_location),
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 24,
            child: FilledButton(
              onPressed: () => Navigator.of(context).pop(_center),
              child: Text(t.mapPickerConfirmButton),
            ),
          ),
        ],
      ),
    );
  }
}
