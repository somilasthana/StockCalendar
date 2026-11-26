import 'package:flutter/material.dart';

import '../logic/dates.dart';
import '../theme/calendar_theme.dart';
import 'calendar_bits.dart';

/// Month calendar. Returns the chosen start date, or null if dismissed.
Future<DateTime?> showStartDatePicker(
  BuildContext context, {
  required DateTime today,
}) {
  return showDialog<DateTime>(
    context: context,
    builder: (context) => _StartDateDialog(today: dateOnly(today)),
  );
}

class _StartDateDialog extends StatefulWidget {
  const _StartDateDialog({required this.today});

  final DateTime today;

  @override
  State<_StartDateDialog> createState() => _StartDateDialogState();
}

class _StartDateDialogState extends State<_StartDateDialog> {
  late DateTime _month;

  @override
  void initState() {
    super.initState();
    _month = DateTime(widget.today.year, widget.today.month, 1);
  }

  @override
  Widget build(BuildContext context) {
    final colors = calendarColors(context);
    final theme = Theme.of(context);
    final first = DateTime(_month.year, _month.month, 1);
    final gridStart = startOfWeek(first);
    final days = [
      for (var index = 0; index < 42; index++) addDays(gridStart, index),
    ];

    return Dialog(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 20, 12, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                'Select a starting date for this scrip',
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                IconButton(
                  tooltip: 'Previous month',
                  onPressed: () => setState(() {
                    _month = DateTime(_month.year, _month.month - 1, 1);
                  }),
                  icon: const Icon(Icons.chevron_left),
                ),
                Expanded(
                  child: Text(
                    monthTitle(_month),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Next month',
                  onPressed: () => setState(() {
                    _month = DateTime(_month.year, _month.month + 1, 1);
                  }),
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
            const WeekdayHeader(),
            for (var row = 0; row < 6; row++)
              Row(
                children: [
                  for (var column = 0; column < 7; column++)
                    Expanded(
                      child: _dayButton(days[row * 7 + column], colors),
                    ),
                ],
              ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dayButton(DateTime date, CalendarColors colors) {
    final inMonth = date.month == _month.month && date.year == _month.year;
    final afterToday = dateOnly(date).isAfter(widget.today);
    final enabled = inMonth && !afterToday;

    return InkWell(
      onTap: enabled ? () => Navigator.pop(context, dateOnly(date)) : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: DayNumber(
          date: date,
          today: widget.today,
          muted: !enabled,
          size: 32,
        ),
      ),
    );
  }
}
