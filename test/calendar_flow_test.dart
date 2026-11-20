import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stock_calendar/app.dart';
import 'package:stock_calendar/logic/dates.dart';
import 'package:stock_calendar/services/notification_service.dart';
import 'package:stock_calendar/state/auth_controller.dart';
import 'package:stock_calendar/state/calendar_controller.dart';
import 'package:stock_calendar/state/theme_controller.dart';

Future<void> pumpApp(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({});
  rootBundle.evict('assets/data.json');
  final prefs = await SharedPreferences.getInstance();
  final theme = ThemeController(prefs)..load();
  final auth = AuthController(prefs, firebaseActive: false);
  await auth.restore();
  final calendar = CalendarController(prefs, NotificationService());
  await tester.pumpWidget(
    MyStockApp(theme: theme, auth: auth, calendar: calendar),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

Future<void> pressSave(WidgetTester tester) async {
  final button = tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Save'));
  button.onPressed!.call();
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

Future<void> chooseView(WidgetTester tester, String label) async {
  tester.state<NavigatorState>(find.byType(Navigator).first).popUntil(
    (route) => route.settings.name == '/calendar' || route.isFirst,
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 200));
  tester.state<ScaffoldState>(find.byType(Scaffold).first).openDrawer();
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  tester.widget<ListTile>(find.widgetWithText(ListTile, label)).onTap!.call();
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

Future<void> enterCalendar(WidgetTester tester) async {
  final start = find.text("Let's Get Started");
  await tester.ensureVisible(start);
  await tester.tap(start);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
  final card = find.text('Personal Stock Calendar');
  await tester.ensureVisible(card);
  await tester.tap(card);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

Future<void> register(WidgetTester tester) async {
  final raw = await rootBundle.loadString('assets/data.json');
  final secret = (jsonDecode(raw) as Map<String, dynamic>)['secretKey'] as String;
  await tester.enterText(find.byType(TextField).at(0), 'owner@example.com');
  await tester.enterText(find.byType(TextField).at(1), '1234');
  await tester.enterText(find.byType(TextField).at(2), secret);
  await tester.tap(find.text('Registration'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

DateTime weekdayNear(DateTime today) {
  final day = dateOnly(today);
  if (!isWeekend(day)) return day;
  final earlier = addDays(day, day.weekday == DateTime.sunday ? -2 : -1);
  if (earlier.month == day.month) return earlier;
  return addDays(day, day.weekday == DateTime.saturday ? 2 : 1);
}

void main() {
  testWidgets('sign in, add a buy, and open the other views', (tester) async {
    await pumpApp(tester);

    expect(find.text('Stock Calendar AI'), findsOneWidget);
    expect(find.text('Secret Key'), findsOneWidget);
    await register(tester);
    await enterCalendar(tester);

    final today = dateOnly(DateTime.now());
    expect(find.text(monthTitle(today)), findsOneWidget);
    expect(find.text('Buys stay on this device until Firebase is connected.'), findsNothing);

    final closed = isWeekend(today) ? today : null;
    if (closed != null) {
      await tester.tap(find.text('${closed.day}').hitTestable());
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('Stock to buy'), findsNothing);
    }

    final openDay = weekdayNear(today);
    await tester.tap(find.text('${openDay.day}').hitTestable());
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Stock to buy'), findsWidgets);

    await tester.enterText(find.byType(TextField).at(0), 'ITC Limited');
    await tester.enterText(find.byType(TextField).at(1), 'itc');
    await pressSave(tester);

    expect(find.text('ITC Limited'), findsWidgets);

    await tester.tap(find.text('${openDay.day}').hitTestable());
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('ITC'), findsWidgets);

    tester.widget<ListTile>(find.widgetWithText(ListTile, 'ITC Limited')).onTap!.call();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.enterText(find.byType(TextField).at(0), 'ITC Hotels');
    await pressSave(tester);
    expect(find.text('ITC Hotels'), findsWidgets);

    await chooseView(tester, 'Week');
    expect(find.text(weekTitle(openDay)), findsOneWidget);

    await chooseView(tester, 'Day');
    expect(find.text('ITC Hotels'), findsOneWidget);

    await chooseView(tester, 'Year');
    expect(find.text('${openDay.year}'), findsOneWidget);
    final monthName = monthLong[openDay.month - 1];
    await tester.scrollUntilVisible(
      find.text(monthName),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text(monthName), findsOneWidget);
  });

  testWidgets('empty symbol is rejected', (tester) async {
    await pumpApp(tester);
    await register(tester);
    await enterCalendar(tester);

    final openDay = weekdayNear(dateOnly(DateTime.now()));
    await tester.tap(find.text('${openDay.day}').hitTestable());
    await tester.pump(const Duration(milliseconds: 300));
    await tester.enterText(find.byType(TextField).at(0), 'Reliance');
    await pressSave(tester);
    expect(find.text('Enter the stock symbol.'), findsOneWidget);
  });

  testWidgets('home control returns to the tool cards', (tester) async {
    await pumpApp(tester);
    await register(tester);
    await enterCalendar(tester);
    expect(find.text('Personal Stock Calendar').hitTestable(), findsNothing);

    await tester.tap(find.byTooltip('Home'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Personal Stock Calendar').hitTestable(), findsOneWidget);

    await tester.tap(find.text('Personal Stock Calendar').hitTestable());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.byTooltip('Open navigation menu'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    tester.widget<ListTile>(find.widgetWithText(ListTile, 'Home')).onTap!.call();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Personal Stock Calendar').hitTestable(), findsOneWidget);
    expect(find.byTooltip('Open navigation menu').hitTestable(), findsNothing);
  });

  testWidgets('wrong secret key stays on registration', (tester) async {
    await pumpApp(tester);
    await tester.enterText(find.byType(TextField).at(0), 'owner@example.com');
    await tester.enterText(find.byType(TextField).at(1), '1234');
    await tester.enterText(find.byType(TextField).at(2), 'wrong-key');
    await tester.tap(find.text('Registration'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Insert the correct secret key.'), findsOneWidget);
    expect(find.text('Registration'), findsOneWidget);
  });

  testWidgets('sign in after log out hides the secret key', (tester) async {
    await pumpApp(tester);
    await register(tester);
    final auth = Provider.of<AuthController>(
      tester.element(find.byType(Scaffold)),
      listen: false,
    );
    await auth.signOut();
    await tester.pump();
    expect(find.text('Sign In'), findsOneWidget);
    expect(find.text('Secret Key'), findsNothing);
    expect(find.text('Create an account'), findsNothing);
    expect(find.text('Forgot password'), findsNothing);
  });
}
