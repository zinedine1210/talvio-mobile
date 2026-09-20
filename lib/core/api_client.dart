import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'api_signing.dart';

// TODO: Android emulator can't reach localhost — switch to 10.0.2.2 when running there.
const String apiBaseUrl = 'http://localhost:8081';

class AuthTokenNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void set(String? token) => state = token;
}

final authTokenProvider = NotifierProvider<AuthTokenNotifier, String?>(AuthTokenNotifier.new);

final dioProvider = Provider<Dio>((ref) {
  final dio = Dio(BaseOptions(baseUrl: apiBaseUrl));
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        final token = ref.read(authTokenProvider);
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }

        final timestamp =
            (DateTime.now().millisecondsSinceEpoch ~/ 1000).toString();
        final body = options.data == null ? '' : jsonEncode(options.data);
        options.headers['X-Timestamp'] = timestamp;
        options.headers['X-Signature'] = signRequest(
          timestamp: timestamp,
          method: options.method,
          path: options.path,
          body: body,
        );

        handler.next(options);
      },
    ),
  );
  return dio;
});
