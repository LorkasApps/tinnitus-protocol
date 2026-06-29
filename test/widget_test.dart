import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tinnitus_protocol/data/database.dart';
import 'package:tinnitus_protocol/l10n/app_localizations.dart';
import 'package:tinnitus_protocol/providers/providers.dart';
import 'package:tinnitus_protocol/screens/home_screen.dart';

void main() {
  testWidgets('Home screen renders with empty DB (en)', (tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());

    await tester.pumpWidget(
      ProviderScope(
        overrides: [dbProvider.overrideWithValue(db)],
        child: const MaterialApp(
          locale: Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: HomeScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Entries'), findsWidgets);
    expect(find.text('No entries yet.'), findsOneWidget);
    expect(find.text('New entry'), findsOneWidget);

    await db.close();
  });

  testWidgets('Home screen renders with empty DB (de)', (tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());

    await tester.pumpWidget(
      ProviderScope(
        overrides: [dbProvider.overrideWithValue(db)],
        child: const MaterialApp(
          locale: Locale('de'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: HomeScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Einträge'), findsWidgets);
    expect(find.text('Noch keine Einträge.'), findsOneWidget);
    expect(find.text('Neuer Eintrag'), findsOneWidget);

    await db.close();
  });
}
