import 'package:flutter/material.dart';

import '../logic/dates.dart';
import '../logic/recurrence.dart';
import '../models/buy_series.dart';
import '../theme/calendar_theme.dart';
import 'calendar_bits.dart';

class WeekView extends StatelessWidget {
  const WeekView({
    super.key,
    required this.selected,
    required this.series,
    required this.onDay,
  });

  final DateTime selected;
  final List<BuySeries> series;
  final ValueChanged<DateTime> onDay;

  @override
  Widget build(BuildContext context) {
    final colors = calendarColors(context);
    final today = dateOnly(DateTime.now());
    final start = startOfWeek(selected);
    final days = [for (var index = 0; index < 7; index++) addDays(start, index)];
    const letters = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

    return Column(
      children: [
        Row(
          children: [
            for (var index = 0; index < 7; index++)
              Expanded(
                child: InkWell(
                  onTap: isWeekend(days[index]) ? null : () => onDay(days[index]),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Column(
                      children: [
                        Text(
                          letters[index],
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: index >= 5
                                ? colors.weekend
                                : Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 4),
                        DayNumber(
                          date: days[index],
                          today: today,
                          selected: dateOnly(days[index]) == dateOnly(selected),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
        Divider(height: 1, color: colors.gridLine),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final day in days)
                Expanded(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: isWeekend(day) ? colors.closed : null,
                      border: Border(left: BorderSide(color: colors.gridLine)),
                    ),
                    child: isWeekend(day)
                        ? const SizedBox.expand()
                        : _WeekColumn(
                            buys: buysOn(series, day),
                            onOpen: () => onDay(day),
                          ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _WeekColumn extends StatelessWidget {
  const _WeekColumn({required this.buys, required this.onOpen});

  final List<DayBuy> buys;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    if (buys.isEmpty) {
      return InkWell(onTap: onOpen);
    }
    return ListView(
      padding: const EdgeInsets.all(4),
      children: [
        for (final buy in buys)
          StockChip(name: buy.series.stockName, fontSize: 11, onTap: onOpen),
      ],
    );
  }
}
