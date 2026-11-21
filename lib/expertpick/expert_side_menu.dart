import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../screens/account_screen.dart';
import '../screens/dashboard_screen.dart';
import '../screens/ledger_screen.dart';
import '../state/calendar_controller.dart';
import '../state/theme_controller.dart';

class ExpertSideMenu extends StatelessWidget {
  const ExpertSideMenu({
    super.key,
    required this.email,
    required this.onImport,
    required this.onExpertPick,
    required this.onReset,
  });

  final String email;
  final VoidCallback onImport;
  final VoidCallback onExpertPick;
  final VoidCallback onReset;

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
            ListTile(
              leading: const Icon(Icons.home_outlined),
              title: const Text('Home'),
              onTap: () {
                final navigator = Navigator.of(context);
                navigator.pop();
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (navigator.canPop()) navigator.pop();
                });
              },
            ),
            const Divider(),
            SwitchListTile(
              secondary: Icon(
                theme.mode == ThemeMode.dark
                    ? Icons.dark_mode
                    : Icons.light_mode,
              ),
              title: const Text('Dark theme'),
              value: theme.mode == ThemeMode.dark,
              onChanged: theme.setDark,
            ),
            const Divider(),
            _item(
              context,
              calendar,
              CalendarView.year,
              Icons.calendar_view_month,
              'Year',
              scheme,
            ),
            _item(
              context,
              calendar,
              CalendarView.month,
              Icons.calendar_month,
              'Month',
              scheme,
            ),
            _item(
              context,
              calendar,
              CalendarView.week,
              Icons.view_week,
              'Week',
              scheme,
            ),
            _item(
              context,
              calendar,
              CalendarView.day,
              Icons.view_day,
              'Day',
              scheme,
            ),
            _action(context, Icons.upload_file, 'Import', onImport),
            _action(
              context,
              Icons.workspace_premium_outlined,
              'Expert Pick',
              onExpertPick,
            ),
            _action(context, Icons.insights_outlined, 'Dashboard', () {
              _open(context, const DashboardScreen());
            }),
            _action(context, Icons.history, 'Retro', () {
              _open(context, const LedgerScreen());
            }),
            _action(context, Icons.restart_alt, 'Reset Calendar', onReset),
            const Divider(),
            ListTile(
              leading: CircleAvatar(
                backgroundColor: scheme.primary,
                foregroundColor: scheme.onPrimary,
                child: Text(email.isEmpty ? '?' : email[0].toUpperCase()),
              ),
              title: const Text('Stock Calendar AI'),
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

  void _open(BuildContext context, Widget screen) {
    final calendar = context.read<CalendarController>();
    Navigator.pop(context);
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => ChangeNotifierProvider<CalendarController>.value(
          value: calendar,
          child: screen,
        ),
      ),
    );
  }

  Widget _action(
    BuildContext context,
    IconData icon,
    String label,
    VoidCallback onTap,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        leading: Icon(icon),
        title: Text(label),
        onTap: () {
          if (label == 'Dashboard' || label == 'Retro') {
            onTap();
            return;
          }
          Navigator.pop(context);
          onTap();
        },
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
