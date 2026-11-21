import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stock_calendar/expertpick/expert_opinion_screen.dart';
import 'package:stock_calendar/expertpick/expert_scrip.dart';
import 'package:stock_calendar/expertpick/memory_series_repository.dart';
import 'package:stock_calendar/services/notification_service.dart';
import 'package:stock_calendar/state/calendar_controller.dart';

import 'calendar_flow_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('sample scrip fields', () {
    final scrip = parseExpertScrip(
      jsonEncode({
        'author_name': 'Equitymaster',
        'investment_firm': 'Quantum Information Services Private Limited',
        'description': 'A short note',
        'published_date': '2026-11-18',
        'youtube_url': 'https://www.youtube.com/watch?v=n633-siFdR8',
        'stocks': [
          {
            'stock_name': 'Shilchar Technologies Ltd',
            'stock_code': 'SHILCTECH',
          },
        ],
      }),
    );
    expect(scrip.authorName, 'Equitymaster');
    expect(
      scrip.investmentFirm,
      'Quantum Information Services Private Limited',
    );
    expect(formatPublishedDate(scrip.publishedDate), '18 Nov 2026');
    expect(youtubeVideoId(scrip.youtubeUrl), 'n633-siFdR8');
    expect(scrip.stocks.single.code, 'SHILCTECH');
    expect(scrip.stocks.single.name, 'Shilchar Technologies Ltd');
  });

  test('youtube links stay on the video id', () {
    expect(youtubeVideoId('https://youtu.be/n633-siFdR8'), 'n633-siFdR8');
    expect(
      youtubeVideoId('https://www.youtube.com/shorts/n633-siFdR8'),
      'n633-siFdR8',
    );
    expect(youtubeVideoId('https://example.com/watch?v=nope'), isNull);
  });

  test('expert calendar does not keep buys', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final calendar = CalendarController(prefs, NotificationService());
    await calendar.bindIsolated(MemorySeriesRepository());
    await Future<void>.delayed(Duration.zero);
    expect(calendar.series, isEmpty);
    expect(await calendar.resetCalendar(), isNull);
    expect(calendar.series, isEmpty);
    calendar.dispose();
  });

  testWidgets('expert pick opens the sample opinion screen', (tester) async {
    await pumpApp(tester);
    await register(tester);
    await tester.tap(find.text("Let's Get Started"));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Expert Pick Calendar'), findsOneWidget);
    expect(find.text('Coming Soon'), findsOneWidget);
    await tester.ensureVisible(find.text('Expert Pick Calendar'));
    await tester.tap(find.text('Expert Pick Calendar'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    tester.state<ScaffoldState>(find.byType(Scaffold).last).openDrawer();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.widgetWithText(ListTile, 'Expert Pick'), findsOneWidget);
    expect(find.widgetWithText(ListTile, 'Export'), findsNothing);
    expect(find.widgetWithText(ListTile, 'Month'), findsOneWidget);

    await tester.tap(find.widgetWithText(ListTile, 'Expert Pick'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(
      find.text(
        'Warning: Without expert import only a sample example will be shown',
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('OK'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final title = find.byWidgetPredicate(
      (widget) =>
          widget is Text && widget.textSpan?.toPlainText() == 'Expert Opinion',
    );
    expect(title, findsOneWidget);
    final opinion =
        (tester.widget<Text>(title).textSpan! as TextSpan).children!.last
            as TextSpan;
    expect(
      opinion.style?.color,
      Theme.of(tester.element(title)).colorScheme.primary,
    );
    final suggested = tester.widget<Text>(find.text('Stock Pick Suggested'));
    expect(
      suggested.style?.color,
      Theme.of(tester.element(find.text('Stock Pick Suggested')))
          .colorScheme
          .primary,
    );
    expect(find.text('Default Scrip'), findsOneWidget);
    expect(find.textContaining('Equitymaster'), findsOneWidget);
    expect(find.text('SHILCTECH'), findsOneWidget);
    expect(find.textContaining('18 Nov 2026'), findsOneWidget);

    final info = find.byTooltip('Stock name').first;
    await tester.ensureVisible(info);
    await tester.tap(info);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Shilchar Technologies Ltd'), findsOneWidget);
    expect(find.widgetWithText(TextButton, 'OK'), findsNothing);
    await tester.tap(find.byTooltip('Close'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    final add = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Add to Calendar'),
    );
    add.onPressed!.call();
    await tester.pumpAndSettle();
    expect(title, findsNothing);
    expect(find.text('SHILCTECH'), findsNothing);
  });

  testWidgets('stock switches share one right edge', (tester) async {
    tester.view.physicalSize = const Size(400, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(home: ExpertOpinionScreen()));
    await tester.pump();
    for (var i = 0; i < 20 && find.text('YASHO').evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    expect(find.text('YASHO'), findsOneWidget);
    expect(find.text('DDEVPLSTIK'), findsOneWidget);
    final switches = find.byType(Switch);
    expect(switches, findsNWidgets(5));
    final right = tester.getRect(switches.first).right;
    for (var i = 1; i < 5; i++) {
      expect(tester.getRect(switches.at(i)).right, closeTo(right, 0.5));
    }
  });
}
