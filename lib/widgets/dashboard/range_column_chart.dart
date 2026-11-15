import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../logic/dashboard_format.dart';
import '../../logic/dashboard_metrics.dart';
import 'dashboard_style.dart';
import 'scrolling_plot.dart';

class RangeColumnChart extends StatelessWidget {
  const RangeColumnChart({super.key, required this.points});

  final List<RangePoint> points;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final brightness = Theme.of(context).brightness;
    if (points.isEmpty) {
      return const SizedBox(
        height: 120,
        child: Center(child: Text('No priced symbols yet.')),
      );
    }
    final peak = points
        .map((point) => point.upper)
        .reduce((a, b) => a > b ? a : b);
    final maxY = niceMax(peak);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ScrollingPlot(
          scrollKey: 'range-${points.length}-${points.first.symbol}',
          itemCount: points.length,
          visibleCount: 5,
          alignEnd: false,
          minY: 0,
          maxY: maxY,
          bottomReserved: 32,
          formatTick: (value) => axisPrice(value, maxY),
          hint: 'Swipe sideways for more symbols.',
          builder: (width, slot) {
            final barWidth = (slot * 0.42).clamp(8.0, 28.0);
            return BarChart(
              BarChartData(
                minY: 0,
                maxY: maxY,
                alignment: BarChartAlignment.spaceAround,
                groupsSpace: 8,
                gridData: chartGrid(scheme, maxY / 4),
                borderData: FlBorderData(show: false),
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    fitInsideHorizontally: true,
                    fitInsideVertically: true,
                    maxContentWidth: 180,
                    getTooltipColor: (_) => scheme.inverseSurface,
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      return BarTooltipItem(
                        _tip(points[group.x]),
                        TextStyle(color: scheme.onInverseSurface, height: 1.3),
                      );
                    },
                  ),
                ),
                titlesData: chartTitles(
                  bottomReserved: 32,
                  bottom: (value, meta) {
                    final index = value.toInt();
                    if (index < 0 || index >= points.length) {
                      return const SizedBox.shrink();
                    }
                    return SideTitleWidget(
                      meta: meta,
                      space: 6,
                      child: SizedBox(
                        width: slot * 0.95,
                        child: Text(
                          points[index].symbol,
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 10,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    );
                  },
                ),
                barGroups: [
                  for (var i = 0; i < points.length; i++)
                    BarChartGroupData(
                      x: i,
                      barRods: [
                        _rod(points[i], barWidth, brightness, scheme),
                      ],
                    ),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 14,
          runSpacing: 6,
          children: [
            _Swatch(color: gainColor(brightness), label: 'Latest above average buy'),
            _Swatch(color: lossColor(brightness), label: 'Latest below average buy'),
            Text(
              'No column means they match',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

BarChartRodData _rod(
  RangePoint point,
  double barWidth,
  Brightness brightness,
  ColorScheme scheme,
) {
  final color = point.flat
      ? Colors.transparent
      : point.above
          ? gainColor(brightness)
          : lossColor(brightness);
  final label = point.flat
      ? 'even'
      : '${shortRupee(point.averagePurchase)}→${shortRupee(point.current)}';
  return BarChartRodData(
    fromY: point.flat ? point.current : point.lower,
    toY: point.flat ? point.current : point.upper,
    width: point.flat ? 0 : barWidth,
    color: color,
    borderSide: BorderSide.none,
    borderRadius: BorderRadius.circular(4),
    label: BarChartRodLabel(
      show: true,
      text: label,
      style: TextStyle(
        fontSize: 10,
        color: scheme.onSurface,
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}

String _tip(RangePoint point) {
  final gap = signedPercent(point.percentGap);
  final days = point.buyDaysPriced == point.buyDaysTotal
      ? '${point.buyDaysTotal} buy days'
      : '${point.buyDaysPriced} of ${point.buyDaysTotal} buy days';
  final direction = point.flat
      ? 'Latest matches the average buy'
      : point.above
          ? 'Latest is above the average buy'
          : 'Latest is below the average buy';
  final lines = [
    point.symbol,
    'Average buy ${fullRupee(point.averagePurchase)}',
    'Latest ${fullRupee(point.current)}',
    if (gap.isNotEmpty) gap,
    days,
    direction,
  ];
  return lines.join('\n');
}

class _Swatch extends StatelessWidget {
  const _Swatch({required this.color, required this.label});

  final Color color;
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
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 6),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}
