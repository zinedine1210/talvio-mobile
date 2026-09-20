import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:presensia_mobile/features/auth/presentation/register_company_screen.dart';

void main() {
  testWidgets('register company form shows validation errors on empty submit',
      (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: RegisterCompanyScreen()),
      ),
    );

    await tester.tap(find.text('Daftar'));
    await tester.pump();

    expect(find.text('Wajib diisi'), findsWidgets);
  });

  testWidgets('register company form rejects invalid email', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: RegisterCompanyScreen()),
      ),
    );

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'PT Maju');
    await tester.enterText(fields.at(1), 'Budi');
    await tester.enterText(fields.at(2), 'bukan-email');
    await tester.enterText(fields.at(3), '123456');
    await tester.tap(find.text('Daftar'));
    await tester.pump();

    expect(find.text('Email tidak valid'), findsOneWidget);
  });
}
