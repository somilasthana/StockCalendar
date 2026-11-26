import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/notification_service.dart';
import '../state/calendar_controller.dart';
import 'expert_calendar_screen.dart';
import 'expert_import.dart';
import 'expert_landing_screen.dart';
import 'expert_simulation_store.dart';
import 'memory_series_repository.dart';

/// Expert calendar with its own empty buy list.
class ExpertCalendarScope extends StatefulWidget {
  const ExpertCalendarScope({super.key, this.simulations});

  /// Saved buys for this calendar. Tests pass a store. The phone file is used
  /// when this is omitted.
  final ExpertSimulationStore? simulations;

  @override
  State<ExpertCalendarScope> createState() => _ExpertCalendarScopeState();
}

class _ExpertCalendarScopeState extends State<ExpertCalendarScope> {
  CalendarController? _calendar;
  final _imports = ExpertImportStore();

  @override
  void initState() {
    super.initState();
    _open();
  }

  Future<void> _open() async {
    final prefs = await SharedPreferences.getInstance();
    final calendar = CalendarController(prefs, NotificationService());
    final repo = MemorySeriesRepository();
    await calendar.bindIsolated(repo);
    await Future<void>.delayed(Duration.zero);
    if (!mounted) {
      calendar.dispose();
      return;
    }
    setState(() => _calendar = calendar);
    final store = widget.simulations ?? ExpertSimulationStore();
    final saved = await store.read();
    final run = await store.readRun();
    final imported = await _imports.read();
    final choice = prefs.getString(expertPickChoiceKey);
    if (!mounted) return;
    if (saved.isNotEmpty) {
      if (run != null) _calendar!.setExpertRun(run);
      await repo.replaceAll(saved);
    } else {
      _calendar!.expertRun = null;
    }
    if (!mounted) return;
    final chosen = choice != null || imported.isNotEmpty || saved.isNotEmpty;
    if (!chosen) {
      await offerFirstExpertScrip(
        context,
        imports: _imports,
        calendar: _calendar!,
      );
      return;
    }
    final useImported =
        imported.isNotEmpty && choice != expertPickChoiceDefault;
    openExpertOpinion(
      context,
      scrips: useImported ? imported : const [],
      calendar: _calendar!,
    );
  }

  @override
  void dispose() {
    _calendar?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final calendar = _calendar;
    if (calendar == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return ChangeNotifierProvider<CalendarController>.value(
      value: calendar,
      child: ExpertLandingScreen(imports: _imports),
    );
  }
}
