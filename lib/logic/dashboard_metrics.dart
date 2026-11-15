import 'dart:math' as math;

import '../models/daily_bar.dart';
import 'dates.dart';
import 'recurrence.dart';

/// Average of the open, high, low, and close values that are present.
double? dailyAverage({
  double? open,
  double? high,
  double? low,
  double? close,
}) {
  final values = <double>[?open, ?high, ?low, ?close];
  if (values.isEmpty) return null;
  return values.reduce((sum, value) => sum + value) / values.length;
}

double? barPrice(DailyBar bar) {
  return dailyAverage(
    open: bar.open,
    high: bar.high,
    low: bar.low,
    close: bar.close,
  );
}

/// Whole rupees and paise, so 7.004 and 7.001 compare as the same price.
int paise(double value) => (value * 100).round();

class SymbolCount {
  const SymbolCount({
    required this.symbol,
    required this.name,
    required this.count,
    required this.share,
  });

  final String symbol;
  final String name;
  final int count;

  /// Fraction of all buy days, from 0 to 1.
  final double share;
}

class DayPriceTotal {
  const DayPriceTotal({required this.date, required this.total});

  final DateTime date;
  final double total;
}

class EventDayReport {
  const EventDayReport({required this.days, required this.skippedSymbolDays});

  final List<DayPriceTotal> days;

  /// Symbol-days dropped because no price was found, including symbols
  /// that contributed nothing. Partial misses are [RangeReport.skippedBuyDays].
  final int skippedSymbolDays;
}

enum HistogramSpan { weekly, monthly, yearly }

class HistogramBar {
  const HistogramBar({
    required this.start,
    required this.total,
    required this.label,
  });

  final DateTime start;
  final double total;
  final String label;
}

class LinePoint {
  const LinePoint({
    required this.date,
    required this.price,
    required this.plannedBuy,
  });

  final DateTime date;
  final double price;
  final bool plannedBuy;
}

class RangePoint {
  const RangePoint({
    required this.symbol,
    required this.averagePurchase,
    required this.current,
    required this.buyDaysPriced,
    required this.buyDaysTotal,
  });

  final String symbol;
  final double averagePurchase;
  final double current;
  final int buyDaysPriced;
  final int buyDaysTotal;

  bool get flat => paise(current) == paise(averagePurchase);

  bool get above => paise(current) > paise(averagePurchase);

  double get lower => math.min(averagePurchase, current);

  double get upper => math.max(averagePurchase, current);

  double? get percentGap {
    if (averagePurchase == 0) return null;
    return (current - averagePurchase) / averagePurchase * 100;
  }
}

class RangeReport {
  const RangeReport({
    required this.points,
    required this.unpricedSymbols,
    required this.skippedBuyDays,
  });

  final List<RangePoint> points;
  final List<String> unpricedSymbols;

  /// Buy days skipped on symbols that still have a latest price and at
  /// least one priced buy day.
  final int skippedBuyDays;
}

const priceGapDays = 5;

List<SymbolCount> occurrenceCounts(List<DayBuy> buys) {
  final counts = <String, int>{};
  final names = <String, String>{};
  final latest = <String, DateTime>{};
  for (final buy in buys) {
    final symbol = buy.series.symbol;
    counts[symbol] = (counts[symbol] ?? 0) + 1;
    final date = dateOnly(buy.date);
    final previous = latest[symbol];
    if (previous == null || !date.isBefore(previous)) {
      latest[symbol] = date;
      names[symbol] = buy.series.stockName;
    }
  }
  final total = counts.values.fold<int>(0, (sum, count) => sum + count);
  final rows = [
    for (final symbol in counts.keys)
      SymbolCount(
        symbol: symbol,
        name: names[symbol] ?? symbol,
        count: counts[symbol]!,
        share: total == 0 ? 0 : counts[symbol]! / total,
      ),
  ]..sort((a, b) {
      final byCount = b.count.compareTo(a.count);
      if (byCount != 0) return byCount;
      return a.symbol.compareTo(b.symbol);
    });
  return rows;
}

List<String> symbolsOf(List<DayBuy> buys) {
  return {for (final buy in buys) buy.series.symbol}.toList()..sort();
}

/// Last bar on or before [day] that has a price.
///
/// When [maxGapDays] is set, a bar older than that many calendar days is
/// ignored. Buy days use this so a long gap is not treated as that day's price.
DailyBar? priceOnOrBefore(
  List<DailyBar> bars,
  DateTime day, {
  int? maxGapDays,
}) {
  final target = dateOnly(day);
  DailyBar? found;
  for (final bar in _sorted(bars)) {
    final date = dateOnly(bar.date);
    if (date.isAfter(target)) break;
    if (barPrice(bar) == null) continue;
    found = bar;
  }
  if (found == null) return null;
  if (maxGapDays != null) {
    final gap = target.difference(dateOnly(found.date)).inDays;
    if (gap > maxGapDays) return null;
  }
  return found;
}

EventDayReport eventDayTotals(
  List<DayBuy> buys,
  Map<String, List<DailyBar>> prices,
) {
  final byDate = <DateTime, List<DayBuy>>{};
  for (final buy in buys) {
    byDate.putIfAbsent(dateOnly(buy.date), () => []).add(buy);
  }
  final dates = byDate.keys.toList()..sort();
  final days = <DayPriceTotal>[];
  var skipped = 0;
  for (final date in dates) {
    var total = 0.0;
    var priced = 0;
    for (final buy in byDate[date]!) {
      final price = _priceFor(prices[buy.series.symbol], date, gap: priceGapDays);
      if (price == null) {
        skipped++;
        continue;
      }
      total += price;
      priced++;
    }
    if (priced > 0) {
      days.add(DayPriceTotal(date: date, total: total));
    }
  }
  return EventDayReport(days: days, skippedSymbolDays: skipped);
}

List<HistogramBar> histogramBars(List<DayPriceTotal> days, HistogramSpan span) {
  if (days.isEmpty) return const [];
  if (span == HistogramSpan.weekly) {
    final ordered = [...days]..sort((a, b) => a.date.compareTo(b.date));
    final withYear = _spansYears(ordered.map((day) => day.date));
    return [
      for (final day in ordered)
        HistogramBar(
          start: day.date,
          total: day.total,
          label: histogramLabel(day.date, span, withYear: withYear),
        ),
    ];
  }

  final groups = <String, _Bucket>{};
  for (final day in days) {
    final date = dateOnly(day.date);
    final key = switch (span) {
      HistogramSpan.monthly =>
        '${date.year}-${date.month}-${_weekOfMonth(date)}',
      HistogramSpan.yearly => '${date.year}-${date.month}',
      HistogramSpan.weekly => formatIsoDate(date),
    };
    final bucket = groups.putIfAbsent(key, () => _Bucket(date));
    if (date.isBefore(bucket.start)) bucket.start = date;
    bucket.total += day.total;
  }
  final buckets = groups.values.toList()
    ..sort((a, b) => a.start.compareTo(b.start));
  final withYear = _spansYears(buckets.map((bucket) => bucket.start));
  return [
    for (final bucket in buckets)
      HistogramBar(
        start: bucket.start,
        total: bucket.total,
        label: histogramLabel(bucket.start, span, withYear: withYear),
      ),
  ];
}

String histogramLabel(
  DateTime date,
  HistogramSpan span, {
  required bool withYear,
}) {
  final day = dateOnly(date);
  final month = monthShort[day.month - 1];
  switch (span) {
    case HistogramSpan.weekly:
      final text = '${day.day} $month';
      return withYear ? '$text ${day.year}' : text;
    case HistogramSpan.monthly:
      final text = '$month-week${_weekOfMonth(day)}';
      return withYear ? '$text ${day.year}' : text;
    case HistogramSpan.yearly:
      final year = (day.year % 100).toString().padLeft(2, '0');
      return '$month $year';
  }
}

List<LinePoint> pricePath({
  required List<DailyBar> bars,
  required Iterable<DateTime> buyDates,
  required DateTime firstBuy,
  required DateTime today,
}) {
  final start = dateOnly(firstBuy);
  final end = dateOnly(today);
  final planned = buyDates.map(dateOnly).toSet();
  final points = <LinePoint>[];
  for (final bar in _sorted(bars)) {
    final date = dateOnly(bar.date);
    if (date.isBefore(start) || date.isAfter(end)) continue;
    final price = barPrice(bar);
    if (price == null) continue;
    points.add(
      LinePoint(date: date, price: price, plannedBuy: planned.contains(date)),
    );
  }
  return points;
}

RangeReport rangeReport(
  List<DayBuy> buys,
  Map<String, List<DailyBar>> prices,
  DateTime today,
) {
  final bySymbol = <String, List<DateTime>>{};
  for (final buy in buys) {
    bySymbol.putIfAbsent(buy.series.symbol, () => []).add(dateOnly(buy.date));
  }
  final symbols = bySymbol.keys.toList()..sort();
  final end = dateOnly(today);
  final points = <RangePoint>[];
  final unpriced = <String>[];
  var skipped = 0;
  for (final symbol in symbols) {
    final bars = prices[symbol] ?? const <DailyBar>[];
    final current = _priceFor(bars, end);
    final dates = bySymbol[symbol]!..sort();
    final samples = <double>[];
    var missed = 0;
    for (final date in dates) {
      final price = _priceFor(bars, date, gap: priceGapDays);
      if (price == null) {
        missed++;
        continue;
      }
      samples.add(price);
    }
    if (current == null || samples.isEmpty) {
      unpriced.add(symbol);
      continue;
    }
    skipped += missed;
    final average = samples.reduce((sum, value) => sum + value) / samples.length;
    points.add(
      RangePoint(
        symbol: symbol,
        averagePurchase: average,
        current: current,
        buyDaysPriced: samples.length,
        buyDaysTotal: dates.length,
      ),
    );
  }
  return RangeReport(
    points: points,
    unpricedSymbols: unpriced,
    skippedBuyDays: skipped,
  );
}

DateTime? firstBuyOf(List<DayBuy> buys, String symbol) {
  DateTime? first;
  for (final buy in buys) {
    if (buy.series.symbol != symbol) continue;
    final date = dateOnly(buy.date);
    if (first == null || date.isBefore(first)) first = date;
  }
  return first;
}

int _weekOfMonth(DateTime date) => ((dateOnly(date).day - 1) ~/ 7) + 1;

bool _spansYears(Iterable<DateTime> dates) {
  final years = dates.map((date) => date.year).toSet();
  return years.length > 1;
}

double? _priceFor(List<DailyBar>? bars, DateTime day, {int? gap}) {
  if (bars == null || bars.isEmpty) return null;
  final bar = priceOnOrBefore(bars, day, maxGapDays: gap);
  if (bar == null) return null;
  return barPrice(bar);
}

List<DailyBar> _sorted(List<DailyBar> bars) {
  final copy = [...bars]..sort((a, b) => dateOnly(a.date).compareTo(dateOnly(b.date)));
  return copy;
}

class _Bucket {
  _Bucket(this.start);

  DateTime start;
  double total = 0;
}
