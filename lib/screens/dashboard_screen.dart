import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/buy_series.dart';
import '../services/yahoo_price_service.dart';
import '../state/calendar_controller.dart';
import '../state/dashboard_controller.dart';
import '../widgets/dashboard/dashboard_style.dart';
import '../widgets/dashboard/frequency_donut.dart';
import '../widgets/dashboard/price_histogram.dart';
import '../widgets/dashboard/price_line_chart.dart';
import '../widgets/dashboard/range_column_chart.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

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
    _dashboard = DashboardController(priceService: _prices)
      ..addListener(_rebuild);
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
    _dashboard.sync(calendar.series);
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
      appBar: AppBar(title: const Text('Buy performance')),
      body: !_dashboard.started
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () => _dashboard.sync(
                _calendar?.series ?? const <BuySeries>[],
                refresh: true,
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
                        if (_dashboard.loading) _Progress(dashboard: _dashboard),
                        for (final line in _notices(_dashboard))
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Text(
                              line,
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                                height: 1.35,
                              ),
                            ),
                          ),
                        DashboardCard(
                          title: 'How often you buy',
                          caption:
                              'Each slice is a symbol. Tap a slice for the stock, count, and share.',
                          borderColor: howOftenBorder,
                          child: FrequencyDonut(counts: _dashboard.counts),
                        ),
                        DashboardCard(
                          title: 'Price on buy days',
                          caption:
                              'Each bar adds the daily price of every symbol you bought, once per symbol per day.',
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
                          title: 'Price path',
                          caption:
                              'Daily price from the first buy through the latest trading day, including days with no buy.',
                          borderColor: pricePathBorder,
                          child: _pricedChild(
                            _dashboard,
                            PriceLineChart(
                              symbols: _dashboard.symbols,
                              selected: _dashboard.selectedSymbol,
                              symbolName: _dashboard.selectedSymbol == null
                                  ? ''
                                  : _dashboard.nameOf(_dashboard.selectedSymbol!),
                              points: _dashboard.lineFor(_dashboard.selectedSymbol),
                              onSelected: _dashboard.selectSymbol,
                            ),
                          ),
                        ),
                        DashboardCard(
                          title: 'Against your average buy',
                          caption:
                              'The column runs from the average price on your buy days to the latest price.',
                          borderColor: againstAverageBorder,
                          child: _pricedChild(
                            _dashboard,
                            RangeColumnChart(points: _dashboard.ranges.points),
                          ),
                        ),
                      ],
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

Widget _pricedChild(DashboardController dashboard, Widget child) {
  final waiting = dashboard.loading &&
      dashboard.prices.values.every((bars) => bars.isEmpty);
  if (waiting) return const ChartWaiting();
  return child;
}

List<String> _notices(DashboardController dashboard) {
  final lines = <String>[];
  final priced = dashboard.prices.values.any((bars) => bars.isNotEmpty);
  if (dashboard.started && !dashboard.loading && !priced && dashboard.loadError != null) {
    lines.add(dashboard.loadError!);
  }
  final missing = dashboard.ranges.unpricedSymbols;
  if (missing.isNotEmpty && priced) {
    lines.add('No price for ${missing.join(', ')}.');
  }
  if (!priced && missing.isNotEmpty && dashboard.loadError == null && !dashboard.loading) {
    lines.add('No price for ${missing.join(', ')}.');
  }
  final skipped = dashboard.ranges.skippedBuyDays;
  if (skipped > 0) {
    lines.add(
      skipped == 1
          ? '1 buy day had no price within 5 days, so it was left out.'
          : '$skipped buy days had no price within 5 days, so they were left out.',
    );
  }
  return lines;
}
