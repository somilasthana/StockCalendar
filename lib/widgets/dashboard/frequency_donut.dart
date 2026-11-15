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
  Offset? _popupAt;

  void _clear() {
    if (_touched == null && _popupAt == null) return;
    setState(() {
      _touched = null;
      _popupAt = null;
    });
  }

  void _show(int index, Offset at) {
    setState(() {
      _touched = index;
      _popupAt = at;
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final total = widget.counts.fold<int>(0, (sum, row) => sum + row.count);
    final touched = _touched != null && _touched! < widget.counts.length
        ? _touched
        : null;
    final popupAt = touched == null ? null : _popupAt;
    return TapRegion(
      onTapOutside: (_) => _clear(),
      child: MouseRegion(
        onExit: (_) => _clear(),
        child: SizedBox(
          height: 240,
          child: LayoutBuilder(
            builder: (context, constraints) {
              return Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  PieChart(
                    PieChartData(
                      startDegreeOffset: -90,
                      sectionsSpace: 3,
                      centerSpaceRadius: 62,
                      pieTouchData: PieTouchData(
                        touchCallback: (event, response) {
                          final index =
                              response?.touchedSection?.touchedSectionIndex;
                          final hit = index != null && index >= 0 ? index : null;
                          if (event is FlPointerHoverEvent) {
                            if (_touched != null && hit != _touched) _clear();
                            return;
                          }
                          if (event is! FlTapUpEvent) return;
                          if (hit == null || response == null) {
                            _clear();
                            return;
                          }
                          _show(hit, response.touchLocation);
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
                  if (touched != null && popupAt != null)
                    _SlicePopup(
                      bounds: constraints.biggest,
                      anchor: popupAt,
                      color: dashboardColor(touched),
                      row: widget.counts[touched],
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _SlicePopup extends StatelessWidget {
  const _SlicePopup({
    required this.bounds,
    required this.anchor,
    required this.color,
    required this.row,
  });

  final Size bounds;
  final Offset anchor;
  final Color color;
  final SymbolCount row;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final brightness = Theme.of(context).brightness;
    const width = 188.0;
    final maxLeft = bounds.width - width;
    final left = maxLeft <= 0
        ? 0.0
        : (anchor.dx - width / 2).clamp(0.0, maxLeft);
    final top = (anchor.dy - 78).clamp(0.0, bounds.height - 8);
    final name = row.name.trim().isEmpty ? row.symbol : row.name.trim();
    final style = TextStyle(
      fontSize: 12,
      height: 1.35,
      color: scheme.onSurface,
    );
    return Positioned(
      left: left,
      top: top,
      width: width,
      child: IgnorePointer(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: chartSurface(brightness, scheme),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Stock Name: $name', style: style),
                Text('Cnt: ${row.count}', style: style),
                Text('Percent (%): ${_percent(row.share)}', style: style),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String _percent(double share) {
  final text = (share * 100).toStringAsFixed(1);
  if (text.endsWith('.0')) return text.substring(0, text.length - 2);
  return text;
}
