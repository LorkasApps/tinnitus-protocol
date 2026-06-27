import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tinnitus_protocol/data/database.dart';
import 'package:tinnitus_protocol/providers/providers.dart';
import 'package:tinnitus_protocol/screens/home_screen.dart';

void main() {
  testWidgets('Home screen rendert mit leerer DB', (tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dbProvider.overrideWithValue(db),
        ],
        child: const MaterialApp(home: HomeScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Einträge'), findsWidgets);
    expect(find.text('Noch keine Einträge.'), findsOneWidget);
    expect(find.text('Neuer Eintrag'), findsOneWidget);

    await db.close();
  });
}
