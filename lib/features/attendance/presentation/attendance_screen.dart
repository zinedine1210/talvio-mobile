import 'dart:io';
import 'dart:typed_data';

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
import '../face_matching.dart';
import '../providers/attendance_providers.dart';
import 'live_location_map.dart';

/// Max face-match retries before submitting anyway for HR review — per
/// SPEC.md's "never truly locked out" rule. Liveness has no such cap (that
/// gate stays retry-until-cancel, unchanged from Fase 2a).
const _maxFaceMatchAttempts = 3;

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

  /// Returns true = retake photo, false = submit anyway, null = cancel.
  Future<bool?> _showFaceMatchRetryDialog(AppLocalizations t) async {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(t.faceMatchRetryTitle),
        content: Text(t.faceMatchRetryMessage),
        actions: [
          TextButton(onPressed: () => context.pop(), child: Text(t.cancelButton)),
          TextButton(onPressed: () => context.pop(false), child: Text(t.submitAnywayButton)),
          FilledButton(onPressed: () => context.pop(true), child: Text(t.retakeButton)),
        ],
      ),
    );
  }

  Future<File> _downloadToTempFile(String url) async {
    final response = await Dio().get<List<int>>(
      url,
      options: Options(responseType: ResponseType.bytes),
    );
    return writeBytesToTempFile(Uint8List.fromList(response.data!), '.jpg');
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

      // Camera screen gates capture on live face+liveness detection (see
      // camera_capture_screen.dart) — a returned path has already passed
      // that bar, no separate post-capture liveness re-check needed here.
      if (!mounted) return;
      final firstCapture = await context.push<String>('/attendance/capture');
      if (firstCapture == null) return; // user backed out of camera
      String photoPath = firstCapture;

      var matchResult = const FaceMatchResult(0, FaceMatchStatus.notChecked);
      final profilePhotoUrl = me['photo_url'] as String?;
      final embedder = (profilePhotoUrl != null && profilePhotoUrl.isNotEmpty)
          ? await FaceEmbedder.load()
          : null;
      var matchAttempts = 0;
      var gaveUpOnMatch = false;
      try {
        while (embedder != null) {
          matchAttempts++;
          final liveEmbedding = await embedder.embedFaceInImageFile(photoPath);
          final profileFile = await _downloadToTempFile(profilePhotoUrl!);
          List<double>? profileEmbedding;
          try {
            profileEmbedding = await embedder.embedFaceInImageFile(profileFile.path);
          } finally {
            await profileFile.delete();
          }

          if (liveEmbedding == null || profileEmbedding == null) {
            matchResult = const FaceMatchResult(0, FaceMatchStatus.notChecked);
            break;
          }

          final distance = euclideanDistance(liveEmbedding, profileEmbedding);
          matchResult = classifyDistance(distance);
          if (matchResult.status == FaceMatchStatus.match) break;
          if (matchAttempts >= _maxFaceMatchAttempts) {
            gaveUpOnMatch = true;
            break;
          }

          if (!mounted) return;
          final choice = await _showFaceMatchRetryDialog(t);
          if (choice == null) return; // cancel entirely
          if (choice == false) break; // submit anyway, right now
          // choice == true -> retake (camera gates on liveness again, same
          // as the first capture) and loop back for another match attempt.
          if (!mounted) return;
          final retaken = await context.push<String>('/attendance/capture');
          if (retaken == null) return; // user backed out of camera
          photoPath = retaken;
        }
      } finally {
        embedder?.close();
      }

      final bytes = await File(photoPath).readAsBytes();
      final filename = photoPath.split(Platform.pathSeparator).last;
      final api = ref.read(attendanceApiProvider);
      final faceScore = matchResult.status == FaceMatchStatus.notChecked ? null : matchResult.score;
      final faceStatus = matchResult.status.apiValue;
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
      if (gaveUpOnMatch) _showMessage(t.faceMatchGaveUpMessage);
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
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const LiveLocationMap(),
            const SizedBox(height: 20),
            attendanceAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text(translateError(context, e))),
              data: (records) {
                final action = determineAttendanceAction(records, todayDateString());
                if (action == AttendanceAction.done) {
                  return Card(
                    color: Theme.of(context).colorScheme.tertiaryContainer,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Icon(Icons.check_circle_outline,
                              color: Theme.of(context).colorScheme.onTertiaryContainer),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              t.alreadyClockedTodayMessage,
                              style: TextStyle(
                                  color: Theme.of(context).colorScheme.onTertiaryContainer),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
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
          ],
        ),
      ),
    );
  }
}
