import 'package:flutter/material.dart';

import '../logic/dates.dart';
import '../theme/calendar_theme.dart';

class DayNumber extends StatelessWidget {
  const DayNumber({
    super.key,
    required this.date,
    required this.today,
    this.selected = false,
    this.muted = false,
    this.size = 28,
    this.fontSize = 12,
  });

  final DateTime date;
  final DateTime today;
  final bool selected;
  final bool muted;
  final double size;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final colors = calendarColors(context);
    final weekend = isWeekend(date);
    final isToday = dateOnly(date) == dateOnly(today);
    final Color foreground;
    if (isToday) {
      foreground = colors.onToday;
    } else if (muted) {
      foreground = colors.outside;
    } else if (weekend) {
      foreground = colors.weekend;
    } else {
      foreground = Theme.of(context).colorScheme.onSurface;
    }

    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: isToday ? colors.today : null,
        shape: BoxShape.circle,
        border: !isToday && selected
            ? Border.all(color: colors.selected, width: 1.5)
            : null,
      ),
      child: Text(
        '${date.day}',
        style: TextStyle(
          color: foreground,
          fontSize: fontSize,
          fontWeight: isToday ? FontWeight.w600 : FontWeight.w500,
        ),
      ),
    );
  }
}

class StockChip extends StatelessWidget {
  const StockChip({super.key, required this.name, this.onTap, this.fontSize = 10});

  final String name;
  final VoidCallback? onTap;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final colors = calendarColors(context);
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Material(
        color: colors.chipBackground,
        borderRadius: BorderRadius.circular(4),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(4),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: colors.chipForeground,
                fontSize: fontSize,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class WeekdayHeader extends StatelessWidget {
  const WeekdayHeader({super.key, this.labels = const ['M', 'T', 'W', 'T', 'F', 'S', 'S']});

  final List<String> labels;

  @override
  Widget build(BuildContext context) {
    final colors = calendarColors(context);
    final style = Theme.of(context).textTheme.labelMedium;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          for (var index = 0; index < 7; index++)
            Expanded(
              child: Text(
                labels[index],
                textAlign: TextAlign.center,
                style: style?.copyWith(
                  color: index >= 5 ? colors.weekend : Theme.of(context).colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
