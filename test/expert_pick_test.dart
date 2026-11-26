import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stock_calendar/expertpick/expert_calendar_screen.dart';
import 'package:stock_calendar/expertpick/expert_calendar_scope.dart';
import 'package:stock_calendar/expertpick/expert_import.dart';
import 'package:stock_calendar/expertpick/expert_landing_screen.dart';
import 'package:stock_calendar/expertpick/expert_simulation_store.dart';
import 'package:stock_calendar/expertpick/expert_opinion_screen.dart';
import 'package:stock_calendar/expertpick/expert_scrip.dart';
import 'package:stock_calendar/logic/dates.dart';
import 'package:stock_calendar/models/expert_run.dart';
import 'package:stock_calendar/expertpick/memory_series_repository.dart';
import 'package:stock_calendar/models/buy_series.dart';
import 'package:stock_calendar/services/notification_service.dart';
import 'package:stock_calendar/state/auth_controller.dart';
import 'package:stock_calendar/state/calendar_controller.dart';
import 'package:stock_calendar/state/theme_controller.dart';
import 'package:stock_calendar/widgets/buy_sheet.dart';

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

  test('a fresh list becomes one menu entry per title', () {
    final scrips = parseExpertList(
      File('assets/Freshlist.json').readAsStringSync(),
    );
    expect(scrips, hasLength(6));
    expect(scrips.first.title, '5 Smallcaps with a Strong Future Roadmap');
    expect(scrips.first.authorName, 'Equitymaster');
    expect(scrips.first.stocks, hasLength(5));
    expect(scrips[1].title, 'Stocks to buy now ? Dipan Mehta');
    expect(scrips[1].authorName, 'PaisaSmart');
    expect(scrips[1].investmentFirm, 'Elixir Equities Private Limited');
    expect(scrips[1].youtubeUrl, 'https://www.youtube.com/watch?v=nsJtoufLQFk');
    expect(formatPublishedDate(scrips[1].publishedDate), '19 Oct 2026');
    expect(scrips[1].stocks.map((stock) => stock.code), [
      'ELECTCAST',
      'CONFIPET',
      'ARIS',
      'AFFLE',
    ]);
    expect(
      expertScripLabels(scrips),
      scrips.map((scrip) => scrip.title).toList(),
    );
  });

  test('one expert object is one menu entry', () {
    final scrips = parseExpertList(
      File('assets/icon/veteran.json').readAsStringSync(),
    );
    expect(scrips, hasLength(1));
    expect(
      scrips.single.stocks.singleWhere((stock) => stock.code == 'YASHO').name,
      'Yasho Industries Ltd',
    );
  });

  test('repeated titles stay distinct in the menu', () {
    final labels = expertScripLabels([
      _named('Same'),
      _named('Same'),
      _named('Same (2)'),
    ]);
    expect(labels, ['Same', 'Same (2)', 'Same (2) (2)']);
  });

  test('imported fresh list is kept for the next visit', () async {
    final dir = await Directory.systemTemp.createTemp('expert-import');
    addTearDown(() async {
      if (dir.existsSync()) await dir.delete(recursive: true);
    });
    final raw = File('assets/Freshlist.json').readAsStringSync();
    final store = ExpertImportStore(directory: () async => dir);
    expect(await store.save(raw), isNull);
    expect(await store.save('[]'), 'The file could not be read.');
    expect(await store.save('{'), 'The file could not be read.');

    final again = ExpertImportStore(directory: () async => dir);
    final scrips = await again.read();
    expect(scrips, hasLength(6));
    expect(scrips[1].authorName, 'PaisaSmart');
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
    await _until(tester, find.text('No Expert Scrip Added to Calendar'));
    expect(find.text('Portfolio Exploration'), findsOneWidget);
    expect(find.text('by Experts'), findsOneWidget);
    expect(
      find.text(
        'Do you want to import a scrip from gdrive or use default one?',
      ),
      findsOneWidget,
    );
    expect(find.widgetWithText(TextButton, 'Import'), findsOneWidget);
    expect(find.widgetWithText(TextButton, 'Default'), findsOneWidget);
    expect(
      tester.getCenter(find.widgetWithText(TextButton, 'Import')).dx,
      lessThan(tester.getCenter(find.widgetWithText(TextButton, 'Default')).dx),
    );

    await tester.tap(find.widgetWithText(TextButton, 'Default'));
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
    expect(
      tester
          .widget<DropdownButtonFormField<String>>(
            find.byType(DropdownButtonFormField<String>).first,
          )
          .onChanged,
      isNull,
    );
    expect(find.textContaining('Equitymaster'), findsOneWidget);
    expect(find.text('SHILCTECH'), findsOneWidget);
    expect(find.textContaining('18 Oct 2026'), findsOneWidget);

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
      find.widgetWithText(FilledButton, expertPerformanceLabel),
    );
    add.onPressed!.call();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(
      find.text('Choose an allocation strategy and an amount.'),
      findsOneWidget,
    );
    expect(title, findsOneWidget);
    await tester.tap(find.text('OK'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('SHILCTECH'), findsOneWidget);

    tester.state<NavigatorState>(find.byType(Navigator).first).pop();
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    final landing = find.byType(ExpertLandingScreen);
    expect(landing, findsOneWidget);
    expect(find.byType(ExpertCalendarScreen), findsNothing);
    expect(find.text('Portfolio Exploration'), findsOneWidget);
    tester
        .state<ScaffoldState>(
          find.descendant(of: landing, matching: find.byType(Scaffold)),
        )
        .openDrawer();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.widgetWithText(ListTile, 'Expert Pick'), findsOneWidget);
    expect(find.widgetWithText(ListTile, 'Refresh Scrip'), findsOneWidget);
    expect(find.widgetWithText(ListTile, 'Show Calendar'), findsOneWidget);
    expect(
      find.widgetWithText(ListTile, 'Add to Personal Calendar'),
      findsOneWidget,
    );
    expect(find.widgetWithText(ListTile, 'Export'), findsNothing);
    expect(find.widgetWithText(ListTile, 'Month'), findsNothing);
    expect(find.widgetWithText(ListTile, 'Reset Calendar'), findsNothing);
    expect(find.widgetWithText(ListTile, 'Import'), findsNothing);
    await tester.tap(find.widgetWithText(ListTile, 'Expert Pick'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(
      find.text('Need Refresh Expert Scrip Added to Calendar?'),
      findsNothing,
    );
    expect(find.text('Default Scrip'), findsOneWidget);
  });

  testWidgets('leaving the empty expert prompt returns home', (tester) async {
    await _openExpertCalendar(tester);
    expect(find.text('No Expert Scrip Added to Calendar'), findsOneWidget);

    tester.state<NavigatorState>(find.byType(Navigator)).pop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('No Expert Scrip Added to Calendar'), findsNothing);
    expect(find.text('Open expert'), findsOneWidget);
  });

  testWidgets('import from the empty prompt opens expert opinion', (
    tester,
  ) async {
    const raw = '''
[
  {
    "Title": "Imported Roadmap",
    "author_name": "Imported Author",
    "investment_firm": "Imported Firm",
    "description": "Imported note",
    "published_date": "2026-10-19",
    "youtube_url": "https://www.youtube.com/watch?v=nsJtoufLQFk",
    "stocks": [{"stock_name": "Cast", "stock_code": "ELECTCAST"}]
  },
  {
    "Title": "Second Imported Scrip",
    "author_name": "Other",
    "investment_firm": "Other Firm",
    "description": "Other note",
    "published_date": "2026-01-02",
    "youtube_url": "",
    "stocks": [{"stock_name": "Affle", "stock_code": "AFFLE"}]
  }
]
''';
    _mockDrive(tester, () async => raw);
    await _openExpertCalendar(tester);

    await tester.tap(find.widgetWithText(TextButton, 'Import'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(
      find.text('Import the fresh expert pick file from your google drive'),
      findsNothing,
    );
    expect(find.text('2 expert scrips were imported.'), findsNothing);
    expect(find.text('No Expert Scrip Added to Calendar'), findsNothing);
    expect(find.text('Default Scrip'), findsNothing);
    expect(find.text('Imported Roadmap'), findsOneWidget);
    expect(find.text('ELECTCAST'), findsOneWidget);
    final scrip = tester.widget<DropdownButtonFormField<String>>(
      find.byType(DropdownButtonFormField<String>).first,
    );
    expect(scrip.onChanged, isNotNull);
    await tester.tap(find.byType(DropdownButtonFormField<String>).first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Second Imported Scrip'), findsWidgets);
  });

  testWidgets('a cancelled drive pick asks again', (tester) async {
    _mockDrive(tester, () async => null);
    await _openExpertCalendar(tester);

    await tester.tap(find.widgetWithText(TextButton, 'Import'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('No Expert Scrip Added to Calendar'), findsOneWidget);
    expect(find.text('Google Drive could not be opened.'), findsNothing);
    expect(find.text('Choose a file in Google Drive.'), findsNothing);
  });

  testWidgets('an unreadable drive file asks again after the error', (
    tester,
  ) async {
    _mockDrive(tester, () async => '{');
    await _openExpertCalendar(tester);

    await tester.tap(find.widgetWithText(TextButton, 'Import'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('The file could not be read.'), findsOneWidget);
    await tester.tap(find.text('OK'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('No Expert Scrip Added to Calendar'), findsOneWidget);
  });

  testWidgets('a calendar that already has buys skips the prompt', (
    tester,
  ) async {
    final store = ExpertSimulationStore(
      initial: [
        BuySeries(
          id: '1',
          stockName: 'Pine Labs Ltd',
          symbol: 'PINELABS',
          notes: 'From the expert scrip',
          anchorDate: DateTime(2026, 11, 20),
          frequency: RepeatFrequency.none,
          interval: 1,
          endType: RepeatEnd.forever,
          createdAt: DateTime.utc(2026, 11, 21),
        ),
      ],
    );

    await _openExpertCalendar(tester, simulations: store);
    await _until(tester, _expertOpinionTitle);
    expect(find.text('No Expert Scrip Added to Calendar'), findsNothing);
    expect(find.byType(ExpertCalendarScreen), findsNothing);
  });

  testWidgets('cancel leaves the calendar unchanged', (tester) async {
    var priced = false;
    await _openOpinion(
      tester,
      onPrices: (_, _, _) async {
        priced = true;
        return const {};
      },
    );

    await _choosePlan(tester);
    await tester.tap(find.widgetWithText(FilledButton, expertPerformanceLabel));
    await tester.pumpAndSettle();

    expect(find.text('Select a starting date for this scrip'), findsOneWidget);
    expect(find.text('November 2026'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(find.text('Select a starting date for this scrip'), findsNothing);
    expect(priced, isFalse);
    expect(find.text(expertPerformanceLabel), findsOneWidget);
  });

  testWidgets('buys start on the chosen date, not the published date', (
    tester,
  ) async {
    DateTime? requestedFrom;
    DateTime? requestedTo;
    List<BuySeries>? applied;
    ExpertRun? remembered;

    await _openOpinion(
      tester,
      onPrices: (_, from, to) async {
        requestedFrom = from;
        requestedTo = to;
        return const {
          'AAA': {'2026-11-20': 100, '2026-11-23': 100, '2026-11-24': 100},
        };
      },
      onApply: (buys) async {
        applied = buys;
        return null;
      },
      onRun: (run) => remembered = run,
    );

    await _choosePlan(tester);
    await tester.tap(find.widgetWithText(FilledButton, expertPerformanceLabel));
    await tester.pumpAndSettle();

    expect(find.text('Select a starting date for this scrip'), findsOneWidget);
    expect(find.text('November 2026'), findsOneWidget);

    await tester.tap(find.byTooltip('Previous month'));
    await tester.pump();
    expect(find.text('October 2026'), findsOneWidget);
    await tester.tap(find.byTooltip('Next month'));
    await tester.pump();
    expect(find.text('November 2026'), findsOneWidget);

    await tester.tap(find.text('25'));
    await tester.pump();
    expect(find.text('Select a starting date for this scrip'), findsOneWidget);
    expect(requestedFrom, isNull);

    await tester.tap(find.text('20'));
    await tester.pumpAndSettle();

    expect(requestedFrom, DateTime(2026, 11, 20));
    expect(requestedTo, DateTime(2026, 11, 24));
    expect(remembered?.published, DateTime(2026, 11, 20));
    expect(applied?.map((buy) => formatIsoDate(buy.anchorDate)).toList(), [
      '2026-11-20',
      '2026-11-23',
      '2026-11-24',
    ]);
    expect(find.text(expertPerformanceLabel), findsNothing);
  });

  testWidgets('stock switches share one right edge', (tester) async {
    tester.view.physicalSize = const Size(400, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    rootBundle.evict('assets/icon/veteran.json');
    await tester.pumpWidget(const MaterialApp(home: ExpertOpinionScreen()));
    await tester.pump();
    for (var i = 0; i < 20 && find.text('YASHO').evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    expect(find.text('YASHO'), findsOneWidget);
    expect(find.text('DDEVPLSTIK'), findsOneWidget);
    expect(find.text('Default Scrip'), findsOneWidget);
    final switches = find.byType(Switch);
    expect(switches, findsNWidgets(5));
    final right = tester.getRect(switches.first).right;
    for (var i = 1; i < 5; i++) {
      expect(tester.getRect(switches.at(i)).right, closeTo(right, 0.5));
    }
  });

  testWidgets('import keeps the fresh list for Expert Pick', (tester) async {
    final raw = File('assets/Freshlist.json').readAsStringSync();
    const channel = MethodChannel('stockcalendar/export');
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
      call,
    ) async {
      if (call.method == 'openDrive') return raw;
      return null;
    });
    addTearDown(() {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        null,
      );
    });

    final store = ExpertImportStore();
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(platform: TargetPlatform.android),
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => importExpertDriveFile(context, store: store),
              child: const Text('Import'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Import'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(
      find.text('Import the fresh expert pick file from your google drive'),
      findsOneWidget,
    );
    await tester.tap(find.text('OK'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('6 expert scrips were imported.'), findsOneWidget);
    final saved = await store.read();
    expect(saved.first.title, '5 Smallcaps with a Strong Future Roadmap');
    expect(saved[1].title, 'Stocks to buy now ? Dipan Mehta');
  });

  testWidgets('expert pick opens the last scrip without a refresh dialog', (
    tester,
  ) async {
    await _openExpertMenu(tester);
    await tester.ensureVisible(find.widgetWithText(ListTile, 'Expert Pick'));
    await tester.tap(find.widgetWithText(ListTile, 'Expert Pick'));
    await tester.pump();
    await _until(tester, _expertOpinionTitle);
    expect(
      find.text('Need Refresh Expert Scrip Added to Calendar?'),
      findsNothing,
    );

    tester.state<NavigatorState>(find.byType(Navigator)).pop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(ExpertCalendarScreen), findsOneWidget);
  });

  testWidgets('refresh scrip replaces the saved file and opens opinion', (
    tester,
  ) async {
    const fresh = '''
[
  {
    "Title": "Fresh Roadmap",
    "author_name": "Fresh Author",
    "investment_firm": "Fresh Firm",
    "description": "Fresh note",
    "published_date": "2026-10-19",
    "youtube_url": "",
    "stocks": [{"stock_name": "Cast", "stock_code": "ELECTCAST"}]
  }
]
''';
    _mockDrive(tester, () async => fresh);
    final store = ExpertImportStore();
    expect(await store.save(_olderImport), isNull);

    await _openExpertMenu(tester, store: store);
    await tester.tap(find.widgetWithText(ListTile, 'Refresh Scrip'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(
      find.text('Import the fresh expert pick file from your google drive'),
      findsOneWidget,
    );
    await tester.tap(find.text('OK'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('1 expert scrip was imported.'), findsOneWidget);
    await tester.tap(find.text('OK'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Fresh Roadmap'), findsOneWidget);
    expect(find.text('Older Roadmap'), findsNothing);
    expect((await store.read()).single.title, 'Fresh Roadmap');
  });

  testWidgets('a cancelled refresh scrip stays put', (tester) async {
    _mockDrive(tester, () async => null);
    final store = ExpertImportStore();
    expect(await store.save(_olderImport), isNull);
    await _openExpertMenu(tester, store: store);

    await tester.tap(find.widgetWithText(ListTile, 'Refresh Scrip'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('OK'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(
      find.text('Need Refresh Expert Scrip Added to Calendar?'),
      findsNothing,
    );
    expect(find.text('Google Drive could not be opened.'), findsNothing);
    expect(find.byType(ExpertCalendarScreen), findsOneWidget);
    expect((await store.read()).single.title, 'Older Roadmap');
  });

  testWidgets('an unreadable refresh scrip keeps the saved file', (
    tester,
  ) async {
    _mockDrive(tester, () async => '{');
    final store = ExpertImportStore();
    expect(await store.save(_olderImport), isNull);
    await _openExpertMenu(tester, store: store);

    await tester.tap(find.widgetWithText(ListTile, 'Refresh Scrip'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('OK'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('The file could not be read.'), findsOneWidget);
    await tester.tap(find.text('OK'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(
      find.text('Need Refresh Expert Scrip Added to Calendar?'),
      findsNothing,
    );
    expect(find.byType(ExpertCalendarScreen), findsOneWidget);
    expect((await store.read()).single.title, 'Older Roadmap');
  });

  testWidgets('an imported file replaces Default Scrip', (tester) async {
    tester.view.physicalSize = const Size(400, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final calendar = CalendarController(prefs, NotificationService());
    await calendar.bindIsolated(MemorySeriesRepository());
    addTearDown(calendar.dispose);
    final auth = AuthController(prefs, firebaseActive: false);
    final theme = ThemeController(prefs)..load();
    final store = ExpertImportStore();
    expect(
      await store.save(File('assets/Freshlist.json').readAsStringSync()),
      isNull,
    );

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<ThemeController>.value(value: theme),
          ChangeNotifierProvider<AuthController>.value(value: auth),
          ChangeNotifierProvider<CalendarController>.value(value: calendar),
        ],
        child: MaterialApp(home: ExpertCalendarScreen(imports: store)),
      ),
    );
    await tester.pump();

    tester.state<ScaffoldState>(find.byType(Scaffold)).openDrawer();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.widgetWithText(ListTile, 'Expert Pick'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(
      find.text('Need Refresh Expert Scrip Added to Calendar?'),
      findsNothing,
    );
    expect(find.text('Default Scrip'), findsNothing);
    expect(
      find.text('5 Smallcaps with a Strong Future Roadmap'),
      findsOneWidget,
    );
    expect(find.textContaining('Equitymaster'), findsOneWidget);
    expect(find.text('SHILCTECH'), findsOneWidget);
    expect(find.text('ELECTCAST'), findsNothing);
    expect(find.byType(Switch), findsNWidgets(5));

    await tester.tap(find.byType(DropdownButtonFormField<String>).first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Stocks to buy now ? Dipan Mehta').last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.textContaining('PaisaSmart'), findsOneWidget);
    expect(find.textContaining('Elixir Equities'), findsOneWidget);
    expect(find.textContaining('19 Oct 2026'), findsOneWidget);
    expect(find.text('ELECTCAST'), findsOneWidget);
    expect(find.text('AFFLE'), findsOneWidget);
    expect(find.text('SHILCTECH'), findsNothing);
    expect(find.text('YASHO'), findsNothing);
    expect(find.byType(Switch), findsNWidgets(4));
    expect(find.text('Default Scrip'), findsNothing);
  });

  testWidgets('show calendar stays closed when there is nothing to show', (
    tester,
  ) async {
    await _openExpertCalendar(tester);
    await tester.tap(find.widgetWithText(TextButton, 'Default'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    tester.state<NavigatorState>(find.byType(Navigator)).pop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final landing = find.byType(ExpertLandingScreen);
    tester
        .state<ScaffoldState>(
          find.descendant(of: landing, matching: find.byType(Scaffold)),
        )
        .openDrawer();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.widgetWithText(ListTile, 'Show Calendar'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text(nothingToShowOnCalendar), findsOneWidget);
    await tester.tap(find.text('OK'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(ExpertCalendarScreen), findsNothing);
    expect(find.text('Portfolio Exploration'), findsOneWidget);
  });

  testWidgets('show calendar opens when buys are saved', (tester) async {
    final store = ExpertSimulationStore(
      initial: [
        BuySeries(
          id: '1',
          stockName: 'Pine Labs Ltd',
          symbol: 'PINELABS',
          notes: 'From the expert scrip',
          anchorDate: DateTime(2026, 11, 20),
          frequency: RepeatFrequency.none,
          interval: 1,
          endType: RepeatEnd.forever,
          createdAt: DateTime.utc(2026, 11, 21),
        ),
      ],
    );
    await _openExpertCalendar(tester, simulations: store);
    await _until(tester, _expertOpinionTitle);
    tester.state<NavigatorState>(find.byType(Navigator)).pop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final landing = find.byType(ExpertLandingScreen);
    tester
        .state<ScaffoldState>(
          find.descendant(of: landing, matching: find.byType(Scaffold)),
        )
        .openDrawer();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.widgetWithText(ListTile, 'Show Calendar'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text(nothingToShowOnCalendar), findsNothing);
    expect(find.byType(ExpertCalendarScreen), findsOneWidget);
    tester
        .state<ScaffoldState>(
          find.descendant(
            of: find.byType(ExpertCalendarScreen),
            matching: find.byType(Scaffold),
          ),
        )
        .openDrawer();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.widgetWithText(ListTile, 'Month'), findsOneWidget);
    expect(find.widgetWithText(ListTile, 'Reset Calendar'), findsNothing);
  });

  testWidgets('add to personal calendar says it is on the way', (tester) async {
    await _openExpertCalendar(tester);
    await tester.tap(find.widgetWithText(TextButton, 'Default'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    tester.state<NavigatorState>(find.byType(Navigator)).pop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final landing = find.byType(ExpertLandingScreen);
    tester
        .state<ScaffoldState>(
          find.descendant(of: landing, matching: find.byType(Scaffold)),
        )
        .openDrawer();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.widgetWithText(ListTile, 'Add to Personal Calendar'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('On the way.'), findsOneWidget);
  });

  testWidgets('a chosen scrip opens expert opinion on the next visit', (
    tester,
  ) async {
    await _openExpertCalendar(tester);
    await tester.tap(find.widgetWithText(TextButton, 'Default'));
    await _until(tester, _expertOpinionTitle);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await _openExpertCalendar(tester, resetPrefs: false, waitForPrompt: false);
    await _until(tester, _expertOpinionTitle);
    expect(find.text('No Expert Scrip Added to Calendar'), findsNothing);
  });

  testWidgets('checking performance opens insight and returns to opinion', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final calendar = CalendarController(prefs, NotificationService());
    await calendar.bindIsolated(MemorySeriesRepository());
    addTearDown(calendar.dispose);

    const scrip = ExpertScrip(
      title: 'Roadmap',
      authorName: 'Ada',
      investmentFirm: 'Firm',
      description: 'A note',
      publishedDate: '2020-01-02',
      youtubeUrl: '',
      stocks: [ExpertStock(name: 'Stock A', code: 'AAA')],
    );

    await tester.pumpWidget(
      ChangeNotifierProvider<CalendarController>.value(
        value: calendar,
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => openExpertOpinion(
                  context,
                  scrips: const [scrip],
                  calendar: calendar,
                  clock: () => DateTime.utc(2026, 11, 23, 18, 30),
                  prices: (_, _, _) async => const {
                    'AAA': {
                      '2026-11-20': 100,
                      '2026-11-23': 100,
                      '2026-11-24': 100,
                    },
                  },
                ),
                child: const Text('Portfolio Exploration'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Portfolio Exploration'));
    await tester.pumpAndSettle();
    await _choosePlan(tester);
    await tester.tap(find.widgetWithText(FilledButton, expertPerformanceLabel));
    await tester.pumpAndSettle();
    await tester.tap(find.text('20'));
    await tester.pumpAndSettle();

    expect(find.text('Added 3 buys.'), findsOneWidget);
    expect(find.byType(ExpertCalendarScreen), findsNothing);
    expect(_expertOpinionTitle, findsNothing);
    await tester.tap(find.text('OK'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Expert Scrip Portfolio Insight'), findsOneWidget);
    await tester.tap(find.byTooltip('Back').hitTestable());
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Expert Scrip Portfolio Insight'), findsNothing);
    expect(_expertOpinionTitle, findsOneWidget);
    expect(find.text(fixedStockInvestedAmount), findsOneWidget);

    await tester.tap(find.byTooltip('Back').hitTestable());
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(_expertOpinionTitle, findsNothing);
    expect(find.text('Portfolio Exploration'), findsOneWidget);
  });

  testWidgets('expert calendar does not take a hand entered buy', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final calendar = CalendarController(prefs, NotificationService());
    await calendar.bindIsolated(MemorySeriesRepository());
    addTearDown(calendar.dispose);

    final existing = BuySeries(
      id: '1',
      stockName: 'Pine Labs Ltd',
      symbol: 'PINELABS',
      notes: 'From the expert scrip',
      anchorDate: DateTime(2026, 11, 20),
      frequency: RepeatFrequency.none,
      interval: 1,
      endType: RepeatEnd.forever,
      createdAt: DateTime.utc(2026, 11, 21),
    );

    await tester.pumpWidget(
      ChangeNotifierProvider<CalendarController>.value(
        value: calendar,
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => Column(
                children: [
                  TextButton(
                    onPressed: () =>
                        showBuySheet(context, day: DateTime(2026, 11, 20)),
                    child: const Text('Add'),
                  ),
                  TextButton(
                    onPressed: () => showBuySheet(
                      context,
                      day: DateTime(2026, 11, 20),
                      existing: existing,
                    ),
                    child: const Text('Open'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Add'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text(manualBuyDisabled), findsOneWidget);
    await tester.tap(find.text('OK'));
    await tester.pump();

    await tester.tap(find.text('Open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Buy'), findsOneWidget);
    expect(find.text('Remove'), findsNothing);
    final save = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Save'),
    );
    expect(save.onPressed, isNull);
    final fields = tester.widgetList<TextField>(find.byType(TextField));
    expect(fields, isNotEmpty);
    expect(fields.every((field) => field.readOnly), isTrue);
  });
}

Future<void> _openOpinion(
  WidgetTester tester, {
  required Future<Map<String, Map<String, double>>> Function(
    List<ExpertStock> basket,
    DateTime from,
    DateTime to,
  )
  onPrices,
  ApplyExpertBuys? onApply,
  void Function(ExpertRun run)? onRun,
}) async {
  tester.view.physicalSize = const Size(400, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  const scrip = ExpertScrip(
    title: 'Roadmap',
    authorName: 'Ada',
    investmentFirm: 'Firm',
    description: 'A note',
    publishedDate: '2020-01-02',
    youtubeUrl: '',
    stocks: [ExpertStock(name: 'Stock A', code: 'AAA')],
  );
  final screen = ExpertOpinionScreen(
    scrips: const [scrip],
    clock: () => DateTime.utc(2026, 11, 23, 18, 30),
    prices: onPrices,
    onApply: onApply,
    onRun: onRun,
  );

  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute<void>(builder: (_) => screen),
              );
            },
            child: const Text('Open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open'));
  await tester.pumpAndSettle();
}

Future<void> _choosePlan(WidgetTester tester) async {
  final dropdowns = find.byType(DropdownButtonFormField<String>);
  await tester.ensureVisible(dropdowns.at(1));
  await tester.tap(dropdowns.at(1));
  await tester.pumpAndSettle();
  await tester.tap(find.text(fixedStockInvestedAmount).last);
  await tester.pumpAndSettle();

  await tester.ensureVisible(
    find.byType(DropdownButtonFormField<String>).at(2),
  );
  await tester.tap(find.byType(DropdownButtonFormField<String>).at(2));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Rs 2000').last);
  await tester.pumpAndSettle();
  await tester.ensureVisible(
    find.widgetWithText(FilledButton, expertPerformanceLabel),
  );
}

Finder get _expertOpinionTitle => find.byWidgetPredicate(
  (widget) =>
      widget is Text && widget.textSpan?.toPlainText() == 'Expert Opinion',
);

Future<void> _until(WidgetTester tester, Finder finder) async {
  for (var i = 0; i < 40 && finder.evaluate().isEmpty; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
  expect(finder, findsOneWidget);
}

Future<void> _openExpertCalendar(
  WidgetTester tester, {
  ExpertSimulationStore? simulations,
  bool resetPrefs = true,
  bool waitForPrompt = true,
}) async {
  if (resetPrefs) SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final auth = AuthController(prefs, firebaseActive: false);
  final theme = ThemeController(prefs)..load();
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<ThemeController>.value(value: theme),
        ChangeNotifierProvider<AuthController>.value(value: auth),
      ],
      child: MaterialApp(
        theme: ThemeData(platform: TargetPlatform.android),
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) =>
                        ExpertCalendarScope(simulations: simulations),
                  ),
                );
              },
              child: const Text('Open expert'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open expert'));
  await _until(tester, find.text('Portfolio Exploration'));
  await tester.pump();
  if (waitForPrompt && simulations == null) {
    await _until(tester, find.text('No Expert Scrip Added to Calendar'));
  }
}

const _olderImport = '''
[
  {
    "Title": "Older Roadmap",
    "author_name": "Older Author",
    "investment_firm": "Older Firm",
    "description": "Older note",
    "published_date": "2026-09-01",
    "youtube_url": "",
    "stocks": [{"stock_name": "Old", "stock_code": "OLD"}]
  }
]
''';

Future<void> _openExpertMenu(
  WidgetTester tester, {
  ExpertImportStore? store,
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final calendar = CalendarController(prefs, NotificationService());
  await calendar.bindIsolated(MemorySeriesRepository());
  addTearDown(calendar.dispose);
  final auth = AuthController(prefs, firebaseActive: false);
  final theme = ThemeController(prefs)..load();
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<ThemeController>.value(value: theme),
        ChangeNotifierProvider<AuthController>.value(value: auth),
        ChangeNotifierProvider<CalendarController>.value(value: calendar),
      ],
      child: MaterialApp(
        theme: ThemeData(platform: TargetPlatform.android),
        home: ExpertCalendarScreen(imports: store ?? ExpertImportStore()),
      ),
    ),
  );
  await tester.pump();
  tester.state<ScaffoldState>(find.byType(Scaffold)).openDrawer();
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

void _mockDrive(WidgetTester tester, Future<Object?> Function() open) {
  const channel = MethodChannel('stockcalendar/export');
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
    call,
  ) async {
    if (call.method == 'openDrive') return open();
    return null;
  });
  addTearDown(() {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      null,
    );
  });
}

ExpertScrip _named(String title) {
  return ExpertScrip(
    title: title,
    authorName: '',
    investmentFirm: '',
    description: '',
    publishedDate: '',
    youtubeUrl: '',
    stocks: const [],
  );
}
