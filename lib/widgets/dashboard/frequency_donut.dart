import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../logic/dashboard_format.dart';
import '../../logic/dashboard_metrics.dart';
import 'dashboard_style.dart';

class FrequencyDonut extends StatefulWidget {
  const FrequencyDonut({super.key, required this.counts, this.noun = 'buy'})
    : amounts = null;

  const FrequencyDonut.amounts({super.key, required this.amounts})
    : counts = const [],
      noun = 'current';

  final List<SymbolCount> counts;

  /// When set, slice size and percent follow the current value.
  final List<SymbolInvestment>? amounts;

  /// Singular word under the center total. Count mode uses "buy".
  final String noun;

  @override
  State<FrequencyDonut> createState() => _FrequencyDonutState();
}

class _DonutRow {
  const _DonutRow({
    required this.name,
    required this.value,
    required this.share,
    required this.detail,
  });

  final String name;
  final double value;
  final double share;
  final String detail;
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

  List<_DonutRow> get _rows {
    final amounts = widget.amounts;
    if (amounts != null) {
      return [
        for (final row in amounts)
          _DonutRow(
            name: row.name.trim().isEmpty ? row.symbol : row.name.trim(),
            value: row.amount,
            share: row.share,
            detail: 'Current: ${fullRupee(row.amount)}',
          ),
      ];
    }
    return [
      for (final row in widget.counts)
        _DonutRow(
          name: row.name.trim().isEmpty ? row.symbol : row.name.trim(),
          value: row.count.toDouble(),
          share: row.share,
          detail: 'Cnt: ${row.count}',
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final rows = _rows;
    final money = widget.amounts != null;
    final total = rows.fold<double>(0, (sum, row) => sum + row.value);
    final touched = _touched != null && _touched! < rows.length ? _touched : null;
    final popupAt = touched == null ? null : _popupAt;
    final center = money ? fullRupee(total) : total.round().toString();
    final caption = money
        ? 'current'
        : (total == 1 ? widget.noun : '${widget.noun}s');
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
                        for (var i = 0; i < rows.length; i++)
                          PieChartSectionData(
                            value: rows[i].value,
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
                        SizedBox(
                          width: 110,
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              center,
                              style: Theme.of(context).textTheme.headlineSmall,
                            ),
                          ),
                        ),
                        Text(
                          caption,
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
                      row: rows[touched],
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
  final _DonutRow row;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final brightness = Theme.of(context).brightness;
    const width = 220.0;
    final maxLeft = bounds.width - width;
    final left = maxLeft <= 0
        ? 0.0
        : (anchor.dx - width / 2).clamp(0.0, maxLeft);
    final top = (anchor.dy - 78).clamp(0.0, bounds.height - 8);
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
                Text('Stock Name: ${row.name}', style: style),
                Text(row.detail, style: style),
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
