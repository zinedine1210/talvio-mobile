import 'dart:convert';

import 'package:crypto/crypto.dart';

/// Must match `API_SIGNING_SECRET` in talvio-backend's .env exactly.
///
/// This ships inside the compiled app binary, so it's defense-in-depth
/// against generic bot/script traffic hitting the API directly — NOT a
/// real secret. A determined attacker can extract it by decompiling the
/// app. Actual security is the JWT bearer token issued after login.
const String apiSigningSecret =
    'b9a46fa9a2b37cb30d868793578cd933772b86665aa94501b418547e7ca72076';

String signRequest({
  required String timestamp,
  required String method,
  required String path,
  required String body,
}) {
  final payload = '$timestamp.$method.$path.$body';
  final hmac = Hmac(sha256, utf8.encode(apiSigningSecret));
  return hmac.convert(utf8.encode(payload)).toString();
}
