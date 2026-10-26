import 'package:flutter/material.dart';

import '../logic/dates.dart';
import '../logic/recurrence.dart';
import '../models/buy_series.dart';
import '../theme/calendar_theme.dart';
import 'calendar_bits.dart';

class MonthView extends StatefulWidget {
  const MonthView({
    super.key,
    required this.visible,
    required this.selected,
    required this.series,
    required this.onDay,
    required this.onMonth,
  });

  final DateTime visible;
  final DateTime selected;
  final List<BuySeries> series;
  final ValueChanged<DateTime> onDay;
  final ValueChanged<DateTime> onMonth;

  @override
  State<MonthView> createState() => _MonthViewState();
}

class _MonthViewState extends State<MonthView> {
  static const _startYear = 1970;
  static const _pageCount = 131 * 12;

  late final PageController _controller;

  int _indexFor(DateTime date) {
    final index = (date.year - _startYear) * 12 + date.month - 1;
    if (index < 0) return 0;
    if (index >= _pageCount) return _pageCount - 1;
    return index;
  }

  DateTime _monthFor(int index) {
    final year = _startYear + index ~/ 12;
    final month = index % 12 + 1;
    return DateTime(year, month, 1);
  }

  @override
  void initState() {
    super.initState();
    _controller = PageController(initialPage: _indexFor(widget.visible));
  }

  @override
  void didUpdateWidget(MonthView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_indexFor(oldWidget.visible) == _indexFor(widget.visible)) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _reveal(_indexFor(widget.visible));
    });
  }

  void _reveal(int target) {
    if (!_controller.hasClients) return;
    final current = _controller.page?.round() ?? _controller.initialPage;
    if (current == target) return;
    if ((target - current).abs() == 1) {
      _controller.animateToPage(
        target,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
      return;
    }
    _controller.jumpToPage(target);
  }

  void _handlePage(int index) {
    final month = _monthFor(index);
    final day = clampDate(month.year, month.month, widget.selected.day);
    final selected = dateOnly(widget.selected);
    if (day == selected) return;
    widget.onMonth(day);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const WeekdayHeader(larger: true),
        Expanded(
          child: PageView.builder(
            controller: _controller,
            itemCount: _pageCount,
            onPageChanged: _handlePage,
            itemBuilder: (context, index) {
              return _MonthGrid(
                visible: _monthFor(index),
                selected: widget.selected,
                series: widget.series,
                onDay: widget.onDay,
              );
            },
          ),
        ),
      ],
    );
  }
}

class _MonthGrid extends StatelessWidget {
  const _MonthGrid({
    required this.visible,
    required this.selected,
    required this.series,
    required this.onDay,
  });

  final DateTime visible;
  final DateTime selected;
  final List<BuySeries> series;
  final ValueChanged<DateTime> onDay;

  @override
  Widget build(BuildContext context) {
    final colors = calendarColors(context);
    final today = dateOnly(DateTime.now());
    final first = DateTime(visible.year, visible.month, 1);
    final gridStart = startOfWeek(first);
    final days = [for (var index = 0; index < 42; index++) addDays(gridStart, index)];

    return Column(
      children: [
        for (var row = 0; row < 6; row++)
          Expanded(
            child: Row(
              children: [
                for (var column = 0; column < 7; column++)
                  Expanded(
                    child: _MonthCell(
                      date: days[row * 7 + column],
                      inMonth: days[row * 7 + column].month == visible.month,
                      today: today,
                      selected: dateOnly(selected),
                      series: series,
                      colors: colors,
                      onDay: onDay,
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class _MonthCell extends StatelessWidget {
  const _MonthCell({
    required this.date,
    required this.inMonth,
    required this.today,
    required this.selected,
    required this.series,
    required this.colors,
    required this.onDay,
  });

  final DateTime date;
  final bool inMonth;
  final DateTime today;
  final DateTime selected;
  final List<BuySeries> series;
  final CalendarColors colors;
  final ValueChanged<DateTime> onDay;

  @override
  Widget build(BuildContext context) {
    final weekend = isWeekend(date);
    final isToday = dateOnly(date) == dateOnly(today);
    final buys = weekend ? const <DayBuy>[] : buysOn(series, date);

    return DecoratedBox(
      decoration: BoxDecoration(
        border: isToday
            ? Border.all(color: colors.today, width: 1.5)
            : Border(top: BorderSide(color: colors.gridLine)),
      ),
      child: InkWell(
        onTap: weekend ? null : () => onDay(date),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(2, 2, 2, 2),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final shown = _fits(constraints.maxHeight, buys, MediaQuery.textScalerOf(context));
              final extra = buys.length - shown.length;
              return Column(
                children: [
                  DayNumber(
                    date: date,
                    today: today,
                    selected: dateOnly(date) == selected,
                    muted: !inMonth,
                    size: 26,
                    fontSize: 14,
                  ),
                  for (final buy in shown)
                    _MonthEvent(name: buy.series.stockName, color: colors.today),
                  if (extra > 0)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Padding(
                        padding: const EdgeInsets.only(left: 2, top: 1),
                        child: Text(
                          '+$extra',
                          style: TextStyle(fontSize: 10, color: colors.chipForeground),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  List<DayBuy> _fits(double maxHeight, List<DayBuy> buys, TextScaler scaler) {
    if (buys.isEmpty) return const [];
    const dayHeight = 26.0;
    final chipHeight = _monthEventHeight(10, scaler);
    final extraHeight = scaler.scale(10) + 3;
    var room = maxHeight - dayHeight;
    if (!room.isFinite) return buys.take(2).toList();
    final shown = <DayBuy>[];
    for (var index = 0; index < buys.length; index++) {
      final more = buys.length - index - 1;
      final reserve = more > 0 ? extraHeight : 0.0;
      if (room < chipHeight + reserve) break;
      shown.add(buys[index]);
      room -= chipHeight;
    }
    return shown;
  }
}

double _monthEventHeight(double fontSize, TextScaler scaler, {int maxLines = 2}) {
  return 2 + scaler.scale(fontSize) * 1.15 * maxLines;
}

class _MonthEvent extends StatelessWidget {
  const _MonthEvent({required this.name, required this.color});

  final String name;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: SizedBox(
        width: double.infinity,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(1.5),
                ),
                child: const SizedBox(width: 3),
              ),
              const SizedBox(width: 3),
              Expanded(
                child: Text(
                  name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontSize: 10,
                    height: 1.15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
