import 'package:flutter_test/flutter_test.dart';
import 'package:talvio_mobile/core/api_signing.dart';

void main() {
  test('signRequestWithBytes matches signRequest for plain-ASCII bodies', () {
    final stringSig = signRequest(
      timestamp: '1700000000',
      method: 'POST',
      path: '/auth/login',
      body: '{"a":1}',
    );
    final bytesSig = signRequestWithBytes(
      timestamp: '1700000000',
      method: 'POST',
      path: '/auth/login',
      bodyBytes: '{"a":1}'.codeUnits,
    );
    expect(bytesSig, stringSig);
  });

  test('signRequestWithBytes is stable and sensitive to every byte', () {
    final a = signRequestWithBytes(
      timestamp: '1700000000',
      method: 'POST',
      path: '/employees/1/photo',
      bodyBytes: [0xFF, 0x00, 0x89, 0x50, 0x4E, 0x47], // arbitrary binary bytes
    );
    final b = signRequestWithBytes(
      timestamp: '1700000000',
      method: 'POST',
      path: '/employees/1/photo',
      bodyBytes: [0xFF, 0x00, 0x89, 0x50, 0x4E, 0x48], // last byte differs
    );
    expect(a, isNot(b));
    expect(a.length, 64); // hex-encoded SHA-256
  });
}
