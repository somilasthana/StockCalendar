import '../models/buy_series.dart';
import 'dates.dart';

/// A buy shown on one calendar day.
///
/// If two saved series land on the same symbol that day, only the one that
/// was added first is kept.
class DayBuy {
  const DayBuy({required this.date, required this.series});

  final DateTime date;
  final BuySeries series;
}

class _MonthHit {
  const _MonthHit(this.date, this.counts);
  final DateTime date;
  final bool counts;
}

_MonthHit _monthHit(DateTime anchor, int monthOffset) {
  final total = (anchor.month - 1) + monthOffset;
  final year = anchor.year + total ~/ 12;
  final month = total % 12 + 1;
  if (anchor.day > daysInMonth(year, month)) {
    return _MonthHit(lastWeekdayOfMonth(year, month), true);
  }
  final date = DateTime(year, month, anchor.day);
  return _MonthHit(date, !isWeekend(date));
}

Iterable<DateTime> _candidates(BuySeries series) sync* {
  final anchor = dateOnly(series.anchorDate);
  switch (series.frequency) {
    case RepeatFrequency.none:
      yield anchor;
    case RepeatFrequency.days:
      var date = anchor;
      for (var guard = 0; guard < 20000; guard++) {
        yield date;
        date = addWeekdays(date, series.interval);
      }
    case RepeatFrequency.weeks:
      var date = anchor;
      for (var guard = 0; guard < 5000; guard++) {
        yield date;
        date = addDays(date, 7);
      }
    case RepeatFrequency.months:
    case RepeatFrequency.years:
      final yearly = series.frequency == RepeatFrequency.years;
      for (var step = 0; step < 2400; step++) {
        final hit = _monthHit(anchor, yearly ? step * 12 : step);
        if (hit.counts) yield hit.date;
      }
  }
}

/// Dates this series occupies inside [from] and [to], including both ends.
///
/// Saturday and Sunday are never returned. Weekday holidays are ordinary
/// days: they are added and they count toward "N times".
List<DateTime> expandSeries(
  BuySeries series, {
  required DateTime from,
  required DateTime to,
}) {
  final windowStart = dateOnly(from);
  final windowEnd = dateOnly(to);
  if (windowEnd.isBefore(windowStart)) return const [];
  if (isWeekend(series.anchorDate)) return const [];

  final until = series.endType == RepeatEnd.until ? series.untilDate : null;
  final cut = series.cutBefore;
  final limit = series.endType == RepeatEnd.count ? series.count ?? 0 : null;
  if (limit != null && limit <= 0) return const [];

  final results = <DateTime>[];
  var placed = 0;
  for (final raw in _candidates(series)) {
    final date = dateOnly(raw);
    if (cut != null && !date.isBefore(cut)) break;
    if (until != null && date.isAfter(dateOnly(until))) break;
    if (limit != null && placed >= limit) break;
    if (date.isAfter(windowEnd)) break;
    if (!date.isBefore(windowStart)) results.add(date);
    placed++;
    if (series.frequency == RepeatFrequency.none) break;
  }
  return results;
}

List<DayBuy> buysBetween(List<BuySeries> seriesList, DateTime from, DateTime to) {
  final grouped = <String, List<BuySeries>>{};
  for (final series in seriesList) {
    for (final date in expandSeries(series, from: from, to: to)) {
      grouped.putIfAbsent(formatIsoDate(date), () => []).add(series);
    }
  }

  final keys = grouped.keys.toList()..sort();
  final result = <DayBuy>[];
  for (final key in keys) {
    final items = grouped[key]!..sort((a, b) {
      final byTime = a.createdAt.compareTo(b.createdAt);
      if (byTime != 0) return byTime;
      return a.id.compareTo(b.id);
    });
    final seen = <String>{};
    for (final series in items) {
      if (seen.add(series.symbol)) {
        result.add(DayBuy(date: parseIsoDate(key), series: series));
      }
    }
  }
  return result;
}

List<DayBuy> buysOn(List<BuySeries> seriesList, DateTime day) {
  final date = dateOnly(day);
  return buysBetween(seriesList, date, date);
}

bool symbolTakenOn(
  List<BuySeries> seriesList,
  DateTime day,
  String symbol, {
  String? ignoreSeriesId,
}) {
  final normalized = normalizeSymbol(symbol);
  if (normalized.isEmpty) return false;
  return buysOn(seriesList, day).any(
    (buy) => buy.series.symbol == normalized && buy.series.id != ignoreSeriesId,
  );
}
