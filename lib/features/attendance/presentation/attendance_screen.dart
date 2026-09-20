import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';

import '../../../core/error_translator.dart';
import '../../../core/geo.dart';
import '../../../l10n/app_localizations.dart';
import '../../employee/providers/employee_providers.dart';
import '../attendance_status.dart';
import '../liveness_check.dart';
import '../providers/attendance_providers.dart';

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

  Future<bool> _showLivenessFailedDialog(AppLocalizations t) async {
    final retry = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(t.livenessFailedTitle),
        content: Text(t.livenessFailedMessage),
        actions: [
          TextButton(onPressed: () => context.pop(false), child: Text(t.cancelButton)),
          FilledButton(onPressed: () => context.pop(true), child: Text(t.retakeButton)),
        ],
      ),
    );
    return retry ?? false;
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _handleAction(AttendanceAction action) async {
    final t = AppLocalizations.of(context)!;
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

      String? photoPath;
      while (true) {
        if (!mounted) return;
        photoPath = await context.push<String>('/attendance/capture');
        if (photoPath == null) return; // user backed out of camera
        final passed = await passesLivenessCheck(photoPath);
        if (passed) break;
        if (!mounted) return;
        final retry = await _showLivenessFailedDialog(t);
        if (!retry) return;
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
        );
        _showMessage(t.clockInSuccessMessage);
      } else {
        await api.clockOut(
          photoBytes: bytes,
          filename: filename,
          latitude: position.latitude,
          longitude: position.longitude,
          note: note,
        );
        _showMessage(t.clockOutSuccessMessage);
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

    return Scaffold(
      appBar: AppBar(title: Text(t.attendanceTitle)),
      body: Center(
        child: attendanceAsync.when(
          loading: () => const CircularProgressIndicator(),
          error: (e, _) => Text(translateError(context, e)),
          data: (records) {
            final action = determineAttendanceAction(records, todayDateString());
            if (action == AttendanceAction.done) {
              return Text(t.alreadyClockedTodayMessage);
            }
            final isClockIn = action == AttendanceAction.clockIn;
            return FilledButton(
              onPressed: _isProcessing ? null : () => _handleAction(action),
              child: _isProcessing
                  ? const SizedBox(
                      height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(isClockIn ? t.clockInButton : t.clockOutButton),
            );
          },
        ),
      ),
    );
  }
}
