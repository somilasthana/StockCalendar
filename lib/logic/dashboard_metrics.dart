import 'dart:math' as math;

import '../models/daily_bar.dart';
import '../models/expert_run.dart';
import 'dates.dart';
import 'recurrence.dart';

/// Average of the open, high, low, and close values that are present.
double? dailyAverage({double? open, double? high, double? low, double? close}) {
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

/// Dashboard price is a positive closing price.
double? quotedPrice(DailyBar bar) {
  final close = bar.close;
  if (close == null || close <= 0) return null;
  return close;
}

/// Personal counts one share on each buy. Expert uses the stored share count.
int _sharesBought(DayBuy buy, {required bool expert}) {
  if (!expert) return 1;
  final shares = buy.series.numberOfShares;
  return shares < 1 ? 1 : shares;
}

/// Portfolio worth prefers the close. A session that has not closed yet uses
/// that day's open, so the latest weekday is still plotted.
double? worthMark(DailyBar bar) {
  final close = bar.close;
  if (close != null && close > 0) return close;
  final open = bar.open;
  if (open != null && open > 0) return open;
  return null;
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

/// One open market day on the portfolio-worth chart.
class WorthPoint {
  const WorthPoint({
    required this.date,
    required this.invested,
    required this.worth,
  });

  final DateTime date;

  /// Money invested through the end of [date]. Expert adds the dropdown amount
  /// once per plotted day. Personal adds each buy's closing price, so a day
  /// with no buy keeps the previous total.
  final double invested;

  /// Shares held at the end of [date], including a buy that day, times that day's close or open.
  final double worth;
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

class PortfolioGain {
  const PortfolioGain({
    required this.invested,
    required this.current,
    required this.pricedBuys,
    required this.unpricedSymbols,
    required this.skippedBuyDays,
  });

  /// Money paid on priced buy days. Each day contributes its close times the
  /// shares bought. Personal counts one share. Expert uses the stored count.
  final double invested;

  /// What those same buys are worth at the latest close.
  final double current;

  final int pricedBuys;
  final List<String> unpricedSymbols;

  /// Buy days with no price on that exact date. Days on an unpriced symbol
  /// are not included.
  final int skippedBuyDays;

  double get amount => current - invested;

  /// Change against the amount invested. Null when nothing was invested.
  double? get percent {
    if (invested == 0) return null;
    return (current - invested) / invested * 100;
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
  final rows =
      [
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

/// Stocks that were actually bought. A symbol that never got a buy is absent.
int uniqueBoughtStocks(List<DayBuy> buys) => symbolsOf(buys).length;

class SymbolInvestment {
  const SymbolInvestment({
    required this.symbol,
    required this.name,
    required this.amount,
    required this.share,
  });

  final String symbol;
  final String name;

  /// Shares bought times the latest close.
  final double amount;

  /// [amount] divided by the portfolio's current value, from 0 to 1.
  final double share;
}

/// Current value of each symbol: shares bought times the latest close.
///
/// Personal counts one share per buy. Expert uses the stored share count.
/// A symbol with no close on or before [today] is left out, and its shares
/// are not part of the total.
List<SymbolInvestment> holdingValueBySymbol(
  List<DayBuy> buys,
  Map<String, List<DailyBar>> prices,
  DateTime today, {
  bool expert = true,
}) {
  final shares = <String, int>{};
  final names = <String, String>{};
  final latestBuy = <String, DateTime>{};
  for (final buy in buys) {
    final symbol = buy.series.symbol;
    shares[symbol] = (shares[symbol] ?? 0) + _sharesBought(buy, expert: expert);
    final date = dateOnly(buy.date);
    final previous = latestBuy[symbol];
    if (previous == null || !date.isBefore(previous)) {
      latestBuy[symbol] = date;
      names[symbol] = buy.series.stockName;
    }
  }
  final end = dateOnly(today);
  final amounts = <String, double>{};
  for (final symbol in shares.keys) {
    final count = shares[symbol]!;
    if (count < 1) continue;
    final price = _priceFor(prices[symbol], end);
    if (price == null) continue;
    final value = price * count;
    if (value <= 0) continue;
    amounts[symbol] = value;
  }
  final total = amounts.values.fold<double>(0, (sum, amount) => sum + amount);
  final rows =
      [
        for (final symbol in amounts.keys)
          SymbolInvestment(
            symbol: symbol,
            name: names[symbol] ?? symbol,
            amount: amounts[symbol]!,
            share: total == 0 ? 0 : amounts[symbol]! / total,
          ),
      ]..sort((a, b) {
        final byAmount = b.amount.compareTo(a.amount);
        if (byAmount != 0) return byAmount;
        return a.symbol.compareTo(b.symbol);
      });
  return rows;
}

/// Shares across the buys already on the dashboard.
int portfolioShareCount(List<DayBuy> buys) {
  var total = 0;
  for (final buy in buys) {
    total += buy.series.numberOfShares;
  }
  return total;
}

/// Last bar on or before [day] that has a closing price.
///
/// Buy days use [exactDayPrice] instead, so an older close is not treated as
/// that day's price.
DailyBar? priceOnOrBefore(List<DailyBar> bars, DateTime day) {
  final target = dateOnly(day);
  DailyBar? found;
  for (final bar in _sorted(bars)) {
    final date = dateOnly(bar.date);
    if (date.isAfter(target)) break;
    if (quotedPrice(bar) == null) continue;
    found = bar;
  }
  return found;
}

EventDayReport eventDayTotals(
  List<DayBuy> buys,
  Map<String, List<DailyBar>> prices, {
  bool expert = false,
}) {
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
      final bars = prices[buy.series.symbol];
      final price = exactDayPrice(bars, date);
      if (price == null) {
        skipped++;
        continue;
      }
      final shares = _sharesBought(buy, expert: expert);
      total += price * shares;
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
    final price = quotedPrice(bar);
    if (price == null) continue;
    points.add(
      LinePoint(date: date, price: price, plannedBuy: planned.contains(date)),
    );
  }
  return points;
}

/// One column per symbol. The average paid is the total spent divided by the
/// shares bought. Personal counts one share per buy. Expert uses the stored
/// share count. A buy with no close on that day is left out.
RangeReport rangeReport(
  List<DayBuy> buys,
  Map<String, List<DailyBar>> prices,
  DateTime today, {
  bool expert = false,
}) {
  final bySymbol = <String, List<DayBuy>>{};
  for (final buy in buys) {
    bySymbol.putIfAbsent(buy.series.symbol, () => []).add(buy);
  }
  final symbols = bySymbol.keys.toList()..sort();
  final end = dateOnly(today);
  final points = <RangePoint>[];
  final unpriced = <String>[];
  var skipped = 0;
  for (final symbol in symbols) {
    final bars = prices[symbol] ?? const <DailyBar>[];
    final current = _priceFor(bars, end);
    final symbolBuys = bySymbol[symbol]!
      ..sort((a, b) => dateOnly(a.date).compareTo(dateOnly(b.date)));
    var invested = 0.0;
    var shares = 0;
    var missed = 0;
    for (final buy in symbolBuys) {
      final price = exactDayPrice(bars, buy.date);
      if (price == null) {
        missed++;
        continue;
      }
      final count = _sharesBought(buy, expert: expert);
      invested += price * count;
      shares += count;
    }
    if (current == null || shares == 0) {
      unpriced.add(symbol);
      continue;
    }
    skipped += missed;
    points.add(
      RangePoint(
        symbol: symbol,
        averagePurchase: invested / shares,
        current: current,
        buyDaysPriced: symbolBuys.length - missed,
        buyDaysTotal: symbolBuys.length,
      ),
    );
  }
  return RangeReport(
    points: points,
    unpricedSymbols: unpriced,
    skippedBuyDays: skipped,
  );
}

/// A day with no price on that date is left out of both totals.
///
/// [current] uses the latest close on or before [today], once per share.
/// Personal counts one share per priced buy. Expert uses the stored count.
PortfolioGain portfolioGain(
  List<DayBuy> buys,
  Map<String, List<DailyBar>> prices,
  DateTime today, {
  bool expert = false,
}) {
  final bySymbol = <String, List<DayBuy>>{};
  for (final buy in buys) {
    bySymbol.putIfAbsent(buy.series.symbol, () => []).add(buy);
  }
  final end = dateOnly(today);
  final symbols = bySymbol.keys.toList()..sort();
  var invested = 0.0;
  var current = 0.0;
  var pricedBuys = 0;
  final unpriced = <String>[];
  var skipped = 0;
  for (final symbol in symbols) {
    final bars = prices[symbol] ?? const <DailyBar>[];
    final latest = _priceFor(bars, end);
    var symbolInvested = 0.0;
    var symbolShares = 0;
    var symbolBuys = 0;
    var missed = 0;
    for (final buy in bySymbol[symbol]!) {
      final price = exactDayPrice(bars, buy.date);
      if (price == null) {
        missed++;
        continue;
      }
      final shares = _sharesBought(buy, expert: expert);
      symbolInvested += price * shares;
      symbolShares += shares;
      symbolBuys++;
    }
    if (latest == null || symbolBuys == 0) {
      unpriced.add(symbol);
      continue;
    }
    skipped += missed;
    invested += symbolInvested;
    current += latest * symbolShares;
    pricedBuys += symbolBuys;
  }
  return PortfolioGain(
    invested: invested,
    current: current,
    pricedBuys: pricedBuys,
    unpricedSymbols: unpriced,
    skippedBuyDays: skipped,
  );
}

/// The dropdown amount that produced every priced buy, when only one fits.
///
/// A buy with no close on its own day is left out of the check. Returns null
/// when no priced buy is available or more than one amount still fits.
int? inferDropdownAmount(
  List<DayBuy> buys,
  Map<String, List<DailyBar>> prices,
) {
  final possible = expertAmountChoices.toSet();
  var priced = 0;
  for (final buy in buys) {
    final price = exactDayPrice(prices[buy.series.symbol], buy.date);
    if (price == null) continue;
    priced++;
    final shares = buy.series.numberOfShares;
    possible.removeWhere(
      (amount) => !_matchesDropdownAmount(amount, price, shares),
    );
  }
  if (priced == 0 || possible.length != 1) return null;
  return possible.single;
}

/// Open market days from [start] through [today], weekends and holidays omitted.
///
/// Each plotted day adds [amount] once, so the invested line is straight.
/// A day is a holiday when no tracked symbol has a close or an open. A day is
/// also left out, and does not add [amount], when a stock already held has
/// neither that day. A missing close uses that day's open. Weekends stay off
/// the chart, so the previous session's close remains the last point. Shares
/// held include a buy on the day being priced.
List<WorthPoint> portfolioWorthSeries({
  required List<DayBuy> buys,
  required Map<String, List<DailyBar>> prices,
  required DateTime today,
  required int amount,
  required DateTime start,
}) {
  if (buys.isEmpty || amount < 1) return const [];
  final begin = dateOnly(start);
  final end = dateOnly(today);
  if (begin.isAfter(end)) return const [];

  final byDate = <DateTime, List<DayBuy>>{};
  for (final buy in buys) {
    byDate.putIfAbsent(dateOnly(buy.date), () => []).add(buy);
  }
  final marks = <String, Map<DateTime, double>>{};
  for (final entry in prices.entries) {
    final days = <DateTime, double>{};
    for (final bar in entry.value) {
      final price = worthMark(bar);
      if (price == null) continue;
      days[dateOnly(bar.date)] = price;
    }
    marks[entry.key] = days;
  }
  final symbols = symbolsOf(buys);
  final held = <String, int>{};
  var invested = 0.0;
  final points = <WorthPoint>[];
  for (var date = begin; !date.isAfter(end); date = addDays(date, 1)) {
    if (isWeekend(date)) continue;
    for (final buy in byDate[date] ?? const <DayBuy>[]) {
      final symbol = buy.series.symbol;
      held[symbol] = (held[symbol] ?? 0) + buy.series.numberOfShares;
    }
    if (!_marketOpen(symbols, marks, date)) continue;
    if (held.isEmpty) {
      invested += amount;
      points.add(WorthPoint(date: date, invested: invested, worth: 0));
      continue;
    }
    var worth = 0.0;
    var missing = false;
    for (final entry in held.entries) {
      final price = marks[entry.key]?[date];
      if (price == null) {
        missing = true;
        break;
      }
      worth += price * entry.value;
    }
    if (missing) continue;
    invested += amount;
    points.add(WorthPoint(date: date, invested: invested, worth: worth));
  }
  return points;
}

/// Personal portfolio worth from the first buy through [today].
///
/// Each buy counts as one share. Invested increases by that day's close, and
/// a plotted day with no buy keeps the previous total. Worth is the shares
/// held times that day's close, or the open when the session has not closed.
/// Weekends stay off the chart. A day is left out when a stock already held
/// has no price. A buy with no close on its own day is left out of both lines.
List<WorthPoint> personalWorthSeries({
  required List<DayBuy> buys,
  required Map<String, List<DailyBar>> prices,
  required DateTime today,
}) {
  if (buys.isEmpty) return const [];
  var begin = dateOnly(buys.first.date);
  for (final buy in buys) {
    final date = dateOnly(buy.date);
    if (date.isBefore(begin)) begin = date;
  }
  final end = dateOnly(today);
  if (begin.isAfter(end)) return const [];

  final byDate = <DateTime, List<DayBuy>>{};
  for (final buy in buys) {
    byDate.putIfAbsent(dateOnly(buy.date), () => []).add(buy);
  }
  final marks = <String, Map<DateTime, double>>{};
  for (final entry in prices.entries) {
    final days = <DateTime, double>{};
    for (final bar in entry.value) {
      final price = worthMark(bar);
      if (price == null) continue;
      days[dateOnly(bar.date)] = price;
    }
    marks[entry.key] = days;
  }
  final symbols = symbolsOf(buys);
  final held = <String, int>{};
  var invested = 0.0;
  final points = <WorthPoint>[];
  for (var date = begin; !date.isAfter(end); date = addDays(date, 1)) {
    for (final buy in byDate[date] ?? const <DayBuy>[]) {
      final cost = exactDayPrice(prices[buy.series.symbol], date);
      if (cost == null) continue;
      final symbol = buy.series.symbol;
      held[symbol] = (held[symbol] ?? 0) + 1;
      invested += cost;
    }
    if (isWeekend(date)) continue;
    if (!_marketOpen(symbols, marks, date)) continue;
    if (held.isEmpty) continue;
    var worth = 0.0;
    var missing = false;
    for (final entry in held.entries) {
      final price = marks[entry.key]?[date];
      if (price == null) {
        missing = true;
        break;
      }
      worth += price * entry.value;
    }
    if (missing) continue;
    points.add(WorthPoint(date: date, invested: invested, worth: worth));
  }
  return points;
}

/// Gain or loss on the last plotted day of a portfolio-worth series.
///
/// Invested is that day's cumulative amount. Current is that day's portfolio
/// worth, so the difference is the gap between the two lines.
PortfolioGain gainOnLastWorth(WorthPoint last) {
  return PortfolioGain(
    invested: last.invested,
    current: last.worth,
    pricedBuys: 1,
    unpricedSymbols: const [],
    skippedBuyDays: 0,
  );
}

bool _marketOpen(
  List<String> symbols,
  Map<String, Map<DateTime, double>> marks,
  DateTime date,
) {
  for (final symbol in symbols) {
    if (marks[symbol]?.containsKey(date) ?? false) return true;
  }
  return false;
}

/// Same share count [sharesForAmount] would buy at [price].
bool _matchesDropdownAmount(int amount, double price, int shares) {
  if (amount < 1 || price <= 0 || shares < 1 || price > amount) return false;
  return (amount / price).floor() == shares;
}

/// Price on [day] itself. A bar from another date is not used.
double? exactDayPrice(List<DailyBar>? bars, DateTime day) {
  if (bars == null || bars.isEmpty) return null;
  final target = dateOnly(day);
  for (final bar in bars) {
    if (dateOnly(bar.date) != target) continue;
    final price = quotedPrice(bar);
    if (price != null) return price;
  }
  return null;
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

double? _priceFor(List<DailyBar>? bars, DateTime day) {
  if (bars == null || bars.isEmpty) return null;
  final bar = priceOnOrBefore(bars, day);
  if (bar == null) return null;
  return quotedPrice(bar);
}

List<DailyBar> _sorted(List<DailyBar> bars) {
  final copy = [...bars]
    ..sort((a, b) => dateOnly(a.date).compareTo(dateOnly(b.date)));
  return copy;
}

class _Bucket {
  _Bucket(this.start);

  DateTime start;
  double total = 0;
}
