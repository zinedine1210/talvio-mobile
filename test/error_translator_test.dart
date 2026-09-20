import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:talvio_mobile/core/error_translator.dart';
import 'package:talvio_mobile/l10n/app_localizations.dart';

Future<String> _translate(WidgetTester tester, Object error, {Locale locale = const Locale('id')}) async {
  late String result;
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(builder: (context) {
          result = translateError(context, error);
          return const SizedBox();
        }),
      ),
    ),
  );
  return result;
}

DioException _errorWithData(Map<String, dynamic>? data) => DioException(
      requestOptions: RequestOptions(path: '/test'),
      response: data == null
          ? null
          : Response(requestOptions: RequestOptions(path: '/test'), data: data, statusCode: 400),
    );

void main() {
  testWidgets('translates a known error code in Indonesian', (tester) async {
    final message = await _translate(tester, _errorWithData({'code': 'EMAIL_TAKEN', 'message': 'Email is already registered'}));
    expect(message, 'Email sudah terdaftar');
  });

  testWidgets('translates the same code in English', (tester) async {
    final message = await _translate(
      tester,
      _errorWithData({'code': 'EMAIL_TAKEN', 'message': 'Email is already registered'}),
      locale: const Locale('en'),
    );
    expect(message, 'Email is already registered');
  });

  testWidgets('falls back to backend message for an unknown code', (tester) async {
    final message = await _translate(tester, _errorWithData({'code': 'SOMETHING_NEW', 'message': 'Backend says hi'}));
    expect(message, 'Backend says hi');
  });

  testWidgets('falls back to network-unreachable when there is no response', (tester) async {
    final message = await _translate(tester, _errorWithData(null));
    expect(message, 'Tidak dapat terhubung ke server, cek koneksi internet');
  });

  testWidgets('falls back to a generic message for a non-Dio error', (tester) async {
    final message = await _translate(tester, Exception('boom'));
    expect(message, 'Terjadi kesalahan, coba lagi');
  });
}
