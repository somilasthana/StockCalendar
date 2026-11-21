import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../logic/dates.dart';
import '../logic/recurrence.dart';
import '../state/auth_controller.dart';
import '../state/calendar_controller.dart';
import '../widgets/buy_sheet.dart';
import '../widgets/day_list_sheet.dart';
import '../widgets/day_view.dart';
import '../widgets/month_view.dart';
import '../widgets/week_view.dart';
import '../widgets/year_view.dart';
import 'expert_import.dart';
import 'expert_opinion_screen.dart';
import 'expert_side_menu.dart';

class ExpertCalendarScreen extends StatelessWidget {
  const ExpertCalendarScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final calendar = context.watch<CalendarController>();
    final auth = context.watch<AuthController>();
    final weekend = isWeekend(calendar.selected);

    return Scaffold(
      appBar: AppBar(
        leading: const DrawerButton(),
        title: Text(calendar.title),
        actions: [
          IconButton(
            tooltip: 'Home',
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(Icons.home_outlined),
          ),
          IconButton(
            tooltip: 'Previous',
            onPressed: () => calendar.shift(-1),
            icon: const Icon(Icons.chevron_left),
          ),
          IconButton(
            tooltip: 'Today',
            onPressed: calendar.goToToday,
            icon: const Icon(Icons.today_outlined),
          ),
          IconButton(
            tooltip: 'Next',
            onPressed: () => calendar.shift(1),
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      ),
      drawer: ExpertSideMenu(
        email: auth.email ?? '',
        onImport: () => importExpertDriveFile(context),
        onExpertPick: () => _openExpertPick(context),
        onReset: () => _resetCalendar(context),
      ),
      floatingActionButton: weekend
          ? null
          : FloatingActionButton(
              onPressed: () => showBuySheet(context, day: calendar.selected),
              child: const Icon(Icons.add),
            ),
      body: Column(
        children: [
          if (calendar.loading) const LinearProgressIndicator(),
          if (calendar.error != null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(calendar.error!),
            ),
          Expanded(child: _calendarBody(context, calendar)),
        ],
      ),
    );
  }

  Widget _calendarBody(BuildContext context, CalendarController calendar) {
    final page = switch (calendar.view) {
      CalendarView.month => MonthView(
        visible: calendar.selected,
        selected: calendar.selected,
        series: calendar.series,
        onDay: (day) => _openDay(context, day),
        onMonth: calendar.select,
      ),
      CalendarView.week => WeekView(
        selected: calendar.selected,
        series: calendar.series,
        onDay: (day) => _openDay(context, day),
      ),
      CalendarView.day => DayView(
        selected: calendar.selected,
        series: calendar.series,
        onOpenBuy: (series) =>
            showBuySheet(context, day: calendar.selected, existing: series),
      ),
      CalendarView.year => YearView(
        year: calendar.selected.year,
        onMonth: (year, month) {
          final today = dateOnly(DateTime.now());
          final day = today.year == year && today.month == month
              ? today
              : DateTime(year, month, 1);
          calendar.select(day, open: CalendarView.month);
        },
        onDay: (day) => calendar.select(day, open: CalendarView.month),
      ),
    };
    if (calendar.view == CalendarView.month) return page;
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onHorizontalDragEnd: (details) {
        final velocity = details.primaryVelocity ?? 0;
        if (velocity > 250) calendar.shift(-1);
        if (velocity < -250) calendar.shift(1);
      },
      child: page,
    );
  }

  Future<void> _openExpertPick(BuildContext context) async {
    final acknowledged = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: const Text(
          'Warning: Without expert import only a sample example will be shown',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('OK'),
          ),
        ],
      ),
    );
    if (acknowledged != true || !context.mounted) return;
    await Navigator.push<void>(
      context,
      MaterialPageRoute(builder: (_) => const ExpertOpinionScreen()),
    );
  }

  Future<void> _resetCalendar(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset Calendar'),
        content: const Text(
          'This will remove all entries, including repeats. Are you sure?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Yes'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    final message = await context.read<CalendarController>().resetCalendar();
    if (!context.mounted || message == null) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset Calendar'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _openDay(BuildContext context, DateTime day) {
    if (isWeekend(day)) return;
    final calendar = context.read<CalendarController>();
    calendar.select(day);
    final buys = buysOn(calendar.series, day);
    if (buys.isEmpty) {
      showBuySheet(context, day: day);
    } else {
      showDayList(context, day: day);
    }
  }
}
