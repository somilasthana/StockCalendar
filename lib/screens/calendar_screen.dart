import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../logic/dates.dart';
import '../logic/export_buys.dart';
import '../logic/import_buys.dart';
import '../logic/recurrence.dart';
import '../services/save_export.dart';
import '../state/auth_controller.dart';
import '../state/calendar_controller.dart';
import '../widgets/buy_sheet.dart';
import '../widgets/day_list_sheet.dart';
import '../widgets/day_view.dart';
import '../widgets/month_view.dart';
import '../widgets/side_menu.dart';
import '../widgets/week_view.dart';
import '../widgets/year_view.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen>
    with WidgetsBindingObserver {
  String? _boundUid;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final auth = context.read<AuthController>();
    if (auth.uid == _boundUid) return;
    _boundUid = auth.uid;
    final uid = auth.uid;
    final firebase = auth.firebaseActive;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<CalendarController>().bind(uid: uid, firebase: firebase);
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      context.read<CalendarController>().refreshAlerts();
    }
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

  Future<void> _importBuys() async {
    final picked = await FilePicker.pickFile(
      dialogTitle: 'Import buys',
      type: FileType.custom,
      allowedExtensions: const ['json'],
    );
    if (!mounted || picked == null) return;

    final String text;
    try {
      text = utf8.decode(await picked.readAsBytes());
    } catch (_) {
      if (!mounted) return;
      await _showNotice('Import', 'This file could not be read.');
      return;
    }
    if (!mounted) return;

    final calendar = context.read<CalendarController>();
    final result = parseImportBuys(text, existing: calendar.series);
    if (result.fileError == null && result.accepted.isNotEmpty) {
      final saveError = await calendar.saveImported(result.accepted);
      if (!mounted) return;
      if (saveError != null) {
        await _showNotice('Import', saveError);
        return;
      }
    }
    if (!mounted) return;
    await _showNotice('Import', describeImport(result));
  }

  Future<void> _exportBuys() async {
    final document = exportBuys(context.read<CalendarController>().series);
    if (document == null) {
      await _showNotice('Export', noBuysToExport);
      return;
    }

    final Uri? saved;
    try {
      saved = await saveExportFile(
        fileName: exportFileName(DateTime.now()),
        bytes: utf8.encode(document.json),
      );
    } catch (_) {
      if (!mounted) return;
      await _showNotice('Export', 'This file could not be saved.');
      return;
    }
    if (!mounted || saved == null) return;
    await _showNotice('Export', describeExport(document.count));
  }

  Future<void> _resetCalendar() async {
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
    if (confirmed != true || !mounted) return;
    final message = await context.read<CalendarController>().resetCalendar();
    if (!mounted || message == null) return;
    await _showNotice('Reset Calendar', message);
  }

  Future<void> _showNotice(String title, String message) {
    return showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(child: Text(message)),
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
      drawer: SideMenu(
        email: auth.email ?? '',
        onImport: _importBuys,
        onExport: _exportBuys,
        onReset: _resetCalendar,
      ),
      floatingActionButton: weekend
          ? null
          : FloatingActionButton(
              onPressed: () => showBuySheet(context, day: calendar.selected),
              child: const Icon(Icons.add),
            ),
      body: Column(
        children: [
          if (calendar.alertMessage != null)
            MaterialBanner(
              content: Text(calendar.alertMessage!),
              actions: [
                TextButton(
                  onPressed: calendar.dismissAlert,
                  child: const Text('Hide'),
                ),
              ],
            ),
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
}
