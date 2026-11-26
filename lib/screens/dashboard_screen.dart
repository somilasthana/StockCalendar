import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../logic/dashboard_format.dart';
import '../logic/dashboard_metrics.dart';
import '../models/buy_series.dart';
import '../services/yahoo_price_service.dart';
import '../state/calendar_controller.dart';
import '../state/dashboard_controller.dart';
import '../widgets/dashboard/dashboard_style.dart';
import '../widgets/dashboard/frequency_donut.dart';
import '../widgets/dashboard/price_histogram.dart';
import '../widgets/dashboard/price_line_chart.dart';
import '../widgets/dashboard/range_column_chart.dart';
import '../widgets/dashboard/worth_line_chart.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key, this.expert = false});

  /// Expert Scrip uses the stored share count. Personal Stock Calendar counts
  /// one share per buy. Both price every chart from the closing price.
  final bool expert;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late final YahooPriceService _prices;
  late final DashboardController _dashboard;
  CalendarController? _calendar;

  @override
  void initState() {
    super.initState();
    _prices = YahooPriceService();
    _dashboard = DashboardController(
      priceService: _prices,
      expert: widget.expert,
    )..addListener(_rebuild);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _calendar = context.read<CalendarController>()..addListener(_onCalendar);
      _onCalendar();
    });
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  void _onCalendar() {
    final calendar = _calendar;
    if (calendar == null) return;
    _dashboard.sync(calendar.series, run: calendar.expertRun);
  }

  @override
  void dispose() {
    _calendar?.removeListener(_onCalendar);
    _dashboard.dispose();
    _prices.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: widget.expert ? 72 : null,
        title: widget.expert
            ? _ExpertTitle(name: _dashboard.scripName)
            : const Text('Stock Calendar Insights'),
      ),
      body: !_dashboard.started
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () => _dashboard.sync(
                _calendar?.series ?? const <BuySeries>[],
                refresh: true,
                run: _calendar?.expertRun,
              ),
              child: _dashboard.buys.isEmpty
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: const [
                        SizedBox(height: 160),
                        Center(child: Text('No buys through today.')),
                      ],
                    )
                  : ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                      children: [
                        if (_dashboard.loading)
                          _Progress(dashboard: _dashboard),
                        _PortfolioCount(count: _dashboard.portfolioCount),
                        if (_dashboard.gain != null)
                          _GainSummary(gain: _dashboard.gain!),
                        for (final line in _notices(_dashboard))
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Text(
                              line,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: scheme.onSurfaceVariant,
                                    height: 1.35,
                                  ),
                            ),
                          ),
                        DashboardCard(
                          title: 'Your Buying Pattern',
                          caption: 'Each slice is a symbol. Tap a slice for the stock, its current value, and its share of the portfolio.',
                          borderColor: howOftenBorder,
                          child: _holdingDonut(_dashboard),
                        ),
                        DashboardCard(
                          title: 'Amount Invested Distribution',
                          caption: widget.expert
                              ? 'Each bar adds the closing price times the shares bought, once per symbol per day.'
                              : 'Each bar adds the closing price of every symbol you bought, once per symbol per day.',
                          borderColor: priceOnBuyBorder,
                          child: _pricedChild(
                            _dashboard,
                            PriceHistogram(
                              bars: _dashboard.histogram,
                              span: _dashboard.span,
                              onSpan: _dashboard.setSpan,
                            ),
                          ),
                        ),
                        DashboardCard(
                          title: 'Price Movement',
                          caption: 'Closing price from the first buy through the latest trading day, including days with no buy.',
                          borderColor: pricePathBorder,
                          child: _pricedChild(
                            _dashboard,
                            PriceLineChart(
                              symbols: _dashboard.symbols,
                              selected: _dashboard.selectedSymbol,
                              symbolName: _dashboard.selectedSymbol == null
                                  ? ''
                                  : _dashboard.nameOf(
                                      _dashboard.selectedSymbol!,
                                    ),
                              points: _dashboard.lineFor(
                                _dashboard.selectedSymbol,
                              ),
                              onSelected: _dashboard.selectSymbol,
                            ),
                          ),
                        ),
                        DashboardCard(
                          title: 'Your Portfolio Gains/Losses',
                          caption: widget.expert
                              ? 'Each bar runs from the average price paid to the latest close. The average is the total spent divided by the shares bought.'
                              : 'Each bar runs from the average closing price paid to the latest close. Each buy counts as one share.',
                          borderColor: againstAverageBorder,
                          child: _pricedChild(
                            _dashboard,
                            RangeColumnChart(points: _dashboard.ranges.points),
                          ),
                        ),
                        if (_dashboard.showsWorth)
                          DashboardCard(
                            title: 'Your Portfolio Worth',
                            caption: widget.expert
                                ? 'Compare cumulative increase or decrease in portfolio worth'
                                : 'Invested adds the closing price of each buy and stays flat on other days. Worth is the shares held times that day\'s close.',
                            borderColor: portfolioWorthBorder,
                            child: _worthBody(_dashboard),
                          ),
                      ],
                    ),
            ),
    );
  }
}

class _ExpertTitle extends StatelessWidget {
  const _ExpertTitle({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Expert Scrip Portfolio Insight',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.titleMedium,
        ),
        Text(
          name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodyMedium,
        ),
      ],
    );
  }
}

class _PortfolioCount extends StatelessWidget {
  const _PortfolioCount({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final scheme = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      color: chartSurface(brightness, scheme),
      surfaceTintColor: Colors.transparent,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: howOftenBorder, width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Text.rich(
          TextSpan(
            style: Theme.of(context).textTheme.titleMedium,
            children: [
              const TextSpan(text: 'Total Number of Stocks in Portfolio: '),
              TextSpan(
                text: '$count',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Gain or loss on the last plotted day of Your Portfolio Worth.
class _GainSummary extends StatelessWidget {
  const _GainSummary({required this.gain});

  final PortfolioGain gain;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final scheme = Theme.of(context).colorScheme;
    final down = paise(gain.amount) < 0;
    final color = down ? lossColor(brightness) : gainColor(brightness);
    final percent = gain.percent;
    final value = percent == null
        ? fullRupee(gain.amount)
        : '${fullRupee(gain.amount)} (${percent.toStringAsFixed(1)}%)';
    return Card(
      elevation: 0,
      color: chartSurface(brightness, scheme),
      surfaceTintColor: Colors.transparent,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: color, width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Text.rich(
          TextSpan(
            style: Theme.of(context).textTheme.titleMedium,
            children: [
              const TextSpan(text: 'Gain/Losses: '),
              TextSpan(
                text: value,
                style: TextStyle(color: color, fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Progress extends StatelessWidget {
  const _Progress({required this.dashboard});

  final DashboardController dashboard;

  @override
  Widget build(BuildContext context) {
    final total = dashboard.totalSymbols;
    final symbol = dashboard.loadingSymbol;
    final label = symbol == null
        ? 'Loading prices'
        : 'Loading $symbol  ${dashboard.loaded} of $total';
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LinearProgressIndicator(
            value: total == 0 ? null : dashboard.loaded / total,
          ),
          const SizedBox(height: 6),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

Widget _worthBody(DashboardController dashboard) {
  if (dashboard.expert && dashboard.investedAmount == null) {
    if (dashboard.loading) return const ChartWaiting();
    return const SizedBox(
      height: 88,
      child: Center(
        child: Text(
          'Add this scrip to the calendar again so the invested amount can be plotted.',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
  if (dashboard.loading && dashboard.worth.isEmpty) return const ChartWaiting();
  if (dashboard.worth.isEmpty) {
    return const SizedBox(
      height: 120,
      child: Center(child: Text('No market days to plot.')),
    );
  }
  return WorthLineChart(points: dashboard.worth);
}

Widget _holdingDonut(DashboardController dashboard) {
  final rows = dashboard.holdings;
  if (rows.isEmpty) {
    if (dashboard.loading) return const ChartWaiting();
    return const SizedBox(
      height: 120,
      child: Center(child: Text('No current price for these stocks.')),
    );
  }
  return FrequencyDonut.amounts(amounts: rows);
}

Widget _pricedChild(DashboardController dashboard, Widget child) {
  final waiting =
      dashboard.loading &&
      dashboard.prices.values.every((bars) => bars.isEmpty);
  if (waiting) return const ChartWaiting();
  return child;
}

List<String> _notices(DashboardController dashboard) {
  final lines = <String>[];
  final priced = dashboard.prices.values.any((bars) => bars.isNotEmpty);
  if (dashboard.started &&
      !dashboard.loading &&
      !priced &&
      dashboard.loadError != null) {
    lines.add(dashboard.loadError!);
  }
  final missing = dashboard.ranges.unpricedSymbols;
  if (missing.isNotEmpty && priced) {
    lines.add('No price for ${missing.join(', ')}.');
  }
  if (!priced &&
      missing.isNotEmpty &&
      dashboard.loadError == null &&
      !dashboard.loading) {
    lines.add('No price for ${missing.join(', ')}.');
  }
  final skipped = dashboard.ranges.skippedBuyDays;
  if (skipped > 0) {
    const reason = 'no closing price';
    lines.add(
      skipped == 1
          ? '1 buy day had $reason, so it was left out.'
          : '$skipped buy days had $reason, so they were left out.',
    );
  }
  return lines;
}
