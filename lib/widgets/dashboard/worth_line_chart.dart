import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../logic/dashboard_format.dart';
import '../../logic/dashboard_metrics.dart';
import '../../logic/dates.dart';
import 'scrolling_plot.dart';

const investedLineColor = Color(0xFF3D7DFF);
const worthLineColor = Color(0xFFE09B1C);

class WorthLineChart extends StatelessWidget {
  const WorthLineChart({super.key, required this.points});

  final List<WorthPoint> points;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _WorthPlot(points: points, scheme: scheme),
        const SizedBox(height: 10),
        const Wrap(
          spacing: 16,
          runSpacing: 6,
          children: [
            _LineLegend(
              color: investedLineColor,
              label: 'Daily Cumulative Invested Amt',
            ),
            _LineLegend(
              color: worthLineColor,
              label: 'Daily Cumulative Portfolio Worth',
            ),
          ],
        ),
      ],
    );
  }
}

class _WorthPlot extends StatelessWidget {
  const _WorthPlot({required this.points, required this.scheme});

  final List<WorthPoint> points;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    final values = [
      for (final point in points) ...[point.invested, point.worth],
    ];
    final low = values.reduce((a, b) => a < b ? a : b);
    final high = values.reduce((a, b) => a > b ? a : b);
    final pad = high == low ? 1.0 : (high - low) * 0.16;
    var minY = low - pad;
    final maxY = high + pad;
    if (low >= 0 && minY < 0) minY = 0;
    final span = maxY - minY;
    final withYear = points.first.date.year != points.last.date.year;
    final last = points.length - 1;
    return ScrollingPlot(
      scrollKey:
          '${points.length}-${points.last.date.toIso8601String()}-${points.last.invested}',
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
                maxContentWidth: 240,
                getTooltipColor: (_) => scheme.inverseSurface,
                getTooltipItems: (spots) {
                  return [
                    for (var i = 0; i < spots.length; i++)
                      i != 0 ||
                              spots[i].x.toInt() < 0 ||
                              spots[i].x.toInt() >= points.length
                          ? null
                          : LineTooltipItem(
                              _tip(
                                points[spots[i].x.toInt()],
                                withYear: withYear,
                              ),
                              TextStyle(
                                color: scheme.onInverseSurface,
                                height: 1.3,
                                fontSize: 12,
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
              _line(points.map((point) => point.invested).toList(), investedLineColor),
              _line(points.map((point) => point.worth).toList(), worthLineColor),
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

LineChartBarData _line(List<double> values, Color color) {
  return LineChartBarData(
    spots: [
      for (var i = 0; i < values.length; i++) FlSpot(i.toDouble(), values[i]),
    ],
    isCurved: false,
    color: color,
    barWidth: 2.5,
    isStrokeCapRound: true,
    isStrokeJoinRound: true,
    dotData: FlDotData(
      show: true,
      getDotPainter: (spot, percent, bar, index) => FlDotCirclePainter(
        radius: 3,
        color: color,
        strokeWidth: 0,
      ),
    ),
  );
}

class _LineLegend extends StatelessWidget {
  const _LineLegend({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 16,
          height: 3,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 6),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

String _dateLabel(DateTime date, {required bool withYear}) {
  final day = dateOnly(date);
  final text = '${day.day} ${monthShort[day.month - 1]}';
  return withYear ? '$text ${day.year}' : text;
}

String _tip(WorthPoint point, {required bool withYear}) {
  return '${_dateLabel(point.date, withYear: withYear)}\n'
      'Daily Cumulative Invested Amt: ${fullRupee(point.invested)}\n'
      'Daily Cumulative Portfolio Worth: ${fullRupee(point.worth)}';
}
