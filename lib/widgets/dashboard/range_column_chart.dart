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
    const chartHeight = 240.0;
    const bottomReserved = 44.0;
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
          height: chartHeight,
          bottomReserved: bottomReserved,
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
                  bottomReserved: bottomReserved,
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
                        _rod(
                          points[i],
                          barWidth,
                          brightness,
                          scheme,
                          maxY,
                          chartHeight - bottomReserved,
                        ),
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
  double maxY,
  double plotHeight,
) {
  final color = point.flat
      ? Colors.transparent
      : point.above
          ? gainColor(brightness)
          : lossColor(brightness);
  final label = _rangeLabel(point);
  final style = TextStyle(
    fontSize: 10,
    color: scheme.onSurface,
    fontWeight: FontWeight.w600,
    height: 1,
  );
  final text = _textSize(label, style);
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
      angle: -90,
      offset: _labelOffset(
        barWidth: point.flat ? 0 : barWidth,
        textWidth: text.width,
        textHeight: text.height,
        upper: point.upper,
        lower: point.flat ? point.current : point.lower,
        maxY: maxY,
        plotHeight: plotHeight,
      ),
      style: style,
    ),
  );
}

/// Low price, then high price. A flat column shows the single price.
String _rangeLabel(RangePoint point) {
  if (point.flat) return shortRupee(point.current);
  return '${shortRupee(point.lower)} - ${shortRupee(point.upper)}';
}

Size _textSize(String text, TextStyle style) {
  final painter = TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: TextDirection.ltr,
    maxLines: 1,
  )..layout();
  final size = painter.size;
  painter.dispose();
  return size;
}

/// Places the rotated label beside the column, reading upward from low to high.
Offset _labelOffset({
  required double barWidth,
  required double textWidth,
  required double textHeight,
  required double upper,
  required double lower,
  required double maxY,
  required double plotHeight,
}) {
  final span = maxY == 0 ? 0.0 : (upper - lower) / maxY * plotHeight;
  final tipFromTop = maxY == 0 ? plotHeight : (1 - upper / maxY) * plotHeight;
  var centerFromTip = span / 2;
  final halfLabel = textWidth / 2;
  final topIfCentered = tipFromTop + centerFromTip - halfLabel;
  if (topIfCentered < 2) centerFromTip += 2 - topIfCentered;
  final bottomIfCentered = tipFromTop + centerFromTip + halfLabel;
  final floor = plotHeight - 2;
  if (bottomIfCentered > floor) centerFromTip -= bottomIfCentered - floor;
  return Offset(
    barWidth / 2 + 4 + textHeight / 2,
    -(centerFromTip + textHeight / 2),
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
