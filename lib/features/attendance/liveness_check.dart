import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

const eyeOpenThreshold = 0.5;

/// Liveness-only check (SPEC.md "Face Verification"): is there a real face
/// in frame with eyes open? Not identity matching — that's a separate
/// concern (on-device face-matching against the enrolled profile photo, see
/// face_matching.dart). Shared by the live camera-preview detector
/// (camera_capture_screen.dart processes frames directly) so both use the
/// exact same pass/fail rule.
bool isLiveFace(Face face) {
  final left = face.leftEyeOpenProbability;
  final right = face.rightEyeOpenProbability;
  if (left == null || right == null) return false;
  return left > eyeOpenThreshold && right > eyeOpenThreshold;
}
