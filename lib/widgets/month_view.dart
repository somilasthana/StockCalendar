import 'package:flutter/material.dart';

import '../logic/dates.dart';
import '../logic/recurrence.dart';
import '../models/buy_series.dart';
import '../theme/calendar_theme.dart';
import 'calendar_bits.dart';

class MonthView extends StatelessWidget {
  const MonthView({
    super.key,
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
        const WeekdayHeader(),
        Expanded(
          child: Column(
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
    final buys = buysOn(series, date);
    final shown = buys.take(3).toList();
    final extra = buys.length - shown.length;

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: colors.gridLine)),
      ),
      child: InkWell(
        onTap: weekend ? null : () => onDay(date),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(2, 2, 2, 2),
          child: Column(
            children: [
              DayNumber(
                date: date,
                today: today,
                selected: dateOnly(date) == selected,
                muted: !inMonth,
                size: 24,
                fontSize: 12,
              ),
              if (!weekend)
                for (final buy in shown)
                  StockChip(name: buy.series.stockName),
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
          ),
        ),
      ),
    );
  }
}
