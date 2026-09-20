import 'dart:convert';
import 'dart:io' show Platform;

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'api_signing.dart';

// Android emulator's "localhost" refers to the emulator itself, not the
// host machine — 10.0.2.2 is the documented alias for the host's loopback.
// Doesn't cover a physical device over Wi-Fi (would need the host's LAN IP)
// — not needed yet since testing has been emulator/simulator only so far.
final String apiBaseUrl =
    Platform.isAndroid ? 'http://10.0.2.2:8081' : 'http://localhost:8081';

class AuthTokenNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void set(String? token) => state = token;
}

final authTokenProvider = NotifierProvider<AuthTokenNotifier, String?>(AuthTokenNotifier.new);

class CurrentEmployeeNotifier extends Notifier<Map<String, dynamic>?> {
  @override
  Map<String, dynamic>? build() => null;

  void set(Map<String, dynamic>? employee) => state = employee;
}

final currentEmployeeProvider =
    NotifierProvider<CurrentEmployeeNotifier, Map<String, dynamic>?>(CurrentEmployeeNotifier.new);

final dioProvider = Provider<Dio>((ref) {
  final dio = Dio(BaseOptions(baseUrl: apiBaseUrl));
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = ref.read(authTokenProvider);
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }

        final timestamp =
            (DateTime.now().millisecondsSinceEpoch ~/ 1000).toString();
        options.headers['X-Timestamp'] = timestamp;

        if (options.data is FormData) {
          // Sign the exact multipart bytes via a same-boundary clone, so
          // the original FormData is left untouched for Dio to actually
          // send — jsonEncode can't handle FormData, and re-stringifying
          // binary file bytes as a Dart String would corrupt them.
          final bodyBytes = await (options.data as FormData).clone().readAsBytes();
          options.headers['X-Signature'] = signRequestWithBytes(
            timestamp: timestamp,
            method: options.method,
            path: options.path,
            bodyBytes: bodyBytes,
          );
        } else {
          final body = options.data == null ? '' : jsonEncode(options.data);
          options.headers['X-Signature'] = signRequest(
            timestamp: timestamp,
            method: options.method,
            path: options.path,
            body: body,
          );
        }

        handler.next(options);
      },
    ),
  );
  return dio;
});
