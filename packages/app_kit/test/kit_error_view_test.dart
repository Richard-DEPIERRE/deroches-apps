import 'package:app_kit/app_kit.dart';
import 'package:app_kit/testing.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('full size: an icon, the title and the body', (tester) async {
    await pumpOnSmallPhone(tester, const Locale('en'), const KitErrorView());

    expect(find.byIcon(Icons.error_outline), findsOneWidget);
    expect(find.text('Something went wrong'), findsOneWidget);
    expect(find.textContaining('Close the app and open it again.'), findsOneWidget);
  });

  testWidgets('in a list row: one line, icon and title, no overflow', (tester) async {
    await pumpOnSmallPhone(
      tester,
      const Locale('fr'),
      ListView(children: const [SizedBox(height: 56, child: KitErrorView())]),
    );

    expect(find.byIcon(Icons.error_outline), findsOneWidget);
    expect(find.text('Un problème est survenu'), findsOneWidget);
    expect(find.textContaining('Fermez'), findsNothing);
    expect(tester.getTopLeft(find.byIcon(Icons.error_outline)).dx, 16, reason: 'lined up with M3 list rows');
    expect(tester.takeException(), isNull);
  });

  testWidgets('in a horizontal list card: one line, no layout error', (tester) async {
    await pumpOnSmallPhone(
      tester,
      const Locale('en'),
      Scaffold(
        body: SizedBox(
          height: 120,
          child: ListView(scrollDirection: Axis.horizontal, children: const [KitErrorView()]),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('Something went wrong'), findsOneWidget);
  });

  testWidgets('shows the English strings when the kit\'s localizations are missing', (tester) async {
    await tester.pumpWidget(const Directionality(textDirection: TextDirection.ltr, child: KitErrorView()));

    expect(find.text('Something went wrong'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
