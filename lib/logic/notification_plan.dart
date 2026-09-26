import '../models/buy_series.dart';
import 'dates.dart';
import 'recurrence.dart';

/// One phone alert at an absolute UTC time.
class PlannedAlert {
  const PlannedAlert({
    required this.date,
    required this.slot,
    required this.stockName,
    required this.symbol,
    required this.instantUtc,
  });

  final DateTime date;
  final String slot;
  final String stockName;
  final String symbol;
  final DateTime instantUtc;

  String get title => stockName;

  String get body {
    final when = slot == 'open' ? 'Market open' : 'Market close';
    return '$symbol · $when';
  }
}

/// Alerts for the next [horizonDays] India dates, capped at [maxAlerts].
///
/// 10:30 and 15:00 are India time. A phone in another country fires at the
/// matching local time. 10:30 IST is 05:00 UTC, which is 3:00pm in Sydney
/// during Australian Eastern Standard Time.
List<PlannedAlert> planAlerts({
  required List<BuySeries> series,
  required DateTime nowUtc,
  int horizonDays = 21,
  int maxAlerts = 56,
}) {
  final today = indiaDate(nowUtc.toUtc());
  final end = addDays(today, horizonDays);
  final buys = buysBetween(series, today, end);
  final alerts = <PlannedAlert>[];

  for (final buy in buys) {
    for (final slot in const ['open', 'close']) {
      final hour = slot == 'open' ? 10 : 15;
      final minute = slot == 'open' ? 30 : 0;
      final instant = indiaInstant(buy.date, hour, minute);
      if (!instant.isAfter(nowUtc.toUtc())) continue;
      alerts.add(
        PlannedAlert(
          date: buy.date,
          slot: slot,
          stockName: buy.series.stockName,
          symbol: buy.series.symbol,
          instantUtc: instant,
        ),
      );
      if (alerts.length >= maxAlerts) return alerts;
    }
  }
  return alerts;
}
