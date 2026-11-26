import 'package:flutter/foundation.dart';

import '../logic/dashboard_metrics.dart';
import '../logic/dates.dart';
import '../logic/recurrence.dart';
import '../models/buy_series.dart';
import '../models/daily_bar.dart';
import '../models/expert_run.dart';
import '../services/yahoo_price_service.dart';

class DashboardController extends ChangeNotifier {
  DashboardController({
    required YahooPriceService priceService,
    DateTime Function()? clock,
    this.expert = false,
  }) : _prices = priceService,
       _clock = clock ?? DateTime.now;

  final YahooPriceService _prices;
  final DateTime Function() _clock;
  final bool expert;

  List<DayBuy> buys = [];
  Map<String, List<DailyBar>> prices = {};
  ExpertRun? run;
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

  /// Each row is one symbol at the latest close. Personal counts one share.
  List<SymbolInvestment> get holdings =>
      holdingValueBySymbol(buys, prices, today, expert: expert);

  List<String> get symbols => symbolsOf(buys);

  /// Expert insight names the scrip chosen on Expert Opinion.
  String get scripName => run?.scripName ?? defaultExpertScripName;

  /// Personal worth is shown for any buy. Expert worth is the fixed-amount
  /// strategy. An older simulation that did not save a plan is treated as
  /// that strategy.
  bool get showsWorth {
    if (!expert) return buys.isNotEmpty;
    final saved = run;
    if (saved == null) return buys.isNotEmpty;
    return saved.strategy == fixedStockInvestedAmount;
  }

  int? get investedAmount => _worthPlan()?.amount;

  List<WorthPoint> get worth {
    if (!expert) {
      return personalWorthSeries(buys: buys, prices: prices, today: today);
    }
    final plan = _worthPlan();
    if (plan == null) return const [];
    return portfolioWorthSeries(
      buys: buys,
      prices: prices,
      today: today,
      amount: plan.amount,
      start: plan.published,
    );
  }

  ExpertRun? _worthPlan() {
    if (!expert || !showsWorth) return null;
    final saved = run;
    if (saved != null &&
        saved.strategy == fixedStockInvestedAmount &&
        saved.amount >= 1) {
      return saved;
    }
    final amount = inferDropdownAmount(buys, prices);
    if (amount == null || buys.isEmpty) return null;
    var first = dateOnly(buys.first.date);
    for (final buy in buys) {
      final date = dateOnly(buy.date);
      if (date.isBefore(first)) first = date;
    }
    return ExpertRun(
      scripName: defaultExpertScripName,
      strategy: fixedStockInvestedAmount,
      amount: amount,
      published: first,
    );
  }

  EventDayReport get events => eventDayTotals(buys, prices, expert: expert);

  List<HistogramBar> get histogram => histogramBars(events.days, span);

  RangeReport get ranges => rangeReport(buys, prices, today, expert: expert);

  /// Headline gain. This is the last plotted day's portfolio worth minus the
  /// cumulative amount invested.
  PortfolioGain? get gain {
    if (showsWorth) {
      final points = worth;
      if (points.isEmpty) return null;
      return gainOnLastWorth(points.last);
    }
    if (!expert) return null;
    final computed = portfolioGain(buys, prices, today, expert: true);
    if (computed.pricedBuys == 0) return null;
    return computed;
  }

  int get portfolioCount => uniqueBoughtStocks(buys);

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

  Future<void> sync(
    List<BuySeries> series, {
    bool refresh = false,
    ExpertRun? run,
  }) async {
    final nextRun = expert ? run : null;
    final signature = '${_seriesSignature(series)}|${nextRun?.signature ?? ''}';
    if (!refresh && signature == _signature) return;
    final generation = ++_generation;
    _signature = signature;
    this.run = nextRun;
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

    var earliest = buys
        .map((buy) => dateOnly(buy.date))
        .reduce((a, b) => a.isBefore(b) ? a : b);
    final published = nextRun?.published;
    if (published != null && published.isBefore(earliest)) {
      earliest = published;
    }
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
    final parts = [for (final item in series) '${item.id}:${_seriesJson(item)}']
      ..sort();
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
