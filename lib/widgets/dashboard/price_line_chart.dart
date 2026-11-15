import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../logic/dashboard_format.dart';
import '../../logic/dashboard_metrics.dart';
import '../../logic/dates.dart';
import 'dashboard_style.dart';
import 'scrolling_plot.dart';

class PriceLineChart extends StatelessWidget {
  const PriceLineChart({
    super.key,
    required this.symbols,
    required this.selected,
    required this.symbolName,
    required this.points,
    required this.onSelected,
  });

  final List<String> symbols;
  final String? selected;
  final String symbolName;
  final List<LinePoint> points;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final lineColor = scheme.primary;
    final cardColor = chartSurface(Theme.of(context).brightness, scheme);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButton<String>(
          value: selected,
          items: [
            for (final symbol in symbols)
              DropdownMenuItem(value: symbol, child: Text(symbol)),
          ],
          onChanged: (value) {
            if (value != null) onSelected(value);
          },
        ),
        if (symbolName.isNotEmpty && symbolName != selected)
          Text(
            symbolName,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        const SizedBox(height: 8),
        if (points.isEmpty)
          const SizedBox(
            height: 120,
            child: Center(child: Text('No prices for this symbol.')),
          )
        else
          _LinePlot(
            symbol: selected ?? '',
            points: points,
            lineColor: lineColor,
            cardColor: cardColor,
            scheme: scheme,
          ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 16,
          runSpacing: 6,
          children: [
            _BubbleLegend(
              solid: true,
              color: lineColor,
              fill: cardColor,
              label: 'Solid — planned buy',
            ),
            _BubbleLegend(
              solid: false,
              color: lineColor,
              fill: cardColor,
              label: 'Hollow — no buy that day',
            ),
          ],
        ),
      ],
    );
  }
}

class _LinePlot extends StatelessWidget {
  const _LinePlot({
    required this.symbol,
    required this.points,
    required this.lineColor,
    required this.cardColor,
    required this.scheme,
  });

  final List<LinePoint> points;
  final Color lineColor;
  final Color cardColor;
  final ColorScheme scheme;
  final String symbol;

  @override
  Widget build(BuildContext context) {
    final prices = points.map((point) => point.price);
    final low = prices.reduce((a, b) => a < b ? a : b);
    final high = prices.reduce((a, b) => a > b ? a : b);
    final pad = high == low ? 1.0 : (high - low) * 0.16;
    var minY = low - pad;
    final maxY = high + pad;
    if (low >= 0 && minY < 0) minY = 0;
    final span = maxY - minY;
    final withYear = points.first.date.year != points.last.date.year;
    final last = points.length - 1;
    return ScrollingPlot(
      scrollKey: '$symbol-${points.length}-${points.last.date.toIso8601String()}',
      itemCount: points.length,
      visibleCount: 22,
      alignEnd: true,
      minY: minY,
      maxY: maxY,
      bottomReserved: 32,
      formatTick: (value) => axisPrice(value, span),
      hint: 'Swipe sideways for earlier days.',
      builder: (width, slot) {
        return LineChart(
          LineChartData(
            minX: points.length == 1 ? -1 : 0,
            maxX: points.length == 1 ? 1 : last.toDouble(),
            minY: minY,
            maxY: maxY,
            gridData: chartGrid(scheme, span / 4),
            borderData: FlBorderData(show: false),
            lineTouchData: LineTouchData(
              touchTooltipData: LineTouchTooltipData(
                fitInsideHorizontally: true,
                fitInsideVertically: true,
                maxContentWidth: 160,
                getTooltipColor: (_) => scheme.inverseSurface,
                getTooltipItems: (spots) {
                  return [
                    for (final spot in spots)
                      spot.x.toInt() < 0 || spot.x.toInt() >= points.length
                          ? null
                          : LineTooltipItem(
                              _tip(points[spot.x.toInt()], withYear: withYear),
                              TextStyle(
                                color: scheme.onInverseSurface,
                                height: 1.3,
                              ),
                            ),
                  ];
                },
              ),
            ),
            titlesData: chartTitles(
              bottomReserved: 32,
              bottom: (value, meta) {
                final index = value.toInt();
                if (index < 0 || index >= points.length || !_showDate(index, last)) {
                  return const SizedBox.shrink();
                }
                return SideTitleWidget(
                  meta: meta,
                  space: 4,
                  child: Text(
                    _dateLabel(points[index].date, withYear: withYear),
                    style: TextStyle(fontSize: 10, color: scheme.onSurfaceVariant),
                  ),
                );
              },
            ),
            lineBarsData: [
              LineChartBarData(
                spots: [
                  for (var i = 0; i < points.length; i++)
                    FlSpot(i.toDouble(), points[i].price),
                ],
                isCurved: false,
                color: lineColor,
                barWidth: 2.5,
                isStrokeCapRound: true,
                isStrokeJoinRound: true,
                belowBarData: BarAreaData(
                  show: true,
                  color: lineColor.withValues(alpha: 0.12),
                ),
                dotData: FlDotData(
                  show: true,
                  getDotPainter: (spot, percent, bar, index) {
                    final planned = index >= 0 &&
                        index < points.length &&
                        points[index].plannedBuy;
                    return FlDotCirclePainter(
                      radius: planned ? 4.5 : 3.5,
                      color: planned ? lineColor : cardColor,
                      strokeWidth: planned ? 0 : 2,
                      strokeColor: lineColor,
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  bool _showDate(int index, int last) {
    if (points.length <= 8) return true;
    if (index % 5 == 0) return true;
    return index == last && last % 5 > 2;
  }
}

String _dateLabel(DateTime date, {required bool withYear}) {
  final day = dateOnly(date);
  final text = '${day.day} ${monthShort[day.month - 1]}';
  return withYear ? '$text ${day.year}' : text;
}

String _tip(LinePoint point, {required bool withYear}) {
  final kind = point.plannedBuy ? 'Planned buy' : 'No buy that day';
  return '${_dateLabel(point.date, withYear: withYear)}\n${fullRupee(point.price)}\n$kind';
}

class _BubbleLegend extends StatelessWidget {
  const _BubbleLegend({
    required this.solid,
    required this.color,
    required this.fill,
    required this.label,
  });

  final bool solid;
  final Color color;
  final Color fill;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: solid ? color : fill,
            border: Border.all(color: color, width: 2),
          ),
        ),
        const SizedBox(width: 6),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}
