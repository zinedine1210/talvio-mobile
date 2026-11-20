import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';

import '../../../core/error_translator.dart';
import '../../../core/geo.dart';
import '../../../l10n/app_localizations.dart';
import '../../company/providers/company_providers.dart';
import '../../employee/providers/employee_providers.dart';
import '../attendance_status.dart';
import '../providers/attendance_providers.dart';
import 'live_location_map.dart';

/// Clock-in/out flow, in the order fixed by SPEC.md "Urutan Alur
/// Clock-in/Clock-out": location check first (cheap), then camera +
/// liveness (heavier). The backend is the final authority on radius — the
/// local distance check here only decides whether to show the mandatory
/// note prompt before submitting.
class AttendanceScreen extends ConsumerStatefulWidget {
  const AttendanceScreen({super.key});

  @override
  ConsumerState<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends ConsumerState<AttendanceScreen> {
  bool _isProcessing = false;

  Future<Position?> _getCurrentPosition(AppLocalizations t) async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      _showMessage(t.locationServiceDisabledError);
      return null;
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
      _showMessage(t.locationPermissionDeniedError);
      return null;
    }
    return Geolocator.getCurrentPosition();
  }

  Future<String?> _askForNote(AppLocalizations t) async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          String? error;
          return AlertDialog(
            title: Text(t.outsideRadiusTitle),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(t.outsideRadiusMessage),
                const SizedBox(height: 12),
                TextField(
                  controller: controller,
                  decoration: InputDecoration(labelText: t.noteLabel, errorText: error),
                  maxLines: 3,
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => context.pop(null), child: Text(t.cancelButton)),
              FilledButton(
                onPressed: () {
                  if (controller.text.trim().isEmpty) {
                    setDialogState(() => error = t.requiredField);
                    return;
                  }
                  context.pop(controller.text.trim());
                },
                child: Text(t.submitButton),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  /// True if the user cancelled out of the "clock out early?" confirm.
  Future<bool> _confirmedEarlyClockOut(AppLocalizations t) async {
    final company = await ref.read(companyMeProvider.future);
    final workEnd = company['work_end_time']?.toString();
    if (workEnd == null || workEnd.isEmpty) return true;
    final parts = workEnd.split(':');
    final h = int.tryParse(parts.elementAtOrNull(0) ?? '');
    final m = int.tryParse(parts.elementAtOrNull(1) ?? '');
    if (h == null || m == null) return true;
    final now = DateTime.now();
    final end = DateTime(now.year, now.month, now.day, h, m);
    if (!now.isBefore(end)) return true; // already at/past end time, no need to ask

    if (!mounted) return false;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(t.earlyClockOutTitle),
        content: Text(t.earlyClockOutMessage(workEnd)),
        actions: [
          TextButton(onPressed: () => context.pop(false), child: Text(t.cancelButton)),
          FilledButton(onPressed: () => context.pop(true), child: Text(t.yesClockOutButton)),
        ],
      ),
    );
    return confirmed == true;
  }

  Future<void> _handleAction(AttendanceAction action) async {
    final t = AppLocalizations.of(context)!;
    if (action == AttendanceAction.clockOut) {
      if (!await _confirmedEarlyClockOut(t)) return;
    }
    setState(() => _isProcessing = true);
    try {
      final position = await _getCurrentPosition(t);
      if (position == null) return;

      final me = await ref.read(myProfileProvider.future);
      final locationId = me['location_id'] as int?;
      if (locationId == null) {
        _showMessage(t.noLocationAssignedError);
        return;
      }

      final locations = await ref.read(locationListProvider.future);
      final matches = locations.where((l) => l['id'] == locationId);
      String? note;
      if (matches.isNotEmpty) {
        final location = matches.first;
        final lat = (location['latitude'] as num).toDouble();
        final lng = (location['longitude'] as num).toDouble();
        final radius = (location['radius_meters'] as num).toDouble();
        final distance = distanceInMeters(position.latitude, position.longitude, lat, lng);
        if (distance > radius) {
          note = await _askForNote(t);
          if (note == null) return; // user cancelled
        }
      }

      // Camera screen verifies live: it gates capture on face+liveness
      // detection, and — when the employee has an enrolled profile photo —
      // auto-captures and face-matches against it on its own, retrying
      // automatically on a mismatch/uncertain result (see
      // camera_capture_screen.dart). A returned result has already passed
      // that bar; nothing left to redo here.
      if (!mounted) return;
      final profilePhotoUrl = me['photo_url'] as String?;
      final hasProfilePhoto = profilePhotoUrl != null && profilePhotoUrl.isNotEmpty;

      String photoPath;
      double? faceScore;
      String faceStatus = 'not_checked';
      if (hasProfilePhoto) {
        final result = await context.push<Map<String, dynamic>>(
          '/attendance/capture',
          extra: profilePhotoUrl,
        );
        if (result == null) return; // user backed out of camera
        photoPath = result['path'] as String;
        faceStatus = result['status'] as String;
        faceScore = faceStatus == 'not_checked' ? null : (result['score'] as num).toDouble();
      } else {
        final path = await context.push<String>('/attendance/capture');
        if (path == null) return; // user backed out of camera
        photoPath = path;
      }

      final bytes = await File(photoPath).readAsBytes();
      final filename = photoPath.split(Platform.pathSeparator).last;
      final api = ref.read(attendanceApiProvider);
      if (action == AttendanceAction.clockIn) {
        await api.clockIn(
          photoBytes: bytes,
          filename: filename,
          latitude: position.latitude,
          longitude: position.longitude,
          note: note,
          faceMatchScore: faceScore,
          faceMatchStatus: faceStatus,
        );
        _showMessage(t.clockInSuccessMessage);
      } else {
        await api.clockOut(
          photoBytes: bytes,
          filename: filename,
          latitude: position.latitude,
          longitude: position.longitude,
          note: note,
          faceMatchScore: faceScore,
          faceMatchStatus: faceStatus,
        );
        _showMessage(t.clockOutSuccessMessage);
      }
      if (faceStatus == 'mismatch' || faceStatus == 'uncertain') {
        _showMessage(t.faceMatchGaveUpMessage);
      }
      ref.invalidate(myAttendanceProvider);
    } on DioException catch (e) {
      if (!mounted) return;
      _showMessage(translateError(context, e));
    } catch (_) {
      _showMessage(t.errorGeneric);
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final attendanceAsync = ref.watch(myAttendanceProvider);
    final now = DateTime.now();
    final hh = now.hour.toString().padLeft(2, '0');
    final mm = now.minute.toString().padLeft(2, '0');

    return Scaffold(
      appBar: AppBar(
        title: Text(t.attendanceTitle),
        actions: [
          TextButton(
            onPressed: () => context.push('/attendance/report'),
            child: Text(t.historyLabel),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            DecoratedBox(
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('$hh:$mm',
                        style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w700, color: Color(0xFF134E4A))),
                    const SizedBox(height: 4),
                    Text(_formatToday(now),
                        style: const TextStyle(color: Color(0xFF475569), fontSize: 13)),
                    const SizedBox(height: 12),
                    const _RadiusPill(),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            const LiveLocationMap(),
            const SizedBox(height: 20),
            attendanceAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text(translateError(context, e))),
              data: (records) {
                final action = determineAttendanceAction(records, todayDateString());
                if (action == AttendanceAction.done) {
                  return DecoratedBox(
                    decoration: BoxDecoration(
                      color: const Color(0xFFCCFBF1),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle_outline, color: Color(0xFF0D9488)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              t.alreadyClockedTodayMessage,
                              style: const TextStyle(color: Color(0xFF134E4A)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }
                return Column(
                  children: [
                    InkWell(
                      customBorder: const CircleBorder(),
                      onTap: _isProcessing ? null : () => _handleAction(action),
                      child: Container(
                        width: 84,
                        height: 84,
                        decoration: const BoxDecoration(color: Color(0xFFEA580C), shape: BoxShape.circle),
                        child: _isProcessing
                            ? const Padding(
                                padding: EdgeInsets.all(28),
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.fingerprint, color: Colors.white, size: 36),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(t.tapToAttendHint,
                        style: const TextStyle(color: Color(0xFF475569), fontSize: 13)),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  static const _days = ['Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu'];
  static const _months = [
    'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
    'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember',
  ];
  static String _formatToday(DateTime d) =>
      '${_days[d.weekday - 1]}, ${d.day} ${_months[d.month - 1]} ${d.year}';
}

/// Pill status sederhana (dalam/luar radius) di bawah jam — status
/// terperinci (jarak, map) tetap di [LiveLocationMap] di bawahnya; pill ini
/// cuma ringkasan cepat sesuai figma "05 Absensi".
class _RadiusPill extends ConsumerWidget {
  const _RadiusPill();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context)!;
    return DecoratedBox(
      decoration: BoxDecoration(color: const Color(0xFFCCFBF1), borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle, size: 14, color: Color(0xFF0D9488)),
            const SizedBox(width: 6),
            Text(t.withinRadiusPillLabel,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF0D9488))),
          ],
        ),
      ),
    );
  }
}
