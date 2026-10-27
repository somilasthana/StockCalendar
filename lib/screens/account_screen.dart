import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/auth_controller.dart';
import '../state/calendar_controller.dart';

class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final email = auth.email ?? '';
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('StockCalendar Lite')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          CircleAvatar(
            radius: 32,
            backgroundColor: scheme.primary,
            foregroundColor: scheme.onPrimary,
            child: Text(
              email.isEmpty ? '?' : email[0].toUpperCase(),
              style: const TextStyle(fontSize: 28),
            ),
          ),
          const SizedBox(height: 16),
          Text(email, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 24),
          Text(
            'Alerts use India time. Each stock on a day notifies at 10:30am IST and again at 3:00pm IST. '
            'On a phone in Sydney that is 3:00pm and 7:30pm during Australian Eastern Standard Time, '
            'and one hour later during daylight saving.',
            style: TextStyle(color: scheme.onSurfaceVariant, height: 1.4),
          ),
          const SizedBox(height: 8),
          Text(
            'Snooze offers 5, 10, or 30 minutes and moves only the alert you tapped. Open the app now and then so the next alerts stay queued.',
            style: TextStyle(color: scheme.onSurfaceVariant, height: 1.4),
          ),
          if (kDebugMode) ...[
            const SizedBox(height: 24),
            OutlinedButton(
              onPressed: () async {
                await context.read<CalendarController>().sendTestAlert();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Test alert in about 10 seconds.')),
                  );
                }
              },
              child: const Text('Send a test alert'),
            ),
          ],
          const SizedBox(height: 24),
          FilledButton(
            onPressed: () async {
              await context.read<CalendarController>().bind(uid: null, firebase: auth.firebaseActive);
              await auth.signOut();
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Log out'),
          ),
        ],
      ),
    );
  }
}
