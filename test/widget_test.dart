import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:talvio_mobile/features/auth/presentation/register_company_screen.dart';
import 'package:talvio_mobile/features/employee/presentation/employee_form_screen.dart';
import 'package:talvio_mobile/l10n/app_localizations.dart';

Widget _wrap(Widget child) => ProviderScope(
      child: MaterialApp(
        locale: const Locale('id'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: child,
      ),
    );

void main() {
  testWidgets('employee form shows validation errors on empty submit',
      (tester) async {
    // The form has enough fields to overflow the default test viewport —
    // Simpan wouldn't be mounted (off-screen list children aren't built).
    await tester.binding.setSurfaceSize(const Size(400, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_wrap(const EmployeeFormScreen()));
    // Let the department/employee FutureProviders settle (they fail fast —
    // no backend in the test environment — but must not throw).
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    await tester.tap(find.text('Simpan'));
    await tester.pump();

    expect(find.text('Wajib diisi'), findsWidgets);
  });

  testWidgets('register company form shows validation errors on empty submit',
      (tester) async {
    await tester.pumpWidget(_wrap(const RegisterCompanyScreen()));

    await tester.tap(find.text('Buat akun perusahaan'));
    await tester.pump();

    expect(find.text('Wajib diisi'), findsWidgets);
  });

  testWidgets('register company form rejects invalid email', (tester) async {
    await tester.pumpWidget(_wrap(const RegisterCompanyScreen()));

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'PT Maju');
    await tester.enterText(fields.at(1), 'Budi');
    await tester.enterText(fields.at(2), 'bukan-email');
    await tester.enterText(fields.at(3), '123456');
    await tester.tap(find.text('Buat akun perusahaan'));
    await tester.pump();

    expect(find.text('Email tidak valid'), findsOneWidget);
  });
}
