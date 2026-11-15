import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stock_calendar/models/buy_series.dart';
import 'package:stock_calendar/widgets/repeat_sheet.dart';

void main() {
  testWidgets('tapping above the repeat sheet discards changes', (tester) async {
    RepeatDraft? result = RepeatDraft(frequency: RepeatFrequency.weeks);
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: TextButton(
                onPressed: () async {
                  result = await showRepeatSheet(
                    context,
                    RepeatDraft(),
                    DateTime(2026, 9, 23),
                  );
                },
                child: const Text('Open'),
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.text('Repeat'), findsOneWidget);

    await tester.tap(find.text('Every week'));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(20, 8));
    await tester.pumpAndSettle();

    expect(find.text('Repeat'), findsNothing);
    expect(result, isNull);
  });
}
