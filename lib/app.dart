import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'screens/calendar_screen.dart';
import 'screens/login_screen.dart';
import 'state/auth_controller.dart';
import 'state/calendar_controller.dart';
import 'state/theme_controller.dart';
import 'theme/calendar_theme.dart';

class MyStockApp extends StatelessWidget {
  const MyStockApp({
    super.key,
    required this.theme,
    required this.auth,
    required this.calendar,
  });

  final ThemeController theme;
  final AuthController auth;
  final CalendarController calendar;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: theme),
        ChangeNotifierProvider.value(value: auth),
        ChangeNotifierProvider.value(value: calendar),
      ],
      child: Consumer<ThemeController>(
        builder: (context, themeController, _) {
          return MaterialApp(
            title: 'StockCalendar Lite',
            debugShowCheckedModeBanner: false,
            theme: buildLightTheme(),
            darkTheme: buildDarkTheme(),
            themeMode: themeController.mode,
            home: const RootScreen(),
          );
        },
      ),
    );
  }
}

class RootScreen extends StatelessWidget {
  const RootScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    if (auth.restoring) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (auth.uid == null) return const LoginScreen();
    return const CalendarScreen();
  }
}
