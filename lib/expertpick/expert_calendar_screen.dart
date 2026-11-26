import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../logic/dates.dart';
import '../logic/recurrence.dart';
import '../screens/dashboard_screen.dart';
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
import 'expert_scrip.dart';
import 'expert_side_menu.dart';
import 'expert_simulation_store.dart';

const expertPickChoiceKey = 'expert_pick_choice';
const expertPickChoiceDefault = 'default';
const expertPickChoiceImported = 'imported';

const nothingToShowOnCalendar =
    'Nothing to show - choose a scrip from menu to add';

Future<void> rememberExpertPickChoice(String choice) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(expertPickChoiceKey, choice);
}

enum _FirstScripChoice { import, sample }

/// Shown when no expert scrip has been chosen yet.
///
/// Default opens the sample with the dropdown off. Import opens Google Drive
/// and then Expert Opinion. Leaving the dialog returns to the previous screen.
Future<void> offerFirstExpertScrip(
  BuildContext context, {
  required ExpertImportStore imports,
  required CalendarController calendar,
}) async {
  while (true) {
    if (!context.mounted) return;
    final choice = await showDialog<_FirstScripChoice>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('No Expert Scrip Added to Calendar'),
        content: const Text(
          'Do you want to import a scrip from gdrive or use default one?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, _FirstScripChoice.import),
            child: const Text('Import'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, _FirstScripChoice.sample),
            child: const Text('Default'),
          ),
        ],
      ),
    );
    if (!context.mounted) return;
    if (choice == null) {
      Navigator.of(context).maybePop();
      return;
    }
    if (choice == _FirstScripChoice.sample) {
      await rememberExpertPickChoice(expertPickChoiceDefault);
      if (!context.mounted) return;
      openExpertOpinion(context, scrips: const [], calendar: calendar);
      return;
    }
    final picked = await pickExpertDriveFile(context, store: imports);
    if (!context.mounted) return;
    if (picked.cancelled) continue;
    final error = picked.error;
    if (error != null) {
      await showExpertNotice(context, error);
      continue;
    }
    await rememberExpertPickChoice(expertPickChoiceImported);
    if (!context.mounted) return;
    final scrips = await imports.read();
    if (!context.mounted) return;
    openExpertOpinion(context, scrips: scrips, calendar: calendar);
    return;
  }
}

/// Google Drive, then Expert Opinion with the file that was just saved.
Future<void> refreshExpertScrip(
  BuildContext context, {
  required ExpertImportStore imports,
  required CalendarController calendar,
}) async {
  final saved = await importExpertDriveFile(context, store: imports);
  if (!saved || !context.mounted) return;
  await rememberExpertPickChoice(expertPickChoiceImported);
  if (!context.mounted) return;
  final scrips = await imports.read();
  if (!context.mounted) return;
  openExpertOpinion(context, scrips: scrips, calendar: calendar);
}

/// Expert Opinion for the last choice. An import wins unless Default was chosen.
Future<void> reopenExpertOpinion(
  BuildContext context, {
  required ExpertImportStore imports,
  required CalendarController calendar,
}) async {
  final prefs = await SharedPreferences.getInstance();
  final choice = prefs.getString(expertPickChoiceKey);
  final imported = await imports.read();
  if (!context.mounted) return;
  final useImported = imported.isNotEmpty && choice != expertPickChoiceDefault;
  openExpertOpinion(
    context,
    scrips: useImported ? imported : const [],
    calendar: calendar,
  );
}

/// The calendar when it has buys. An empty calendar stays off this screen.
Future<void> presentExpertCalendar(
  BuildContext context, {
  required ExpertImportStore imports,
  required bool fromCalendar,
}) async {
  final calendar = context.read<CalendarController>();
  if (calendar.series.isEmpty) {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        content: const Text(nothingToShowOnCalendar),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
    if (!fromCalendar || !context.mounted) return;
    final navigator = Navigator.of(context);
    if (navigator.canPop()) navigator.pop();
    return;
  }
  if (fromCalendar) return;
  final store = imports;
  await Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => ChangeNotifierProvider<CalendarController>.value(
        value: calendar,
        child: ExpertCalendarScreen(imports: store),
      ),
    ),
  );
}

void showOnTheWay(BuildContext context) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(const SnackBar(content: Text('On the way.')));
}

/// Expert Opinion. A saved run returns here, then opens the insight screen.
void openExpertOpinion(
  BuildContext context, {
  required List<ExpertScrip> scrips,
  required CalendarController calendar,
  int index = 0,
  List<bool> included = const [],
  String? strategy,
  String? amount,
  bool immediate = false,
  Future<Map<String, Map<String, double>>> Function(
    List<ExpertStock> basket,
    DateTime from,
    DateTime to,
  )?
  prices,
  DateTime Function()? clock,
  ExpertSimulationStore? store,
}) {
  final host = context;
  final screen = ExpertOpinionScreen(
    scrips: scrips,
    onApply: calendar.replaceBuys,
    onRun: calendar.setExpertRun,
    initialIndex: index,
    initialIncluded: included,
    initialStrategy: strategy,
    initialAmount: amount,
    prices: prices,
    clock: clock,
    store: store,
    onCommitted: (commit) {
      unawaited(
        _openPerformance(
          host,
          commit: commit,
          scrips: scrips,
          calendar: calendar,
          prices: prices,
          clock: clock,
          store: store,
        ),
      );
    },
  );
  final route = immediate
      ? PageRouteBuilder<void>(
          transitionDuration: Duration.zero,
          reverseTransitionDuration: Duration.zero,
          pageBuilder: (_, _, _) => screen,
          transitionsBuilder: (_, _, _, child) => child,
        )
      : MaterialPageRoute<void>(builder: (_) => screen);
  Navigator.of(host).push(route);
}

Future<void> _openPerformance(
  BuildContext host, {
  required ExpertOpinionCommit commit,
  required List<ExpertScrip> scrips,
  required CalendarController calendar,
  Future<Map<String, Map<String, double>>> Function(
    List<ExpertStock> basket,
    DateTime from,
    DateTime to,
  )?
  prices,
  DateTime Function()? clock,
  ExpertSimulationStore? store,
}) async {
  final navigator = Navigator.of(host);
  if (navigator.canPop()) navigator.pop();
  if (!host.mounted) return;
  await showDialog<void>(
    context: host,
    builder: (context) => AlertDialog(
      content: Text(commit.summary),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('OK'),
        ),
      ],
    ),
  );
  if (!host.mounted) return;
  openExpertOpinion(
    host,
    scrips: scrips,
    calendar: calendar,
    index: commit.index,
    included: commit.included,
    strategy: commit.strategy,
    amount: commit.amount,
    immediate: true,
    prices: prices,
    clock: clock,
    store: store,
  );
  await Navigator.of(host).push(
    MaterialPageRoute<void>(
      builder: (_) => ChangeNotifierProvider<CalendarController>.value(
        value: calendar,
        child: const DashboardScreen(expert: true),
      ),
    ),
  );
}

/// Removes every expert buy. The menu keeps this wired and does not show it.
Future<void> resetExpertCalendar(BuildContext context) async {
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
  if (!context.mounted) return;
  final shown = message ?? await ExpertSimulationStore().delete();
  if (!context.mounted || shown == null) return;
  await showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Reset Calendar'),
      content: Text(shown),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('OK'),
        ),
      ],
    ),
  );
}

class ExpertCalendarScreen extends StatelessWidget {
  const ExpertCalendarScreen({super.key, required this.imports});

  final ExpertImportStore imports;

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
        calendarViews: true,
        onImport: () => refreshExpertScrip(
          context,
          imports: imports,
          calendar: context.read<CalendarController>(),
        ),
        onExpertPick: () => reopenExpertOpinion(
          context,
          imports: imports,
          calendar: context.read<CalendarController>(),
        ),
        onShowCalendar: () => presentExpertCalendar(
          context,
          imports: imports,
          fromCalendar: true,
        ),
        onPersonal: () => showOnTheWay(context),
        onReset: () => resetExpertCalendar(context),
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
