import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../logic/dates.dart';
import '../logic/notification_plan.dart';
import '../models/buy_series.dart';

const _channelId = 'stock_buys';
const _channelName = 'Stock buys';
const _channelDescription =
    'Reminders at 10:30am and 3:00pm India time on days you plan to buy.';

int stableNotificationId(String key) {
  var hash = 2166136261;
  for (final unit in key.codeUnits) {
    hash ^= unit;
    hash = (hash * 16777619) & 0x7fffffff;
  }
  return hash == 0 ? 1 : hash;
}

@pragma('vm:entry-point')
Future<void> notificationTapBackground(NotificationResponse response) async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService.ensureReady();
  await NotificationService.snoozeFromResponse(response);
}

class NotificationService {
  NotificationService();

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  static bool _ready = false;
  static bool notificationsGranted = true;
  static bool exactAlarmsGranted = true;

  static Future<void> ensureReady() async {
    if (_ready) return;
    tzdata.initializeTimeZones();
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    final darwin = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestSoundPermission: false,
      requestBadgePermission: false,
      notificationCategories: [
        DarwinNotificationCategory(
          'buy_alert',
          actions: [
            DarwinNotificationAction.plain('snooze_5', '5 min'),
            DarwinNotificationAction.plain('snooze_10', '10 min'),
            DarwinNotificationAction.plain('snooze_30', '30 min'),
          ],
        ),
      ],
    );
    try {
      await _plugin.initialize(
        settings: InitializationSettings(android: android, iOS: darwin),
        onDidReceiveNotificationResponse: snoozeFromResponse,
        onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
      );
      _ready = true;
    } catch (_) {
      _ready = false;
    }
  }

  Future<void> init() => ensureReady();

  Future<String?> reschedule(List<BuySeries> series) async {
    if (!_ready) return null;
    await _requestPermissions();
    await _plugin.cancelAll();
    final alerts = planAlerts(series: series, nowUtc: DateTime.now().toUtc());
    final groups = <String, List<PlannedAlert>>{};
    for (final alert in alerts) {
      final key = '${formatIsoDate(alert.date)}-${alert.slot}';
      groups.putIfAbsent(key, () => []).add(alert);
    }

    var used = 0;
    const maxAlerts = 60;
    for (final entry in groups.entries) {
      final items = entry.value;
      final summary = items.length > 1;
      final cost = items.length + (summary ? 1 : 0);
      if (used + cost > maxAlerts) break;
      for (final alert in items) {
        await _schedule(
          id: stableNotificationId(
            '${alert.symbol}|${formatIsoDate(alert.date)}|${alert.slot}',
          ),
          title: alert.title,
          body: alert.body,
          when: alert.instantUtc,
          payload: jsonEncode({
            'name': alert.stockName,
            'symbol': alert.symbol,
            'slot': alert.slot,
          }),
          groupKey: entry.key,
          actions: true,
        );
      }
      if (summary) {
        final slotLabel = items.first.slot == 'open' ? 'Market open' : 'Market close';
        await _schedule(
          id: stableNotificationId('summary|${entry.key}'),
          title: slotLabel,
          body: '${items.length} stocks to buy',
          when: items.first.instantUtc,
          payload: '',
          groupKey: entry.key,
          actions: false,
          summary: true,
        );
      }
      used += cost;
    }

    if (!notificationsGranted) {
      return 'Turn on notifications so buy alerts can appear.';
    }
    if (!exactAlarmsGranted) {
      return 'Allow alarms and reminders so alerts arrive at 10:30am and 3:00pm India time.';
    }
    return null;
  }

  Future<void> cancelAll() async {
    if (!_ready) return;
    await _plugin.cancelAll();
  }

  Future<void> showTestAlert() async {
    if (!_ready) return;
    await _requestPermissions();
    final when = DateTime.now().toUtc().add(const Duration(seconds: 10));
    await _schedule(
      id: stableNotificationId('test-${when.millisecondsSinceEpoch}'),
      title: 'ITC',
      body: 'ITC · Market open',
      when: when,
      payload: jsonEncode({'name': 'ITC', 'symbol': 'ITC', 'slot': 'open'}),
      groupKey: 'test',
      actions: true,
    );
  }

  static Future<void> snoozeFromResponse(NotificationResponse response) async {
    final minutes = switch (response.actionId) {
      'snooze_5' => 5,
      'snooze_10' => 10,
      'snooze_30' => 30,
      _ => null,
    };
    if (minutes == null || response.payload == null || response.payload!.isEmpty) {
      return;
    }
    await ensureReady();
    if (!_ready) return;
    final data = jsonDecode(response.payload!) as Map<String, dynamic>;
    final name = data['name'] as String? ?? 'Stock';
    final symbol = data['symbol'] as String? ?? '';
    final slot = data['slot'] as String? ?? 'open';
    final whenLabel = slot == 'open' ? 'Market open' : 'Market close';
    final when = DateTime.now().toUtc().add(Duration(minutes: minutes));
    await _schedule(
      id: stableNotificationId('snooze|$symbol|$slot|${when.millisecondsSinceEpoch}'),
      title: name,
      body: '$symbol · $whenLabel',
      when: when,
      payload: response.payload!,
      groupKey: 'snooze',
      actions: true,
    );
  }

  static bool _askedPermission = false;

  static Future<void> _requestPermissions() async {
    if (_askedPermission) return;
    _askedPermission = true;
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      notificationsGranted = await android.requestNotificationsPermission() ?? true;
      exactAlarmsGranted = await android.requestExactAlarmsPermission() ?? true;
    }
    final ios = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    if (ios != null) {
      notificationsGranted =
          await ios.requestPermissions(alert: true, badge: false, sound: true) ??
              false;
    }
  }

  static Future<void> _schedule({
    required int id,
    required String title,
    required String body,
    required DateTime when,
    required String payload,
    required String groupKey,
    required bool actions,
    bool summary = false,
  }) async {
    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDescription,
        importance: Importance.max,
        priority: Priority.high,
        groupKey: groupKey,
        setAsGroupSummary: summary,
        actions: actions
            ? const [
                AndroidNotificationAction('snooze_5', '5 min'),
                AndroidNotificationAction('snooze_10', '10 min'),
                AndroidNotificationAction('snooze_30', '30 min'),
              ]
            : null,
      ),
      iOS: DarwinNotificationDetails(
        categoryIdentifier: actions ? 'buy_alert' : null,
        threadIdentifier: groupKey,
      ),
    );
    final scheduled = tz.TZDateTime.from(when.toUtc(), tz.UTC);
    final mode = exactAlarmsGranted
        ? AndroidScheduleMode.exactAllowWhileIdle
        : AndroidScheduleMode.inexactAllowWhileIdle;
    try {
      await _plugin.zonedSchedule(
        id: id,
        title: title,
        body: body,
        scheduledDate: scheduled,
        notificationDetails: details,
        androidScheduleMode: mode,
        payload: payload,
      );
    } catch (_) {
      if (mode == AndroidScheduleMode.exactAllowWhileIdle) {
        exactAlarmsGranted = false;
        await _plugin.zonedSchedule(
          id: id,
          title: title,
          body: body,
          scheduledDate: scheduled,
          notificationDetails: details,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          payload: payload,
        );
      }
    }
  }
}
