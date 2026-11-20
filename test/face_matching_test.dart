import 'package:flutter_test/flutter_test.dart';
import 'package:talvio_mobile/features/attendance/face_matching.dart';

void main() {
  group('classifyDistance', () {
    test('distance <= 0.5 is a match', () {
      expect(classifyDistance(0.0).status, FaceMatchStatus.match);
      expect(classifyDistance(0.5).status, FaceMatchStatus.match);
    });

    test('0.5 < distance <= 0.9 is uncertain', () {
      expect(classifyDistance(0.6).status, FaceMatchStatus.uncertain);
      expect(classifyDistance(0.9).status, FaceMatchStatus.uncertain);
    });

    test('distance > 0.9 is a mismatch', () {
      expect(classifyDistance(1.5).status, FaceMatchStatus.mismatch);
    });
  });

  group('FaceMatchStatus.apiValue', () {
    test('maps to the exact strings the backend expects', () {
      expect(FaceMatchStatus.match.apiValue, 'match');
      expect(FaceMatchStatus.uncertain.apiValue, 'uncertain');
      expect(FaceMatchStatus.mismatch.apiValue, 'mismatch');
      expect(FaceMatchStatus.notChecked.apiValue, 'not_checked');
    });
  });

  group('euclideanDistance', () {
    test('is zero for identical vectors', () {
      expect(euclideanDistance([1, 2, 3], [1, 2, 3]), 0.0);
    });

    test('matches the known 3-4-5 triangle distance', () {
      expect(euclideanDistance([0, 0], [3, 4]), 5.0);
    });
  });

  group('l2Normalize', () {
    test('produces a unit-length vector', () {
      final normalized = l2Normalize([3, 4]);
      final norm = euclideanDistance(normalized, [0, 0]);
      expect(norm, closeTo(1.0, 1e-9));
    });

    test('leaves an all-zero vector untouched (avoids divide-by-zero)', () {
      expect(l2Normalize([0, 0, 0]), [0, 0, 0]);
    });
  });
}
