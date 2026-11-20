import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

const _modelAsset = 'assets/models/mobilefacenet.tflite';
const _inputSize = 112;
const _embeddingSize = 192;

enum FaceMatchStatus { match, uncertain, mismatch, notChecked }

extension FaceMatchStatusApi on FaceMatchStatus {
  /// The exact string the backend expects in the `face_match_status` field.
  String get apiValue => switch (this) {
        FaceMatchStatus.match => 'match',
        FaceMatchStatus.uncertain => 'uncertain',
        FaceMatchStatus.mismatch => 'mismatch',
        FaceMatchStatus.notChecked => 'not_checked',
      };
}

class FaceMatchResult {
  const FaceMatchResult(this.score, this.status);
  final double score;
  final FaceMatchStatus status;
}

/// Classifies a Euclidean distance between two L2-normalized MobileFaceNet
/// embeddings. Thresholds are the reference implementation's starting
/// points (MCarlomagno/FaceRecognitionAuth) widened slightly: with eye-line
/// alignment now applied before embedding (see embedFaceInImageFile), the
/// same-person distance distribution for MobileFaceNet typically sits
/// under ~0.8-0.9 even across lighting/angle variation, so 0.5 as "match"
/// was too strict and caused real same-person captures to register as
/// uncertain/mismatch. Still not independently calibrated against a real
/// employee photo set — see SPEC.md "Face Verification". Tune further if
/// match/mismatch rates look off in practice.
FaceMatchResult classifyDistance(double distance) {
  if (distance <= 0.8) return FaceMatchResult(distance, FaceMatchStatus.match);
  if (distance <= 1.1) return FaceMatchResult(distance, FaceMatchStatus.uncertain);
  return FaceMatchResult(distance, FaceMatchStatus.mismatch);
}

double euclideanDistance(List<double> a, List<double> b) {
  var sum = 0.0;
  for (var i = 0; i < a.length; i++) {
    final d = a[i] - b[i];
    sum += d * d;
  }
  return sqrt(sum);
}

List<double> l2Normalize(List<double> v) {
  var normSq = 0.0;
  for (final x in v) {
    normSq += x * x;
  }
  final norm = sqrt(normSq);
  if (norm == 0) return v;
  return v.map((x) => x / norm).toList();
}

/// On-device face embedding via MobileFaceNet (see assets/models/NOTICE.md
/// for model source/license). One instance per attendance attempt is fine
/// at this app's scale — not pooled/reused across calls.
class FaceEmbedder {
  FaceEmbedder._(this._interpreter);
  final Interpreter _interpreter;

  static Future<FaceEmbedder> load() async {
    final interpreter = await Interpreter.fromAsset(_modelAsset);
    return FaceEmbedder._(interpreter);
  }

  void close() => _interpreter.close();

  /// Detects the largest face in the image at [imagePath], crops + resizes
  /// + normalizes it, and returns its L2-normalized 192-d embedding.
  /// Returns null if no face is detected (caller should treat this as
  /// "can't verify", not as a hard failure — see SPEC.md's "never truly
  /// locked out" rule).
  Future<List<double>?> embedFaceInImageFile(String imagePath) async {
    final detector = FaceDetector(options: FaceDetectorOptions(enableLandmarks: true));
    List<Face> faces;
    try {
      faces = await detector.processImage(InputImage.fromFilePath(imagePath));
    } finally {
      await detector.close();
    }
    if (faces.isEmpty) return null;

    faces.sort((a, b) =>
        (b.boundingBox.width * b.boundingBox.height).compareTo(a.boundingBox.width * a.boundingBox.height));
    final detected = faces.first;
    final box = detected.boundingBox;

    final bytes = await File(imagePath).readAsBytes();
    var decoded = img.decodeImage(bytes);
    if (decoded == null) return null;
    decoded = img.bakeOrientation(decoded);

    final padX = box.width * 0.2;
    final padY = box.height * 0.2;
    final left = (box.left - padX).clamp(0, decoded.width - 1).toInt();
    final top = (box.top - padY).clamp(0, decoded.height - 1).toInt();
    final right = (box.right + padX).clamp(0, decoded.width).toInt();
    final bottom = (box.bottom + padY).clamp(0, decoded.height).toInt();
    var cropped = img.copyCrop(decoded,
        x: left, y: top, width: max(1, right - left), height: max(1, bottom - top));

    // Eye-line alignment: rotate the crop so the eyes are level before
    // resizing. A tilted head otherwise skews the embedding and was a real
    // source of false mismatch/uncertain results — MobileFaceNet (like most
    // small embedding models) assumes a roughly upright, frontal face.
    final leftEye = detected.landmarks[FaceLandmarkType.leftEye]?.position;
    final rightEye = detected.landmarks[FaceLandmarkType.rightEye]?.position;
    if (leftEye != null && rightEye != null) {
      final dx = (rightEye.x - leftEye.x).toDouble();
      final dy = (rightEye.y - leftEye.y).toDouble();
      final angleDeg = atan2(dy, dx) * 180 / pi;
      if (angleDeg.abs() > 1) {
        cropped = img.copyRotate(cropped, angle: -angleDeg);
      }
    }

    final face = img.copyResize(cropped, width: _inputSize, height: _inputSize);
    return _runInference(face);
  }

  List<double> _runInference(img.Image face) {
    final input = [
      List.generate(
        _inputSize,
        (y) => List.generate(_inputSize, (x) {
          final pixel = face.getPixel(x, y);
          return [
            (pixel.r - 127.5) / 128.0,
            (pixel.g - 127.5) / 128.0,
            (pixel.b - 127.5) / 128.0,
          ];
        }),
      ),
    ];
    final output = [List.filled(_embeddingSize, 0.0)];
    _interpreter.run(input, output);
    return l2Normalize(output[0]);
  }
}

/// Downloads bytes and writes them to a temp file — needed because ML
/// Kit's FaceDetector only accepts a file path or raw-frame byte metadata,
/// not arbitrary encoded image bytes. Caller is responsible for deleting
/// the returned file when done.
Future<File> writeBytesToTempFile(Uint8List bytes, String suffix) async {
  final file = File('${Directory.systemTemp.path}/talvio_face_${DateTime.now().microsecondsSinceEpoch}$suffix');
  await file.writeAsBytes(bytes, flush: true);
  return file;
}
