import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../logic/dashboard_format.dart';
import '../../logic/dashboard_metrics.dart';
import 'dashboard_style.dart';
import 'scrolling_plot.dart';

class PriceHistogram extends StatelessWidget {
  const PriceHistogram({
    super.key,
    required this.bars,
    required this.span,
    required this.onSpan,
  });

  final List<HistogramBar> bars;
  final HistogramSpan span;
  final ValueChanged<HistogramSpan> onSpan;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final brightness = Theme.of(context).brightness;
    const chartHeight = 240.0;
    const bottomReserved = 36.0;
    final labelStyle = TextStyle(
      fontSize: 10,
      height: 1,
      color: scheme.onSurface,
      fontWeight: FontWeight.w600,
    );
    final labels = [for (final bar in bars) shortRupee(bar.total)];
    var longest = 0.0;
    for (final label in labels) {
      final width = measureChartLabel(label, labelStyle).width;
      if (width > longest) longest = width;
    }
    final peak = bars.isEmpty
        ? 0.0
        : bars.map((bar) => bar.total).reduce((a, b) => a > b ? a : b);
    final maxY = axisMaxForTopLabel(
      peak: peak,
      labelPixels: longest,
      plotHeight: chartHeight - bottomReserved,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SegmentedButton<HistogramSpan>(
          showSelectedIcon: true,
          segments: const [
            ButtonSegment(value: HistogramSpan.weekly, label: Text('Weekly')),
            ButtonSegment(value: HistogramSpan.monthly, label: Text('Monthly')),
            ButtonSegment(value: HistogramSpan.yearly, label: Text('Yearly')),
          ],
          selected: {span},
          onSelectionChanged: (next) => onSpan(next.first),
        ),
        const SizedBox(height: 12),
        if (bars.isEmpty)
          const SizedBox(
            height: 120,
            child: Center(child: Text('No priced buy days yet.')),
          )
        else
          ScrollingPlot(
            scrollKey: '${span.name}-${bars.length}-${bars.last.label}',
            itemCount: bars.length,
            visibleCount: 5,
            alignEnd: true,
            minY: 0,
            maxY: maxY,
            height: chartHeight,
            bottomReserved: bottomReserved,
            formatTick: (value) => axisPrice(value, maxY),
            hint: 'Swipe sideways for older periods.',
            builder: (width, slot) {
              final barWidth = (slot * 0.46).clamp(8.0, 36.0);
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
                      maxContentWidth: 160,
                      getTooltipColor: (_) => scheme.inverseSurface,
                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                        final bar = bars[group.x];
                        return BarTooltipItem(
                          '${bar.label}\n${fullRupee(bar.total)}',
                          TextStyle(color: scheme.onInverseSurface, height: 1.3),
                        );
                      },
                    ),
                  ),
                  titlesData: chartTitles(
                    bottomReserved: bottomReserved,
                    bottom: (value, meta) {
                      final index = value.toInt();
                      if (index < 0 || index >= bars.length) {
                        return const SizedBox.shrink();
                      }
                      return SideTitleWidget(
                        meta: meta,
                        space: 6,
                        child: SizedBox(
                          width: slot * 0.95,
                          child: Text(
                            bars[index].label,
                            textAlign: TextAlign.center,
                            maxLines: 2,
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
                    for (var i = 0; i < bars.length; i++)
                      BarChartGroupData(
                        x: i,
                        barRods: [
                          BarChartRodData(
                            toY: bars[i].total,
                            width: barWidth,
                            color: histogramColor(brightness),
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(6),
                            ),
                            label: _sumLabel(labels[i], labelStyle),
                          ),
                        ],
                      ),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }
}

BarChartRodLabel _sumLabel(String text, TextStyle style) {
  final size = measureChartLabel(text, style);
  return BarChartRodLabel(
    show: true,
    text: text,
    angle: -90,
    offset: labelAboveBarOffset(textWidth: size.width, textHeight: size.height),
    style: style,
  );
}
