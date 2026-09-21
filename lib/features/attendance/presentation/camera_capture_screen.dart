import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

import '../../../l10n/app_localizations.dart';
import '../liveness_check.dart';

/// How often to run face detection on the live preview. ML Kit inference
/// takes longer than a frame interval, so this is paired with a busy-guard
/// (_isDetecting) rather than relied on alone — throttle bounds the rate,
/// the guard prevents frames queueing up faster than they can be processed.
const _detectionInterval = Duration(milliseconds: 350);

/// Full-screen camera capture, used for attendance photos — deliberately
/// camera-only (no gallery picker), since attendance photos must be a live
/// capture, not a pre-existing image.
///
/// Runs face+liveness detection live on the preview stream (not
/// snap-then-validate): the shutter button only enables once a real face
/// with eyes open is actually in frame, so whatever gets captured has
/// already passed the same liveness bar `isLiveFace` enforces — the caller
/// (attendance_screen.dart) no longer needs to re-check the captured file.
/// Pops with the captured file path, or null if the user backs out.
class CameraCaptureScreen extends StatefulWidget {
  const CameraCaptureScreen({super.key});

  @override
  State<CameraCaptureScreen> createState() => _CameraCaptureScreenState();
}

class _CameraCaptureScreenState extends State<CameraCaptureScreen> {
  CameraController? _controller;
  FaceDetector? _detector;
  Future<void>? _initFuture;
  bool _isCapturing = false;
  bool _isStreaming = false;
  bool _isDetecting = false;
  bool _liveFaceOk = false;
  DateTime? _lastDetectionAt;

  @override
  void initState() {
    super.initState();
    _initFuture = _init();
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
      ResolutionPreset.medium,
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
    await controller.startImageStream((image) => _onFrame(image, camera));
    _isStreaming = true;
  }

  void _onFrame(CameraImage image, CameraDescription camera) {
    if (_isDetecting) return;
    final now = DateTime.now();
    if (_lastDetectionAt != null && now.difference(_lastDetectionAt!) < _detectionInterval) return;
    _lastDetectionAt = now;
    _isDetecting = true;
    _detectLiveFace(image, camera).then((ok) {
      _isDetecting = false;
      if (mounted && ok != _liveFaceOk) setState(() => _liveFaceOk = ok);
    });
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

  Future<void> _capture() async {
    final controller = _controller;
    if (controller == null || _isCapturing || !_liveFaceOk) return;
    setState(() => _isCapturing = true);
    try {
      if (_isStreaming) {
        await controller.stopImageStream();
        _isStreaming = false;
      }
      final file = await controller.takePicture();
      if (!mounted) return;
      Navigator.of(context).pop(file.path);
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
    super.dispose();
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
          return Stack(
            fit: StackFit.expand,
            children: [
              CameraPreview(controller),
              Positioned(
                left: 0,
                right: 0,
                top: 80,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: (_liveFaceOk ? Colors.green : Colors.black).withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _liveFaceOk ? t.liveFaceDetectedStatus : t.positionYourFaceStatus,
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
