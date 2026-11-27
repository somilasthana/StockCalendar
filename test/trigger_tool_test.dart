import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stock_calendar/state/auth_controller.dart';
import 'package:stock_calendar/state/theme_controller.dart';
import 'package:stock_calendar/theme/calendar_theme.dart';
import 'package:stock_calendar/triggertool/trigger_date_picker.dart';
import 'package:stock_calendar/triggertool/trigger_entry.dart';
import 'package:stock_calendar/triggertool/trigger_file_store.dart';
import 'package:stock_calendar/triggertool/trigger_form_screen.dart';
import 'package:stock_calendar/triggertool/trigger_landing_screen.dart';
import 'package:stock_calendar/triggertool/trigger_list_controller.dart';
import 'package:stock_calendar/triggertool/trigger_list_screen.dart';
import 'package:stock_calendar/triggertool/trigger_search.dart';

import 'calendar_flow_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('rupee and trigger date text', () {
    expect(formatRupees(675), 'Rs 675');
    expect(formatRupees(675.5), 'Rs 675.5');
    expect(formatTriggerDate(DateTime(2026, 11, 26)), '26/11/2026');
    expect(formatTriggerDate(DateTime(2026, 1, 5)), '05/01/2026');
    expect(
      _entry('1', 'PB FINTECH', 'Policy Bazaar FinTech Ltd').summary,
      'Stop Loss: Rs 675, Target Price: Rs 1670, '
      'Trigger Price: Rs 1470, Trigger Date: 26/11/2026',
    );
  });

  test('search matches a symbol or a name and keeps spaces', () {
    final entries = [
      _entry('pb', 'PB FINTECH', 'Policy Bazaar FinTech Ltd'),
      _entry('hdfc', 'HDFC BANK', 'HDFC Bank Ltd'),
      _entry('x', 'XFINTECH', 'X Fintech Ltd'),
    ];

    expect(triggersMatching(entries, ''), entries);
    expect(_ids(triggersMatching(entries, 'fin')), ['pb', 'x']);
    expect(_ids(triggersMatching(entries, 'TECH')), ['pb', 'x']);
    expect(_ids(triggersMatching(entries, 'PB')), ['pb']);
    expect(_ids(triggersMatching(entries, 'policy')), ['pb']);
    expect(_ids(triggersMatching(entries, 'pb fin')), ['pb']);
    expect(triggersMatching(entries, 'pbfin'), isEmpty);
    expect(triggersMatching(entries, 'pb  fin'), isEmpty);
    expect(triggersMatching(entries, 'hdfcbank'), isEmpty);
    expect(_ids(triggersMatching(entries, 'hdfc bank')), ['hdfc']);
    expect(triggersMatching(entries, 'stop'), isEmpty);
    expect(triggersMatching(entries, 'trigger'), isEmpty);
    expect(triggersMatching(entries, 'target'), isEmpty);
    expect(triggersMatching(entries, '1470'), isEmpty);
  });

  test('a trigger date is a weekday from today onward', () {
    final today = DateTime(2026, 11, 25);
    expect(canChooseTriggerDate(today, today), isTrue);
    expect(canChooseTriggerDate(DateTime(2026, 11, 24), today), isFalse);
    expect(canChooseTriggerDate(DateTime(2026, 11, 28), today), isFalse);
    expect(canChooseTriggerDate(DateTime(2026, 11, 30), today), isTrue);
    expect(
      validateTriggerForm(
        symbol: '',
        name: 'Policy Bazaar',
        stopLoss: '10',
        targetPrice: '20',
        triggerPrice: '15',
        triggerDate: today,
      ),
      'Enter the stock symbol.',
    );
    expect(
      validateTriggerForm(
        symbol: 'PB',
        name: 'Policy Bazaar',
        stopLoss: '0',
        targetPrice: '20',
        triggerPrice: '15',
        triggerDate: today,
      ),
      'Enter a stop loss greater than zero.',
    );
    expect(
      validateTriggerForm(
        symbol: 'PB',
        name: 'Policy Bazaar',
        stopLoss: '10',
        targetPrice: '20',
        triggerPrice: '15',
        triggerDate: null,
      ),
      'Choose a trigger date.',
    );
    expect(
      validateTriggerForm(
        symbol: ' PB ',
        name: ' Policy Bazaar ',
        stopLoss: '1,670',
        targetPrice: '2000',
        triggerPrice: '1800.5',
        triggerDate: today,
      ),
      isNull,
    );
  });

  test('triggers are kept in a json file', () async {
    final dir = await Directory.systemTemp.createTemp('trigger-file');
    addTearDown(() async {
      if (dir.existsSync()) await dir.delete(recursive: true);
    });
    final store = TriggerFileStore(directory: () async => dir);
    final entry = _entry('pb', 'PB FINTECH', 'Policy Bazaar FinTech Ltd');
    expect(await store.write([entry]), isNull);
    final again = TriggerFileStore(directory: () async => dir);
    final saved = await again.read();
    expect(saved.single.symbol, 'PB FINTECH');
    expect(saved.single.checkFrequency, everyTwoHours);
    expect(saved.single.triggerDate, DateTime(2026, 11, 26));
    expect(
      File('${dir.path}${Platform.pathSeparator}triggers.json').existsSync(),
      isTrue,
    );

    final list = TriggerListController(store: again);
    await list.load();
    await list.remove('pb');
    expect(await again.read(), isEmpty);
  });

  test('delete removes one row when the symbol is repeated', () {
    final list = TriggerListController(
      entries: [
        _entry('a', 'PB FINTECH', 'Policy Bazaar FinTech Ltd'),
        _entry('b', 'PB FINTECH', 'Policy Bazaar FinTech Ltd', stopLoss: 700),
      ],
    );
    list.remove('missing');
    expect(list.count, 2);
    list.remove('a');
    expect(list.entries.single.id, 'b');
    expect(list.entries.single.stopLoss, 700);
  });

  testWidgets('auto trigger tool opens its landing page', (tester) async {
    await _openLanding(tester);

    expect(find.byType(TriggerLandingScreen), findsOneWidget);
    expect(find.text('for Investors'), findsOneWidget);
    expect(
      find.text(
        'This tool assists in adding buy trigger at certain conditions that can be met in future.',
      ),
      findsOneWidget,
    );

    final scaffold = find.descendant(
      of: find.byType(TriggerLandingScreen),
      matching: find.byType(Scaffold),
    );
    tester.state<ScaffoldState>(scaffold).openDrawer();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Add/See Triggers'), findsOneWidget);
    expect(find.text('Import Trigger'), findsOneWidget);
    expect(find.text('Export Trigger'), findsOneWidget);
    expect(find.text('Show Calendar'), findsOneWidget);
    expect(find.text('Reset Calendar'), findsOneWidget);
    expect(find.text('Add to Personal Calendar'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Dashboard'),
      80,
      scrollable: find.descendant(
        of: find.byType(Drawer),
        matching: find.byType(Scrollable),
      ),
    );
    expect(find.text('Dashboard'), findsOneWidget);
    expect(find.text('Dark theme'), findsOneWidget);
    expect(find.text('Stock Calendar AI'), findsWidgets);
    expect(find.text('owner@example.com'), findsOneWidget);
    expect(find.text('Home'), findsNothing);

    final theme = tester
        .element(find.text('Dark theme'))
        .read<ThemeController>();
    expect(theme.mode, ThemeMode.dark);
  });

  testWidgets('add/see triggers starts empty', (tester) async {
    await _openLanding(tester);
    final scaffold = find.descendant(
      of: find.byType(TriggerLandingScreen),
      matching: find.byType(Scaffold),
    );
    tester.state<ScaffoldState>(scaffold).openDrawer();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    await tester.tap(find.text('Add/See Triggers'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Stock Trigger List'), findsOneWidget);
    expect(find.text(triggerListIntro), findsOneWidget);
    expect(find.text('Number of Stocks: 0'), findsOneWidget);
    expect(find.text('Search stock...'), findsOneWidget);
    expect(find.text('Insert new trigger'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'fin');
    await tester.pump();
    expect(find.text('Number of Stocks: 0'), findsOneWidget);

    await tester.tap(find.text('Insert new trigger'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text(addTriggerTitle), findsOneWidget);
    expect(find.text(addTriggerIntro), findsOneWidget);
    expect(find.text('DD/MM/YYYY'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Add'), findsOneWidget);
    await tester.tap(find.byTooltip('Back'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Number of Stocks: 0'), findsOneWidget);

    tester
        .state<ScaffoldState>(
          find.descendant(
            of: find.byType(TriggerListScreen),
            matching: find.byType(Scaffold),
          ),
        )
        .openDrawer();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('Import Trigger'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('On the way.'), findsOneWidget);
  });

  testWidgets('a trigger row opens details and deletes after yes', (
    tester,
  ) async {
    final list = TriggerListController(
      entries: [
        _entry('pb', 'PB FINTECH', 'Policy Bazaar FinTech Ltd'),
        _entry('hdfc', 'HDFC BANK', 'HDFC Bank Ltd'),
        _entry('x', 'XFINTECH', 'X Fintech Ltd'),
      ],
    );
    await _pumpList(tester, list);

    expect(find.text('Number of Stocks: 3'), findsOneWidget);
    expect(find.byIcon(Icons.bolt), findsNWidgets(3));
    expect(find.text('PB FINTECH'), findsOneWidget);
    expect(find.text('HDFC BANK'), findsOneWidget);
    expect(find.textContaining('Stop Loss: Rs 675'), findsWidgets);

    await tester.enterText(find.byType(TextField), 'policy');
    await tester.pump();
    expect(find.text('Number of Stocks: 3'), findsOneWidget);
    expect(find.byIcon(Icons.bolt), findsOneWidget);
    expect(find.text('PB FINTECH'), findsOneWidget);
    expect(find.text('HDFC BANK'), findsNothing);
    expect(find.text('Policy Bazaar FinTech Ltd'), findsNothing);

    await tester.tap(find.byIcon(Icons.bolt));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Policy Bazaar FinTech Ltd'), findsOneWidget);
    expect(find.text('Stop Loss: Rs 675'), findsOneWidget);
    expect(find.text('Target Price: Rs 1670'), findsOneWidget);
    expect(find.text('Trigger Price: Rs 1470'), findsOneWidget);
    expect(find.text('Trigger Date: 26/11/2026'), findsOneWidget);

    await tester.tap(find.text('Delete'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Are you sure?'), findsOneWidget);
    await tester.tap(find.text('No'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Policy Bazaar FinTech Ltd'), findsOneWidget);
    expect(list.count, 3);

    await tester.tap(find.text('Delete'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Yes'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Are you sure?'), findsNothing);
    expect(find.text('Policy Bazaar FinTech Ltd'), findsNothing);
    expect(find.text('PB FINTECH'), findsNothing);
    expect(find.text('Number of Stocks: 2'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '');
    await tester.pump();
    expect(find.text('HDFC BANK'), findsOneWidget);
    expect(find.text('XFINTECH'), findsOneWidget);
    expect(find.text('PB FINTECH'), findsNothing);
  });

  testWidgets('add stores a trigger and returns to the list', (tester) async {
    final store = _MemoryStore();
    final list = TriggerListController(store: store);
    await _pumpList(tester, list, now: () => DateTime(2026, 11, 25));
    await tester.tap(find.text('Insert new trigger'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.widgetWithText(FilledButton, 'Add'));
    await tester.pump();
    expect(find.text('Enter the stock symbol.'), findsOneWidget);
    expect(find.text(addTriggerTitle), findsOneWidget);

    final fields = find.descendant(
      of: find.byType(TriggerFormScreen),
      matching: find.byType(TextField),
    );
    await tester.enterText(fields.at(0), 'PB FINTECH');
    await tester.enterText(fields.at(1), 'Policy Bazaar FinTech Ltd');
    await tester.enterText(fields.at(2), '0');
    await tester.enterText(fields.at(3), '1670');
    await tester.enterText(fields.at(4), '1470');
    await tester.tap(find.widgetWithText(FilledButton, 'Add'));
    await tester.pump();
    expect(find.text('Enter a stop loss greater than zero.'), findsOneWidget);
    await tester.enterText(fields.at(2), '675');

    await tester.ensureVisible(find.text('DD/MM/YYYY'));
    await tester.tap(find.text('DD/MM/YYYY'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('November 2026'), findsOneWidget);
    await tester.tap(find.text('20'));
    await tester.pump();
    expect(find.text('November 2026'), findsOneWidget);
    await tester.tap(find.text('28').last);
    await tester.pump();
    expect(find.text('November 2026'), findsOneWidget);
    await tester.tap(find.byTooltip('Next month'));
    await tester.pump();
    expect(find.text('December 2026'), findsOneWidget);
    await tester.tap(find.text('4').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('04/12/2026'), findsOneWidget);

    await tester.tap(find.text('04/12/2026'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('November 2026'), findsOneWidget);
    expect(find.text('December 2026'), findsNothing);
    await tester.tap(find.text('Cancel'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('04/12/2026'), findsOneWidget);

    await tester.tap(find.byTooltip('Frequency details'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text(frequencyNote), findsOneWidget);
    await tester.tap(find.byTooltip('Close'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text(frequencyNote), findsNothing);
    expect(find.text(everyTwoHours), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Add'));
    await tester.pumpAndSettle();

    expect(find.text('Stock Trigger List'), findsOneWidget);
    expect(find.text('Number of Stocks: 1'), findsOneWidget);
    expect(find.text('PB FINTECH'), findsOneWidget);
    expect(find.textContaining('Trigger Date: 04/12/2026'), findsOneWidget);
    expect(store.entries.single.checkFrequency, everyTwoHours);
    expect(store.entries.single.name, 'Policy Bazaar FinTech Ltd');
  });

  testWidgets('edit opens the saved trigger and save updates that row', (
    tester,
  ) async {
    final store = _MemoryStore([
      _entry('pb', 'PB FINTECH', 'Policy Bazaar FinTech Ltd'),
    ]);
    final list = TriggerListController(store: store);
    await list.load();
    await _pumpList(tester, list);
    await tester.pump();

    await tester.tap(find.text('PB FINTECH'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.byTooltip('Edit'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text(editTriggerTitle), findsOneWidget);
    expect(find.text(editTriggerIntro), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Save'), findsOneWidget);
    expect(find.text('Add'), findsNothing);
    expect(_field(tester, 0), 'PB FINTECH');
    expect(_field(tester, 1), 'Policy Bazaar FinTech Ltd');
    expect(_field(tester, 2), '675');
    expect(_field(tester, 4), '1470');
    expect(find.text('26/11/2026'), findsOneWidget);

    await tester.enterText(
      find
          .descendant(
            of: find.byType(TriggerFormScreen),
            matching: find.byType(TextField),
          )
          .at(0),
      'PB FINTECH PLUS',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    expect(find.byType(TriggerFormScreen), findsNothing);
    expect(find.text('Stock Trigger List'), findsOneWidget);
    expect(find.text('Number of Stocks: 1'), findsOneWidget);
    expect(find.text('PB FINTECH PLUS'), findsOneWidget);
    expect(find.text('PB FINTECH'), findsNothing);
    expect(store.entries.single.id, 'pb');
    expect(store.entries.single.symbol, 'PB FINTECH PLUS');
  });
}

TriggerEntry _entry(
  String id,
  String symbol,
  String name, {
  num stopLoss = 675,
}) {
  return TriggerEntry(
    id: id,
    symbol: symbol,
    name: name,
    stopLoss: stopLoss,
    targetPrice: 1670,
    triggerPrice: 1470,
    triggerDate: DateTime(2026, 11, 26),
  );
}

List<String> _ids(List<TriggerEntry> entries) {
  return entries.map((entry) => entry.id).toList();
}

Future<void> _openLanding(WidgetTester tester) async {
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
}

String _field(WidgetTester tester, int index) {
  final fields = find.descendant(
    of: find.byType(TriggerFormScreen),
    matching: find.byType(TextField),
  );
  return tester.widget<TextField>(fields.at(index)).controller!.text;
}

Future<void> _pumpList(
  WidgetTester tester,
  TriggerListController list, {
  DateTime Function()? now,
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final theme = ThemeController(prefs)..load();
  final auth = AuthController(prefs, firebaseActive: false);
  await auth.restore();
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: theme),
        ChangeNotifierProvider.value(value: auth),
      ],
      child: MaterialApp(
        theme: buildLightTheme(),
        darkTheme: buildDarkTheme(),
        themeMode: theme.mode,
        home: TriggerListScreen(controller: list, now: now),
      ),
    ),
  );
  await tester.pump();
}

class _MemoryStore implements TriggerStore {
  _MemoryStore([List<TriggerEntry> entries = const []])
    : entries = List<TriggerEntry>.of(entries);

  List<TriggerEntry> entries;

  @override
  Future<List<TriggerEntry>> read() async => List<TriggerEntry>.of(entries);

  @override
  Future<String?> write(List<TriggerEntry> next) async {
    entries = List<TriggerEntry>.of(next);
    return null;
  }
}
