import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'firebase_config.dart';
import 'firebase_options.dart';
import 'services/notification_service.dart';
import 'state/auth_controller.dart';
import 'state/calendar_controller.dart';
import 'state/theme_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  var firebaseReady = false;
  if (kFirebaseConfigured) {
    try {
      await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
      firebaseReady = true;
    } catch (_) {
      firebaseReady = false;
    }
  }

  final notifications = NotificationService();
  final prefs = await SharedPreferences.getInstance();
  final theme = ThemeController(prefs)..load();
  final auth = AuthController(prefs, firebaseActive: firebaseReady);
  await auth.restore();
  final calendar = CalendarController(prefs, notifications);

  runApp(MyStockApp(theme: theme, auth: auth, calendar: calendar));
  await notifications.init();
  await calendar.refreshAlerts();
}
