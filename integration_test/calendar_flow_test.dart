import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:stock_calendar/logic/dates.dart';
import 'package:stock_calendar/main.dart' as app;

Future<void> waitFor(WidgetTester tester, Finder finder) async {
  final end = DateTime.now().add(const Duration(seconds: 30));
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 200));
    if (finder.evaluate().isNotEmpty) return;
  }
  fail('Timed out waiting for $finder');
}

Future<void> openMenu(WidgetTester tester) async {
  final menu = find.byTooltip('Open navigation menu');
  await waitFor(tester, menu);
  await tester.tap(menu);
  await tester.pump(const Duration(milliseconds: 500));
}

Future<void> tapText(WidgetTester tester, String text) async {
  final visible = find.text(text).hitTestable();
  if (visible.evaluate().isNotEmpty) {
    await tester.tap(visible.first);
    await tester.pump(const Duration(milliseconds: 400));
    return;
  }
  final finder = find.text(text);
  await waitFor(tester, finder);
  await tester.ensureVisible(finder.last);
  await tester.tap(finder.last);
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('sign up, add a buy, walk the views, and send a test alert', (tester) async {
    await app.main();
    await waitFor(tester, find.text('Registration'));

    final raw = await rootBundle.loadString('assets/data.json');
    final secret = (jsonDecode(raw) as Map<String, dynamic>)['secretKey'] as String;
    await tester.enterText(find.byType(TextField).at(0), 'owner@example.com');
    await tester.enterText(find.byType(TextField).at(1), '1234');
    await tester.enterText(find.byType(TextField).at(2), secret);
    await tapText(tester, 'Registration');
    await waitFor(tester, find.text(monthTitle(dateOnly(DateTime.now()))));

    final today = dateOnly(DateTime.now());
    expect(isWeekend(today), isTrue);
    await tester.tap(find.text('${today.day}').hitTestable());
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Stock to buy'), findsNothing);

    final openDay = addDays(today, today.weekday == DateTime.sunday ? -2 : -1);
    await tapText(tester, '${openDay.day}');
    await waitFor(tester, find.text('Stock to buy'));
    await tester.enterText(find.byType(TextField).at(0), 'ITC Limited');
    await tester.enterText(find.byType(TextField).at(1), 'itc');
    await tapText(tester, 'Save');
    await waitFor(tester, find.text('ITC Limited'));

    await tapText(tester, '${openDay.day}');
    await waitFor(tester, find.text('ITC'));
    await tapText(tester, 'ITC Limited');
    await waitFor(tester, find.text('Stock to buy'));
    await tester.enterText(find.byType(TextField).at(0), 'ITC Hotels');
    await tapText(tester, 'Save');
    await waitFor(tester, find.text('ITC Hotels'));

    await openMenu(tester);
    await tapText(tester, 'Week');
    await waitFor(tester, find.text(weekTitle(openDay)));
    await openMenu(tester);
    await tapText(tester, 'Day');
    await waitFor(tester, find.text('ITC Hotels'));
    await openMenu(tester);
    await tapText(tester, 'Year');
    await waitFor(tester, find.text('${openDay.year}'));

    await openMenu(tester);
    await tapText(tester, 'StockCalendar Lite');
    await waitFor(tester, find.text('owner@example.com'));
    await tapText(tester, 'Send a test alert');
    await waitFor(tester, find.text('Test alert in about 10 seconds.'));
  });
}
