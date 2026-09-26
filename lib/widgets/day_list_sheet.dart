import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../logic/dates.dart';
import '../logic/recurrence.dart';
import '../state/calendar_controller.dart';
import '../theme/calendar_theme.dart';
import 'buy_sheet.dart';

Future<void> showDayList(BuildContext context, {required DateTime day}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => DayListSheet(day: dateOnly(day)),
  );
}

class DayListSheet extends StatelessWidget {
  const DayListSheet({super.key, required this.day});

  final DateTime day;

  @override
  Widget build(BuildContext context) {
    final calendar = context.watch<CalendarController>();
    final colors = calendarColors(context);
    final buys = buysOn(calendar.series, day);
    final height = MediaQuery.sizeOf(context).height * 0.55;

    return SizedBox(
      height: height,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 12, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(prettyDate(day), style: Theme.of(context).textTheme.titleLarge),
                ),
                FloatingActionButton.small(
                  heroTag: 'add-on-day',
                  onPressed: () => showBuySheet(context, day: day),
                  child: const Icon(Icons.add),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: buys.isEmpty
                ? Center(
                    child: Text(
                      'No buys on this day',
                      style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                    ),
                  )
                : ListView.separated(
                    itemCount: buys.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final buy = buys[index];
                      return ListTile(
                        leading: Container(width: 4, height: 36, color: colors.today),
                        title: Text(buy.series.stockName),
                        subtitle: Text(
                          buy.series.notes.isEmpty
                              ? buy.series.symbol
                              : '${buy.series.symbol} · ${buy.series.notes}',
                        ),
                        onTap: () => showBuySheet(context, day: day, existing: buy.series),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
