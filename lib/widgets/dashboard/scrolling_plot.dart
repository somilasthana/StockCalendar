import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../logic/dashboard_format.dart';

/// A wide chart with a fixed rupee axis. About [visibleCount] items stay on
/// screen and the rest move with a horizontal swipe.
class ScrollingPlot extends StatefulWidget {
  const ScrollingPlot({
    super.key,
    required this.scrollKey,
    required this.itemCount,
    required this.visibleCount,
    required this.alignEnd,
    required this.minY,
    required this.maxY,
    required this.bottomReserved,
    required this.formatTick,
    required this.builder,
    this.height = 240,
    this.hint,
  });

  final String scrollKey;
  final int itemCount;
  final int visibleCount;
  final bool alignEnd;
  final double minY;
  final double maxY;
  final double bottomReserved;
  final double height;
  final String? hint;
  final String Function(double value) formatTick;
  final Widget Function(double width, double slot) builder;

  @override
  State<ScrollingPlot> createState() => _ScrollingPlotState();
}

class _ScrollingPlotState extends State<ScrollingPlot> {
  final _scroll = ScrollController();
  String? _alignedKey;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _align([int attempt = 0]) {
    if (!mounted) return;
    if (!_scroll.hasClients) {
      if (attempt < 8) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _align(attempt + 1));
      }
      return;
    }
    final target = widget.alignEnd
        ? _scroll.position.maxScrollExtent
        : _scroll.position.minScrollExtent;
    final waitingForExtent = widget.alignEnd &&
        widget.itemCount > widget.visibleCount &&
        target == 0 &&
        attempt < 8;
    if (waitingForExtent) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _align(attempt + 1));
      return;
    }
    if (_alignedKey == widget.scrollKey) return;
    _alignedKey = widget.scrollKey;
    if (_scroll.offset != target) _scroll.jumpTo(target);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (_alignedKey != widget.scrollKey) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _align());
    }
    final canScroll = widget.itemCount > widget.visibleCount;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: widget.height,
          child: Row(
            children: [
              _YAxis(
                height: widget.height,
                bottomReserved: widget.bottomReserved,
                minY: widget.minY,
                maxY: widget.maxY,
                formatTick: widget.formatTick,
              ),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final viewport = constraints.maxWidth;
                    final count = widget.itemCount < 1 ? 1 : widget.itemCount;
                    final visible = count < widget.visibleCount
                        ? count
                        : widget.visibleCount;
                    final slot = viewport / visible;
                    final width = count <= widget.visibleCount
                        ? viewport
                        : count * slot;
                    return SingleChildScrollView(
                      controller: _scroll,
                      scrollDirection: Axis.horizontal,
                      child: SizedBox(
                        width: width,
                        height: widget.height,
                        child: widget.builder(width, width / count),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        if (canScroll && widget.hint != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              widget.hint!,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
      ],
    );
  }
}

class _YAxis extends StatelessWidget {
  const _YAxis({
    required this.height,
    required this.bottomReserved,
    required this.minY,
    required this.maxY,
    required this.formatTick,
  });

  final double height;
  final double bottomReserved;
  final double minY;
  final double maxY;
  final String Function(double value) formatTick;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final style = TextStyle(fontSize: 10, color: scheme.onSurfaceVariant);
    final span = maxY - minY;
    final ticks = [
      for (var step = 0; step <= 4; step++) minY + span * step / 4,
    ];
    return SizedBox(
      width: 52,
      height: height,
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomReserved, right: 4),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final plot = constraints.maxHeight;
            return Stack(
              clipBehavior: Clip.none,
              children: [
                for (var i = 0; i < ticks.length; i++)
                  Positioned(
                    right: 0,
                    top: (plot - plot * i / 4 - 6).clamp(0.0, plot - 12),
                    child: Text(formatTick(ticks[i]), style: style),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

FlGridData chartGrid(ColorScheme scheme, double interval) {
  return FlGridData(
    show: true,
    drawVerticalLine: false,
    horizontalInterval: interval == 0 ? 1 : interval,
    getDrawingHorizontalLine: (value) => FlLine(
      color: scheme.outlineVariant.withValues(alpha: 0.7),
      strokeWidth: 1,
    ),
  );
}

FlTitlesData chartTitles({
  required Widget Function(double value, TitleMeta meta) bottom,
  double bottomReserved = 36,
}) {
  return FlTitlesData(
    topTitles: const AxisTitles(
      sideTitles: SideTitles(showTitles: false, reservedSize: 0),
    ),
    rightTitles: const AxisTitles(
      sideTitles: SideTitles(showTitles: false, reservedSize: 0),
    ),
    leftTitles: const AxisTitles(
      sideTitles: SideTitles(showTitles: false, reservedSize: 0),
    ),
    bottomTitles: AxisTitles(
      sideTitles: SideTitles(
        showTitles: true,
        reservedSize: bottomReserved,
        interval: 1,
        getTitlesWidget: bottom,
      ),
    ),
  );
}

Size measureChartLabel(
  String text,
  TextStyle style, {
  TextScaler textScaler = TextScaler.noScaling,
}) {
  final painter = TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: TextDirection.ltr,
    textScaler: textScaler,
    maxLines: 1,
  )..layout();
  final size = painter.size;
  painter.dispose();
  return size;
}

/// Rotated rod label sitting just above the bar, centered on that bar.
Offset labelAboveBarOffset({
  required double textWidth,
  required double textHeight,
  double gap = 4,
}) {
  return Offset(0, textWidth / 2 - textHeight / 2 + gap);
}

/// Raises the axis enough for a vertical label above the tallest bar.
double axisMaxForTopLabel({
  required double peak,
  required double labelPixels,
  required double plotHeight,
  double gap = 6,
}) {
  if (plotHeight <= 0) return niceMax(peak);
  final fraction = ((labelPixels + gap) / plotHeight).clamp(0.0, 0.6);
  final room = peak <= 0 ? 4.0 : peak / (1 - fraction);
  return niceMax(room);
}

String axisPrice(double value, double span) {
  if (span < 20 && value.abs() < 10000) {
    return '₹${value.toStringAsFixed(value.abs() >= 100 ? 0 : 2)}';
  }
  return shortRupee(value);
}
