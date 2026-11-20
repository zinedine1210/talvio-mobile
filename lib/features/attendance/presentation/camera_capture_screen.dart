import 'dart:io';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

import '../../../l10n/app_localizations.dart';
import '../face_matching.dart';
import '../liveness_check.dart';

/// How often to run face detection on the live preview. ML Kit inference
/// takes longer than a frame interval, so this is paired with a busy-guard
/// (_isDetecting) rather than relied on alone — throttle bounds the rate,
/// the guard prevents frames queueing up faster than they can be processed.
const _detectionInterval = Duration(milliseconds: 350);

/// Max auto-capture+match attempts before giving up and handing control
/// back to a manual shutter tap — per SPEC.md's "never truly locked out"
/// rule (same cap the old post-capture retry dialog used).
const _maxFaceMatchAttempts = 3;

/// Max takePicture() hard-failure retries before giving up entirely and
/// popping the screen. On some devices a single bad stream reconfigure
/// ("Unsupported set of inputs/outputs provided") leaves the Camera2
/// session permanently wedged — every further takePicture() in that same
/// session fails too, so retrying in place would loop forever instead of
/// ever reaching upload. A fresh CameraController (via _reinitializeCamera)
/// gets a clean session; if that still doesn't help after a couple of
/// tries, bailing out lets the user back out and re-enter the screen for a
/// fully fresh start instead of being stuck silently.
const _maxCaptureFailures = 2;

/// Full-screen camera capture, used for attendance photos — deliberately
/// camera-only (no gallery picker), since attendance photos must be a live
/// capture, not a pre-existing image.
///
/// Runs face+liveness detection live on the preview stream (not
/// snap-then-validate): the shutter only fires once a real face with eyes
/// open is actually in frame.
///
/// When [profilePhotoUrl] is given (attendance clock-in/out with an
/// enrolled profile photo), it goes further: as soon as a live face is
/// detected it automatically captures and face-matches against that photo,
/// looping (release the shutter, wait for the next live face, try again)
/// on a mismatch/uncertain result up to [_maxFaceMatchAttempts] times —
/// the whole point is the user never has to tap anything for the happy
/// path. Pops with `{'path', 'score', 'status'}` once matched or once
/// attempts run out (falling back to a manual shutter tap from there, still
/// never truly locking the user out).
///
/// When [profilePhotoUrl] is null/empty (profile-photo setup, or an
/// employee with no enrolled photo yet), behaves exactly like before:
/// liveness gates a manual shutter, pops with the plain photo path string.
class CameraCaptureScreen extends StatefulWidget {
  const CameraCaptureScreen({super.key, this.profilePhotoUrl});

  final String? profilePhotoUrl;

  bool get _matchesProfile => profilePhotoUrl != null && profilePhotoUrl!.isNotEmpty;

  @override
  State<CameraCaptureScreen> createState() => _CameraCaptureScreenState();
}

class _CameraCaptureScreenState extends State<CameraCaptureScreen> {
  CameraController? _controller;
  FaceDetector? _detector;
  Future<void>? _initFuture;
  bool _isCapturing = false;
  bool _isStreaming = false;
  int _captureFailures = 0;
  bool _isDetecting = false;
  bool _liveFaceOk = false;
  DateTime? _lastDetectionAt;

  FaceEmbedder? _embedder;
  List<double>? _profileEmbedding;
  bool _profileReady = false;
  FaceMatchResult _matchResult = const FaceMatchResult(0, FaceMatchStatus.notChecked);
  int _matchAttempts = 0;
  bool _gaveUpOnMatch = false;

  @override
  void initState() {
    super.initState();
    _initFuture = _init();
    if (widget._matchesProfile) {
      _loadProfileEmbedding();
    } else {
      _profileReady = true;
    }
  }

  Future<void> _init() async {
    final cameras = await availableCameras();
    if (cameras.isEmpty) return;
    final camera = cameras.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.front,
      orElse: () => cameras.first,
    );
    final controller = CameraController(
      camera,
      // low, not medium: this screen runs Preview+ImageCapture+ImageAnalysis
      // concurrently for the auto-capture liveness flow, and some devices'
      // Camera2 HAL (LIMITED hardware level) reject that 3-stream combo at
      // higher resolutions ("Unsupported set of inputs/outputs provided").
      // Face detection/matching works fine at this resolution.
      ResolutionPreset.low,
      enableAudio: false,
      imageFormatGroup: Platform.isAndroid ? ImageFormatGroup.nv21 : ImageFormatGroup.bgra8888,
    );
    await controller.initialize();
    if (!mounted) {
      await controller.dispose();
      return;
    }
    _detector = FaceDetector(options: FaceDetectorOptions(enableClassification: true));
    setState(() => _controller = controller);
    await _startStreaming();
  }

  Future<void> _startStreaming() async {
    final controller = _controller;
    if (controller == null || _isStreaming) return;
    await controller.startImageStream((image) => _onFrame(image, controller.description));
    _isStreaming = true;
  }

  /// Tears down the current CameraController and brings up a brand new one
  /// — used after a hard takePicture() failure, since on some devices the
  /// Camera2 session stays wedged (every further capture in that same
  /// session fails too) once a stream-reconfigure gets rejected.
  Future<void> _reinitializeCamera() async {
    final old = _controller;
    _isStreaming = false;
    if (mounted) setState(() => _controller = null);
    if (old != null) {
      try {
        await old.dispose();
      } catch (_) {
        // Already in a bad state — nothing to clean up further.
      }
    }
    await _detector?.close();
    _detector = null;
    if (!mounted) return;
    await _init();
  }

  /// Downloads the enrolled profile photo and computes its embedding once,
  /// up front, so every subsequent auto-capture only has to embed the fresh
  /// live photo. Falls back to liveness-only (never blocks the user) if
  /// this fails for any reason — same "never truly locked out" guarantee
  /// as a mismatch/uncertain result.
  Future<void> _loadProfileEmbedding() async {
    final url = widget.profilePhotoUrl!;
    try {
      final embedder = await FaceEmbedder.load();
      final profileFile = await _downloadToTempFile(url);
      List<double>? embedding;
      try {
        embedding = await embedder.embedFaceInImageFile(profileFile.path);
      } finally {
        await profileFile.delete();
      }
      if (!mounted) {
        embedder.close();
        return;
      }
      // Kept even if embedding is null (no face found in the profile photo)
      // — dispose() closes it either way, and _matchAgainstProfile bails
      // out safely on a null embedding without needing this to be null too.
      setState(() {
        _embedder = embedder;
        _profileEmbedding = embedding;
        _profileReady = true;
      });
    } catch (_) {
      if (mounted) setState(() => _profileReady = true);
    }
  }

  Future<File> _downloadToTempFile(String url) async {
    final response = await Dio().get<List<int>>(
      url,
      options: Options(responseType: ResponseType.bytes),
    );
    return writeBytesToTempFile(Uint8List.fromList(response.data!), '.jpg');
  }

  void _onFrame(CameraImage image, CameraDescription camera) {
    if (_isDetecting) return;
    final now = DateTime.now();
    if (_lastDetectionAt != null && now.difference(_lastDetectionAt!) < _detectionInterval) return;
    _lastDetectionAt = now;
    _isDetecting = true;
    _detectLiveFace(image, camera).then((ok) {
      _isDetecting = false;
      if (!mounted) return;
      if (ok != _liveFaceOk) setState(() => _liveFaceOk = ok);
      if (ok) _maybeAutoCapture();
    });
  }

  /// Fires an auto capture+match cycle the instant a live face shows up —
  /// only in profile-match mode, only while there's still something useful
  /// to try. `_capture()` itself guards re-entrancy via `_isCapturing`.
  void _maybeAutoCapture() {
    if (!widget._matchesProfile || !_profileReady || _profileEmbedding == null) return;
    if (_gaveUpOnMatch || _isCapturing) return;
    if (_matchResult.status == FaceMatchStatus.match) return;
    _capture();
  }

  Future<bool> _detectLiveFace(CameraImage image, CameraDescription camera) async {
    final detector = _detector;
    if (detector == null) return false;
    final input = _inputImageFromCameraImage(image, camera);
    if (input == null) return false;
    try {
      final faces = await detector.processImage(input);
      return faces.isNotEmpty && isLiveFace(faces.first);
    } catch (_) {
      // A stray malformed frame shouldn't crash the live indicator — treat
      // it as "no face this frame" and let the next one retry.
      return false;
    }
  }

  /// Converts a raw camera frame to the format ML Kit expects. Only
  /// single-plane formats are handled (nv21 on Android, bgra8888 on iOS —
  /// both requested explicitly via imageFormatGroup above), so there's
  /// exactly one plane to read. Rotation assumes portrait device
  /// orientation (this screen doesn't support landscape) — revisit if that
  /// changes.
  InputImage? _inputImageFromCameraImage(CameraImage image, CameraDescription camera) {
    final rotation = InputImageRotationValue.fromRawValue(camera.sensorOrientation);
    if (rotation == null) return null;

    final format = Platform.isAndroid ? InputImageFormat.nv21 : InputImageFormat.bgra8888;
    if (image.planes.isEmpty) return null;
    final plane = image.planes.first;

    return InputImage.fromBytes(
      bytes: plane.bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: plane.bytesPerRow,
      ),
    );
  }

  Future<FaceMatchResult> _matchAgainstProfile(String photoPath) async {
    final embedder = _embedder;
    final profileEmbedding = _profileEmbedding;
    if (embedder == null || profileEmbedding == null) {
      return const FaceMatchResult(0, FaceMatchStatus.notChecked);
    }
    final liveEmbedding = await embedder.embedFaceInImageFile(photoPath);
    if (liveEmbedding == null) return const FaceMatchResult(0, FaceMatchStatus.notChecked);
    return classifyDistance(euclideanDistance(liveEmbedding, profileEmbedding));
  }

  /// The one capture path, used both by the auto-trigger and the manual
  /// shutter (which stays available the whole time as a fallback — e.g. if
  /// the user wants to force a check right away, or once attempts run out
  /// and only a manual tap can finish the flow).
  Future<void> _capture() async {
    final controller = _controller;
    if (controller == null || _isCapturing || !_liveFaceOk) return;
    setState(() => _isCapturing = true);
    try {
      if (_isStreaming) {
        await controller.stopImageStream();
        _isStreaming = false;
        // Some devices' Camera2 HAL rejects takePicture() fired immediately
        // after stopImageStream() — the session hasn't finished dropping
        // the ImageAnalysis stream yet, so it briefly still sees all 3
        // (Preview+ImageCapture+ImageAnalysis) and rejects that combo
        // ("Unsupported set of inputs/outputs provided"). A short settle
        // delay avoids that race.
        await Future<void>.delayed(const Duration(milliseconds: 300));
      }

      final XFile file;
      try {
        file = await controller.takePicture();
      } catch (_) {
        // Camera2/OEM capture failure — surface it instead of leaving the
        // shutter silently re-enabled with no feedback (the exact "jepret
        // tidak tersimpan" symptom). A plain retry on the SAME controller
        // can loop forever if the session is wedged (see
        // _maxCaptureFailures doc) — reinit a fresh controller instead, and
        // give up for good past the cap so the user can back out and
        // re-enter the screen for a truly clean start.
        _captureFailures++;
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(AppLocalizations.of(context)!.cameraCaptureFailedMessage)));
        if (_captureFailures > _maxCaptureFailures) {
          Navigator.of(context).pop();
          return;
        }
        await _reinitializeCamera();
        return;
      }
      if (!mounted) return;
      _captureFailures = 0;

      if (!widget._matchesProfile) {
        Navigator.of(context).pop(file.path);
        return;
      }
      if (_gaveUpOnMatch) {
        // Attempts already exhausted earlier — this manual tap just
        // finishes the flow with the last known (mismatch/uncertain)
        // result, per SPEC's "never truly locked out" rule.
        Navigator.of(context).pop({
          'path': file.path,
          'score': _matchResult.score,
          'status': _matchResult.status.apiValue,
        });
        return;
      }

      setState(() => _matchAttempts++);
      // On-device TFLite inference can throw on some OEM builds — never let
      // that strand the flow silently. Fall back to "not checked" (same as
      // a null embedding) and still finish with the captured photo, instead
      // of leaving the shutter re-enabled with nothing having happened.
      FaceMatchResult result;
      try {
        result = await _matchAgainstProfile(file.path);
      } catch (_) {
        result = const FaceMatchResult(0, FaceMatchStatus.notChecked);
      }
      if (!mounted) return;
      setState(() => _matchResult = result);

      final exhausted = _matchAttempts >= _maxFaceMatchAttempts;
      final needsRetry = result.status == FaceMatchStatus.uncertain || result.status == FaceMatchStatus.mismatch;
      if (!needsRetry || exhausted) {
        if (exhausted && result.status != FaceMatchStatus.match) {
          setState(() => _gaveUpOnMatch = true);
        }
        // Brief pause so "Wajah cocok!" is actually readable instead of an
        // instant cut straight to the next screen.
        if (result.status == FaceMatchStatus.match) {
          await Future<void>.delayed(const Duration(milliseconds: 500));
          if (!mounted) return;
        }
        Navigator.of(context).pop({
          'path': file.path,
          'score': result.score,
          'status': result.status.apiValue,
        });
        return;
      }

      // Not matched yet, attempts remain -> keep watching for the next live
      // face and try again automatically.
      await _startStreaming();
    } finally {
      if (mounted) setState(() => _isCapturing = false);
    }
  }

  @override
  void dispose() {
    final controller = _controller;
    if (controller != null && _isStreaming) {
      controller.stopImageStream();
    }
    controller?.dispose();
    _detector?.close();
    _embedder?.close();
    super.dispose();
  }

  String _statusText(AppLocalizations t) {
    if (!_liveFaceOk) return t.positionYourFaceStatus;
    if (!widget._matchesProfile) return t.liveFaceDetectedStatus;
    if (_gaveUpOnMatch) return t.faceMatchTapToContinueStatus;
    if (_isCapturing && _matchResult.status == FaceMatchStatus.match) return t.faceMatchedStatus;
    if (_isCapturing) return t.verifyingFaceStatus;
    if (_matchAttempts > 0) return t.faceMismatchRetryingStatus;
    return t.liveFaceDetectedStatus;
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: Colors.black,
      body: FutureBuilder<void>(
        future: _initFuture,
        builder: (context, snapshot) {
          final controller = _controller;
          if (controller == null || !controller.value.isInitialized) {
            return const Center(child: CircularProgressIndicator());
          }
          final statusColor = !_liveFaceOk
              ? Colors.black
              : (_gaveUpOnMatch ? Colors.orange : Colors.green);
          return Stack(
            fit: StackFit.expand,
            children: [
              _CameraPreviewFill(controller: controller),
              Positioned(
                left: 0,
                right: 0,
                top: 80,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _statusText(t),
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 32,
                child: Center(
                  child: FloatingActionButton(
                    backgroundColor: _liveFaceOk ? null : Colors.grey,
                    onPressed: (_isCapturing || !_liveFaceOk) ? null : _capture,
                    child: _isCapturing
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Icon(Icons.camera_alt),
                  ),
                ),
              ),
              Positioned(
                top: 40,
                left: 8,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Fills the available space with the camera preview at its true aspect
/// ratio (cropping edges via BoxFit.cover) instead of letting the parent
/// Stack's StackFit.expand stretch CameraPreview directly, which distorts
/// the image into an oval/elongated look and throws off face detection.
///
/// CameraController reports previewSize in landscape terms (width > height)
/// regardless of device orientation, so it's swapped here for portrait.
class _CameraPreviewFill extends StatelessWidget {
  const _CameraPreviewFill({required this.controller});

  final CameraController controller;

  @override
  Widget build(BuildContext context) {
    final previewSize = controller.value.previewSize;
    if (previewSize == null) return CameraPreview(controller);
    return ClipRect(
      child: OverflowBox(
        alignment: Alignment.center,
        child: FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: previewSize.height,
            height: previewSize.width,
            child: CameraPreview(controller),
          ),
        ),
      ),
    );
  }
}
