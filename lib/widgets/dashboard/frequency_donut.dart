import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../logic/dashboard_metrics.dart';
import 'dashboard_style.dart';

class FrequencyDonut extends StatefulWidget {
  const FrequencyDonut({super.key, required this.counts});

  final List<SymbolCount> counts;

  @override
  State<FrequencyDonut> createState() => _FrequencyDonutState();
}

class _FrequencyDonutState extends State<FrequencyDonut> {
  int? _touched;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final total = widget.counts.fold<int>(0, (sum, row) => sum + row.count);
    final touched = _touched != null && _touched! < widget.counts.length
        ? _touched
        : null;
    return Column(
      children: [
        SizedBox(
          height: 220,
          child: Stack(
            alignment: Alignment.center,
            children: [
              PieChart(
                PieChartData(
                  startDegreeOffset: -90,
                  sectionsSpace: 3,
                  centerSpaceRadius: 62,
                  pieTouchData: PieTouchData(
                    touchCallback: (event, response) {
                      final index = response?.touchedSection?.touchedSectionIndex;
                      setState(() {
                        _touched = index != null && index >= 0 ? index : null;
                      });
                    },
                  ),
                  sections: [
                    for (var i = 0; i < widget.counts.length; i++)
                      PieChartSectionData(
                        value: widget.counts[i].count.toDouble(),
                        color: dashboardColor(i),
                        radius: touched == i ? 58 : 48,
                        showTitle: false,
                      ),
                  ],
                ),
              ),
              IgnorePointer(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$total',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    Text(
                      total == 1 ? 'buy' : 'buys',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        for (var i = 0; i < widget.counts.length; i++)
          _LegendRow(
            color: dashboardColor(i),
            symbol: widget.counts[i].symbol,
            count: widget.counts[i].count,
            percent: (widget.counts[i].share * 100).round(),
            highlighted: touched == i,
          ),
      ],
    );
  }
}

class _LegendRow extends StatelessWidget {
  const _LegendRow({
    required this.color,
    required this.symbol,
    required this.count,
    required this.percent,
    required this.highlighted,
  });

  final Color color;
  final String symbol;
  final int count;
  final int percent;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: highlighted ? scheme.surfaceContainerHighest : null,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(symbol, style: Theme.of(context).textTheme.titleSmall),
          ),
          Text('$count', style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(width: 12),
          SizedBox(
            width: 44,
            child: Text(
              '$percent%',
              textAlign: TextAlign.end,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
