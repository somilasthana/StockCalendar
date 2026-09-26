import 'package:flutter/material.dart';

import '../logic/dates.dart';
import '../theme/calendar_theme.dart';

class YearView extends StatelessWidget {
  const YearView({
    super.key,
    required this.year,
    required this.onMonth,
    required this.onDay,
  });

  final int year;
  final void Function(int year, int month) onMonth;
  final ValueChanged<DateTime> onDay;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 88),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 12,
        crossAxisSpacing: 8,
        childAspectRatio: 0.68,
      ),
      itemCount: 12,
      itemBuilder: (context, index) {
        return _MiniMonth(
          year: year,
          month: index + 1,
          onMonth: onMonth,
          onDay: onDay,
        );
      },
    );
  }
}

class _MiniMonth extends StatelessWidget {
  const _MiniMonth({
    required this.year,
    required this.month,
    required this.onMonth,
    required this.onDay,
  });

  final int year;
  final int month;
  final void Function(int year, int month) onMonth;
  final ValueChanged<DateTime> onDay;

  @override
  Widget build(BuildContext context) {
    final colors = calendarColors(context);
    final today = dateOnly(DateTime.now());
    final first = DateTime(year, month, 1);
    final gridStart = startOfWeek(first);
    final count = daysInMonth(year, month);
    final cells = <DateTime?>[];
    for (var index = 0; index < 42; index++) {
      final date = addDays(gridStart, index);
      if (date.month == month && date.day <= count && !date.isBefore(first)) {
        cells.add(date);
      } else if (date.isBefore(first) || date.month != month) {
        cells.add(null);
      }
    }
    while (cells.isNotEmpty && cells.last == null) {
      cells.removeLast();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          onTap: () => onMonth(year, month),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              monthLong[month - 1],
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ),
        Row(
          children: [
            for (final letter in const ['M', 'T', 'W', 'T', 'F', 'S', 'S'])
              Expanded(
                child: Text(
                  letter,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 9,
                    color: letter == 'S' ? colors.weekend : Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
          ],
        ),
        for (var row = 0; row < (cells.length / 7).ceil(); row++)
          Row(
            children: [
              for (var column = 0; column < 7; column++)
                Expanded(
                  child: _miniDay(
                    context,
                    row * 7 + column < cells.length ? cells[row * 7 + column] : null,
                    today,
                    colors,
                  ),
                ),
            ],
          ),
      ],
    );
  }

  Widget _miniDay(BuildContext context, DateTime? date, DateTime today, CalendarColors colors) {
    if (date == null) return const SizedBox(height: 16);
    final weekend = isWeekend(date);
    return InkWell(
      onTap: () => onDay(date),
      child: SizedBox(
        height: 16,
        child: Center(
          child: Text(
            '${date.day}',
            style: TextStyle(
              fontSize: 9,
              fontWeight: dateOnly(date) == today ? FontWeight.w700 : FontWeight.w400,
              color: dateOnly(date) == today
                  ? colors.today
                  : weekend
                      ? colors.weekend
                      : Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ),
      ),
    );
  }
}
