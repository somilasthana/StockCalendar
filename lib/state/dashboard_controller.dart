import 'package:flutter/foundation.dart';

import '../logic/dashboard_metrics.dart';
import '../logic/dates.dart';
import '../logic/recurrence.dart';
import '../models/buy_series.dart';
import '../models/daily_bar.dart';
import '../services/yahoo_price_service.dart';

class DashboardController extends ChangeNotifier {
  DashboardController({
    required YahooPriceService priceService,
    DateTime Function()? clock,
  }) : _prices = priceService,
       _clock = clock ?? DateTime.now;

  final YahooPriceService _prices;
  final DateTime Function() _clock;

  List<DayBuy> buys = [];
  Map<String, List<DailyBar>> prices = {};
  DateTime today = dateOnly(DateTime.now());
  HistogramSpan span = HistogramSpan.weekly;
  String? selectedSymbol;
  bool started = false;
  bool loading = false;
  int loaded = 0;
  int totalSymbols = 0;
  String? loadingSymbol;
  String? loadError;

  int _generation = 0;
  String? _signature;
  bool _disposed = false;

  List<SymbolCount> get counts => occurrenceCounts(buys);

  List<String> get symbols => symbolsOf(buys);

  EventDayReport get events => eventDayTotals(buys, prices);

  List<HistogramBar> get histogram => histogramBars(events.days, span);

  RangeReport get ranges => rangeReport(buys, prices, today);

  List<LinePoint> lineFor(String? symbol) {
    if (symbol == null) return const [];
    final first = firstBuyOf(buys, symbol);
    if (first == null) return const [];
    final dates = [
      for (final buy in buys)
        if (buy.series.symbol == symbol) buy.date,
    ];
    return pricePath(
      bars: prices[symbol] ?? const [],
      buyDates: dates,
      firstBuy: first,
      today: today,
    );
  }

  String nameOf(String symbol) {
    for (final row in counts) {
      if (row.symbol == symbol) return row.name;
    }
    return symbol;
  }

  void setSpan(HistogramSpan next) {
    if (span == next) return;
    span = next;
    _notify();
  }

  void selectSymbol(String symbol) {
    if (selectedSymbol == symbol) return;
    selectedSymbol = symbol;
    _notify();
  }

  Future<void> sync(List<BuySeries> series, {bool refresh = false}) async {
    final signature = _seriesSignature(series);
    if (!refresh && signature == _signature) return;
    final generation = ++_generation;
    _signature = signature;
    today = dateOnly(_clock());
    buys = buysBetween(series, DateTime(1970, 1, 1), today);
    final symbols = symbolsOf(buys);
    _ensureSelection(symbols);
    loadError = null;
    if (symbols.isEmpty) {
      prices = {};
      loading = false;
      loaded = 0;
      totalSymbols = 0;
      loadingSymbol = null;
      started = true;
      _notify();
      return;
    }

    loading = true;
    loaded = 0;
    totalSymbols = symbols.length;
    started = true;
    if (refresh) prices = {};
    _notify();

    final earliest = buys
        .map((buy) => dateOnly(buy.date))
        .reduce((a, b) => a.isBefore(b) ? a : b);
    final from = addDays(earliest, -7);
    final to = addDays(today, 1);
    final next = refresh
        ? <String, List<DailyBar>>{}
        : Map<String, List<DailyBar>>.from(prices);
    var cursor = 0;

    Future<void> worker() async {
      while (generation == _generation) {
        if (cursor >= symbols.length) return;
        final symbol = symbols[cursor++];
        loadingSymbol = symbol;
        _notify();
        try {
          final bars = await _prices.load(
            symbol,
            from: from,
            to: to,
            refresh: refresh,
          );
          if (generation != _generation) return;
          next[symbol] = bars;
        } on PriceLookupException catch (error) {
          if (generation != _generation) return;
          loadError ??= error.message;
          next[symbol] = const [];
        } catch (_) {
          if (generation != _generation) return;
          loadError ??= 'Prices could not be loaded. Pull down to try again.';
          next[symbol] = const [];
        }
        loaded += 1;
        prices = Map<String, List<DailyBar>>.from(next);
        _notify();
      }
    }

    final pool = symbols.length < 4 ? symbols.length : 4;
    await Future.wait([for (var i = 0; i < pool; i++) worker()]);
    if (generation != _generation) return;
    loading = false;
    loadingSymbol = null;
    prices = next;
    started = true;
    _notify();
  }

  void _ensureSelection(List<String> symbols) {
    if (symbols.isEmpty) {
      selectedSymbol = null;
      return;
    }
    if (selectedSymbol == null || !symbols.contains(selectedSymbol)) {
      selectedSymbol = symbols.first;
    }
  }

  String _seriesSignature(List<BuySeries> series) {
    final parts = [
      for (final item in series) '${item.id}:${_seriesJson(item)}',
    ]..sort();
    return parts.join('|');
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    super.dispose();
  }
}

String _seriesJson(BuySeries series) {
  final json = series.toJson();
  final keys = json.keys.toList()..sort();
  return [for (final key in keys) '$key=${json[key]}'].join(',');
}
