import 'package:flutter/material.dart';

@immutable
class CalendarColors extends ThemeExtension<CalendarColors> {
  const CalendarColors({
    required this.weekend,
    required this.today,
    required this.onToday,
    required this.chipBackground,
    required this.chipForeground,
    required this.gridLine,
    required this.outside,
    required this.closed,
    required this.selected,
  });

  final Color weekend;
  final Color today;
  final Color onToday;
  final Color chipBackground;
  final Color chipForeground;
  final Color gridLine;
  final Color outside;
  final Color closed;
  final Color selected;

  static const light = CalendarColors(
    weekend: Color(0xFFD93025),
    today: Color(0xFF1A73E8),
    onToday: Colors.white,
    chipBackground: Color(0xFFE8F0FE),
    chipForeground: Color(0xFF174EA6),
    gridLine: Color(0xFFE8EAED),
    outside: Color(0xFF70757A),
    closed: Color(0xFFF8F9FA),
    selected: Color(0xFF1A73E8),
  );

  static const dark = CalendarColors(
    weekend: Color(0xFFF28B82),
    today: Color(0xFF8AB4F8),
    onToday: Color(0xFF202124),
    chipBackground: Color(0xFF3C4043),
    chipForeground: Color(0xFFE8F0FE),
    gridLine: Color(0xFF3C4043),
    outside: Color(0xFF9AA0A6),
    closed: Color(0xFF292A2D),
    selected: Color(0xFF8AB4F8),
  );

  @override
  CalendarColors copyWith({
    Color? weekend,
    Color? today,
    Color? onToday,
    Color? chipBackground,
    Color? chipForeground,
    Color? gridLine,
    Color? outside,
    Color? closed,
    Color? selected,
  }) {
    return CalendarColors(
      weekend: weekend ?? this.weekend,
      today: today ?? this.today,
      onToday: onToday ?? this.onToday,
      chipBackground: chipBackground ?? this.chipBackground,
      chipForeground: chipForeground ?? this.chipForeground,
      gridLine: gridLine ?? this.gridLine,
      outside: outside ?? this.outside,
      closed: closed ?? this.closed,
      selected: selected ?? this.selected,
    );
  }

  @override
  CalendarColors lerp(ThemeExtension<CalendarColors>? other, double t) {
    if (other is! CalendarColors) return this;
    return CalendarColors(
      weekend: Color.lerp(weekend, other.weekend, t)!,
      today: Color.lerp(today, other.today, t)!,
      onToday: Color.lerp(onToday, other.onToday, t)!,
      chipBackground: Color.lerp(chipBackground, other.chipBackground, t)!,
      chipForeground: Color.lerp(chipForeground, other.chipForeground, t)!,
      gridLine: Color.lerp(gridLine, other.gridLine, t)!,
      outside: Color.lerp(outside, other.outside, t)!,
      closed: Color.lerp(closed, other.closed, t)!,
      selected: Color.lerp(selected, other.selected, t)!,
    );
  }
}

CalendarColors calendarColors(BuildContext context) {
  return Theme.of(context).extension<CalendarColors>() ?? CalendarColors.light;
}

ThemeData buildLightTheme() {
  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xFF1A73E8),
      brightness: Brightness.light,
    ),
    scaffoldBackgroundColor: Colors.white,
  );
  return base.copyWith(
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      foregroundColor: Color(0xFF3C4043),
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: Color(0xFF1A73E8),
      foregroundColor: Colors.white,
    ),
    drawerTheme: const DrawerThemeData(backgroundColor: Colors.white),
    extensions: const [CalendarColors.light],
  );
}

ThemeData buildDarkTheme() {
  const background = Color(0xFF202124);
  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xFF8AB4F8),
      brightness: Brightness.dark,
      surface: background,
    ),
    scaffoldBackgroundColor: background,
  );
  return base.copyWith(
    appBarTheme: const AppBarTheme(
      backgroundColor: background,
      foregroundColor: Color(0xFFE8EAED),
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: Color(0xFF8AB4F8),
      foregroundColor: Color(0xFF202124),
    ),
    drawerTheme: const DrawerThemeData(backgroundColor: Color(0xFF2D2E30)),
    extensions: const [CalendarColors.dark],
  );
}
