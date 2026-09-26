import 'package:flutter/material.dart';

import '../logic/dates.dart';
import '../theme/calendar_theme.dart';
import 'calendar_bits.dart';

Future<DateTime?> showUntilPicker(
  BuildContext context, {
  required DateTime anchor,
  DateTime? selected,
}) {
  return showDialog<DateTime>(
    context: context,
    builder: (context) => _UntilDialog(anchor: dateOnly(anchor), selected: selected),
  );
}

class _UntilDialog extends StatefulWidget {
  const _UntilDialog({required this.anchor, this.selected});

  final DateTime anchor;
  final DateTime? selected;

  @override
  State<_UntilDialog> createState() => _UntilDialogState();
}

class _UntilDialogState extends State<_UntilDialog> {
  late DateTime _month;

  @override
  void initState() {
    super.initState();
    final start = widget.selected ?? widget.anchor;
    final earliest = DateTime(widget.anchor.year, widget.anchor.month, 1);
    final candidate = DateTime(start.year, start.month, 1);
    _month = candidate.isBefore(earliest) ? earliest : candidate;
  }

  bool get _canGoBack {
    final shown = _month.year * 12 + _month.month;
    final first = widget.anchor.year * 12 + widget.anchor.month;
    return shown > first;
  }

  @override
  Widget build(BuildContext context) {
    final colors = calendarColors(context);
    final first = DateTime(_month.year, _month.month, 1);
    final gridStart = startOfWeek(first);
    final days = [for (var index = 0; index < 42; index++) addDays(gridStart, index)];

    return Dialog(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                IconButton(
                  tooltip: 'Previous month',
                  onPressed: _canGoBack
                      ? () => setState(() {
                            _month = DateTime(_month.year, _month.month - 1, 1);
                          })
                      : null,
                  icon: const Icon(Icons.chevron_left),
                ),
                Expanded(
                  child: Text(
                    monthTitle(_month),
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
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
          ],
        ),
      ),
    );
  }

  Widget _dayButton(DateTime date, CalendarColors colors) {
    final inMonth = date.month == _month.month;
    final weekend = isWeekend(date);
    final beforeStart = date.isBefore(widget.anchor);
    final enabled = inMonth && !weekend && !beforeStart;
    final chosen = widget.selected != null && dateOnly(widget.selected!) == dateOnly(date);

    return InkWell(
      onTap: enabled ? () => Navigator.pop(context, dateOnly(date)) : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: DayNumber(
          date: date,
          today: dateOnly(DateTime.now()),
          selected: chosen,
          muted: !enabled,
          size: 32,
        ),
      ),
    );
  }
}
