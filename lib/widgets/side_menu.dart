import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../screens/account_screen.dart';
import '../state/calendar_controller.dart';
import '../state/theme_controller.dart';

class SideMenu extends StatelessWidget {
  const SideMenu({super.key, required this.email});

  final String email;

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeController>();
    final calendar = context.watch<CalendarController>();
    final scheme = Theme.of(context).colorScheme;

    return Drawer(
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: 8),
          children: [
            SwitchListTile(
              secondary: Icon(theme.mode == ThemeMode.dark ? Icons.dark_mode : Icons.light_mode),
              title: const Text('Dark theme'),
              value: theme.mode == ThemeMode.dark,
              onChanged: theme.setDark,
            ),
            const Divider(),
            _item(context, calendar, CalendarView.year, Icons.calendar_view_month, 'Year', scheme),
            _item(context, calendar, CalendarView.month, Icons.calendar_month, 'Month', scheme),
            _item(context, calendar, CalendarView.week, Icons.view_week, 'Week', scheme),
            _item(context, calendar, CalendarView.day, Icons.view_day, 'Day', scheme),
            const Divider(),
            ListTile(
              leading: CircleAvatar(
                backgroundColor: scheme.primary,
                foregroundColor: scheme.onPrimary,
                child: Text(email.isEmpty ? '?' : email[0].toUpperCase()),
              ),
              title: const Text('StockCalendar Lite'),
              subtitle: Text(email.isEmpty ? 'Not signed in' : email),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AccountScreen()),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _item(
    BuildContext context,
    CalendarController calendar,
    CalendarView view,
    IconData icon,
    String label,
    ColorScheme scheme,
  ) {
    final selected = calendar.view == view;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: ListTile(
        selected: selected,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        selectedTileColor: scheme.primaryContainer,
        leading: Icon(icon),
        title: Text(label),
        onTap: () {
          calendar.show(view);
          Navigator.pop(context);
        },
      ),
    );
  }
}
