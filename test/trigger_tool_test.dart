import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:stock_calendar/state/theme_controller.dart';
import 'package:stock_calendar/triggertool/trigger_landing_screen.dart';

import 'calendar_flow_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('auto trigger tool opens its landing page', (tester) async {
    await pumpApp(tester);
    await register(tester);
    await tester.tap(find.text("Let's Get Started"));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final card = find.text('Auto Trigger Tool');
    await tester.ensureVisible(card);
    await tester.tap(card);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(TriggerLandingScreen), findsOneWidget);
    expect(find.text('for Investors'), findsOneWidget);
    expect(
      find.text(
        'This tool assists in adding buy trigger at certain conditions that can be met in future.',
      ),
      findsOneWidget,
    );
    expect(
      find.textContaining('the buy signal will be automatically visible'),
      findsOneWidget,
    );
    expect(
      find.textContaining('help evaluate his or her portfolio'),
      findsOneWidget,
    );

    final scaffold = find.descendant(
      of: find.byType(TriggerLandingScreen),
      matching: find.byType(Scaffold),
    );
    tester.state<ScaffoldState>(scaffold).openDrawer();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Dark theme'), findsOneWidget);
    expect(find.text('Stock Calendar AI'), findsWidgets);
    expect(find.text('owner@example.com'), findsOneWidget);
    expect(find.text('Home'), findsNothing);
    expect(find.text('Expert Pick'), findsNothing);

    final theme = tester.element(find.text('Dark theme')).read<ThemeController>();
    expect(theme.mode, ThemeMode.dark);
  });
}
