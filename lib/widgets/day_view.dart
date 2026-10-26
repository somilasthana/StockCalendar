import 'package:flutter/material.dart';

import '../logic/dates.dart';
import '../logic/recurrence.dart';
import '../models/buy_series.dart';
import '../theme/calendar_theme.dart';

class DayView extends StatelessWidget {
  const DayView({
    super.key,
    required this.selected,
    required this.series,
    required this.onOpenBuy,
  });

  final DateTime selected;
  final List<BuySeries> series;
  final ValueChanged<BuySeries> onOpenBuy;

  @override
  Widget build(BuildContext context) {
    final colors = calendarColors(context);
    final day = dateOnly(selected);
    final weekend = isWeekend(day);
    final buys = weekend ? const <DayBuy>[] : buysOn(series, day);
    final titleColor = weekend ? colors.weekend : Theme.of(context).colorScheme.onSurface;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
      children: [
        Row(
          children: [
            Text(
              '${day.day}',
              style: TextStyle(fontSize: 38, fontWeight: FontWeight.w500, color: titleColor),
            ),
            const SizedBox(width: 12),
            Text(
              weekdayShort[day.weekday - 1],
              style: TextStyle(fontSize: 24, color: titleColor),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Divider(color: colors.gridLine),
        if (weekend)
          Padding(
            padding: const EdgeInsets.only(top: 48),
            child: Column(
              children: [
                Icon(Icons.storefront_outlined, size: 40, color: colors.weekend),
                const SizedBox(height: 12),
                Text(
                  'Market closed',
                  style: TextStyle(fontSize: 20, color: colors.weekend),
                ),
              ],
            ),
          )
        else if (buys.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 32),
            child: Text(
              'No buys on this day',
              style: TextStyle(
                fontSize: 16,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          )
        else
          for (final buy in buys)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Container(
                width: 4,
                height: 36,
                color: colors.today,
              ),
              title: Text(buy.series.stockName, style: const TextStyle(fontSize: 18)),
              subtitle: Text(buy.series.symbol, style: const TextStyle(fontSize: 16)),
              onTap: () => onOpenBuy(buy.series),
            ),
      ],
    );
  }
}
