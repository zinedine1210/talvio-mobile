import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

const _eyeOpenThreshold = 0.5;

/// Liveness-only check (SPEC.md "Face Verification"): is there a real face
/// in frame with eyes open? Not identity matching — that's a separate,
/// later phase (on-device face-matching against the enrolled profile
/// photo).
Future<bool> passesLivenessCheck(String imagePath) async {
  final detector = FaceDetector(
    options: FaceDetectorOptions(enableClassification: true),
  );
  try {
    final faces = await detector.processImage(InputImage.fromFilePath(imagePath));
    if (faces.isEmpty) return false;
    final face = faces.first;
    final left = face.leftEyeOpenProbability;
    final right = face.rightEyeOpenProbability;
    if (left == null || right == null) return false;
    return left > _eyeOpenThreshold && right > _eyeOpenThreshold;
  } finally {
    await detector.close();
  }
}
