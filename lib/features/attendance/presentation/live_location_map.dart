import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart' as ll;

import '../../../core/geo.dart';
import '../../../l10n/app_localizations.dart';
import '../../employee/providers/employee_providers.dart';

/// Live map preview shown above the clock-in/out button — visual, continuously
/// updating proof of where the device actually is, so an employee (or HR
/// reviewing a flagged attendance later) isn't relying only on the
/// out-of-radius note dialog that fires once at submit time.
///
/// This is a preview only: `_handleAction` in attendance_screen.dart takes
/// its own fresh GPS fix at submit time and remains the sole source of truth
/// for what's actually sent to the backend.
class LiveLocationMap extends ConsumerStatefulWidget {
  const LiveLocationMap({super.key});

  @override
  ConsumerState<LiveLocationMap> createState() => _LiveLocationMapState();
}

enum _LocationError { serviceDisabled, permissionDenied }

class _LiveLocationMapState extends ConsumerState<LiveLocationMap> {
  final _mapController = MapController();
  StreamSubscription<Position>? _positionSub;
  Position? _position;
  _LocationError? _error;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      if (mounted) setState(() => _error = _LocationError.serviceDisabled);
      return;
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
      if (mounted) setState(() => _error = _LocationError.permissionDenied);
      return;
    }

    final initial = await Geolocator.getCurrentPosition();
    if (!mounted) return;
    setState(() => _position = initial);
    _mapController.move(ll.LatLng(initial.latitude, initial.longitude), 17);

    _positionSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 5),
    ).listen((position) {
      if (!mounted) return;
      setState(() => _position = position);
      _mapController.move(
        ll.LatLng(position.latitude, position.longitude),
        _mapController.camera.zoom,
      );
    });
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;

    if (_error != null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(Icons.location_off_outlined, color: colorScheme.error),
              const SizedBox(width: 12),
              Expanded(
                child: Text(_error == _LocationError.serviceDisabled
                    ? t.locationServiceDisabledError
                    : t.locationPermissionDeniedError),
              ),
            ],
          ),
        ),
      );
    }

    final position = _position;
    if (position == null) {
      return const Card(
        child: SizedBox(height: 220, child: Center(child: CircularProgressIndicator())),
      );
    }

    final meAsync = ref.watch(myProfileProvider);
    final locationsAsync = ref.watch(locationListProvider);
    Map<String, dynamic>? office;
    final me = meAsync.value;
    final locations = locationsAsync.value;
    if (me != null && locations != null) {
      final locationId = me['location_id'] as int?;
      final matches = locations.where((l) => l['id'] == locationId);
      if (matches.isNotEmpty) office = matches.first;
    }

    double? distance;
    bool? withinRadius;
    ll.LatLng? officePoint;
    double officeRadius = 0;
    if (office != null) {
      final lat = (office['latitude'] as num).toDouble();
      final lng = (office['longitude'] as num).toDouble();
      officeRadius = (office['radius_meters'] as num).toDouble();
      officePoint = ll.LatLng(lat, lng);
      distance = distanceInMeters(position.latitude, position.longitude, lat, lng);
      withinRadius = distance <= officeRadius;
    }

    final Color statusColor;
    final Color onStatusColor;
    final IconData statusIcon;
    final String statusText;
    if (withinRadius == null) {
      statusColor = colorScheme.secondaryContainer;
      onStatusColor = colorScheme.onSecondaryContainer;
      statusIcon = Icons.info_outline;
      statusText = t.noLocationAssignedError;
    } else if (withinRadius) {
      statusColor = colorScheme.tertiaryContainer;
      onStatusColor = colorScheme.onTertiaryContainer;
      statusIcon = Icons.check_circle_outline;
      statusText = t.withinRadiusLabel;
    } else {
      statusColor = colorScheme.errorContainer;
      onStatusColor = colorScheme.onErrorContainer;
      statusIcon = Icons.error_outline;
      statusText = '${t.outsideRadiusLabel} (${distance!.round()} m)';
    }

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          SizedBox(
            height: 200,
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: ll.LatLng(position.latitude, position.longitude),
                initialZoom: 17,
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.talvio.talvio_mobile',
                ),
                if (officePoint != null)
                  CircleLayer(circles: [
                    CircleMarker(
                      point: officePoint,
                      radius: officeRadius,
                      useRadiusInMeter: true,
                      color: colorScheme.primary.withValues(alpha: 0.15),
                      borderColor: colorScheme.primary,
                      borderStrokeWidth: 2,
                    ),
                  ]),
                MarkerLayer(markers: [
                  if (officePoint != null)
                    Marker(
                      point: officePoint,
                      width: 32,
                      height: 32,
                      child: Icon(Icons.apartment, color: colorScheme.primary),
                    ),
                  Marker(
                    point: ll.LatLng(position.latitude, position.longitude),
                    width: 40,
                    height: 40,
                    child: Icon(Icons.my_location, color: colorScheme.error, size: 32),
                  ),
                ]),
              ],
            ),
          ),
          Container(
            width: double.infinity,
            color: statusColor,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                Icon(statusIcon, color: onStatusColor, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(statusText,
                      style: TextStyle(color: onStatusColor, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
