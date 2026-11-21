import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/notification_service.dart';
import '../state/calendar_controller.dart';
import 'expert_calendar_screen.dart';
import 'memory_series_repository.dart';

/// Expert calendar with its own empty buy list.
class ExpertCalendarScope extends StatefulWidget {
  const ExpertCalendarScope({super.key});

  @override
  State<ExpertCalendarScope> createState() => _ExpertCalendarScopeState();
}

class _ExpertCalendarScopeState extends State<ExpertCalendarScope> {
  CalendarController? _calendar;

  @override
  void initState() {
    super.initState();
    _open();
  }

  Future<void> _open() async {
    final prefs = await SharedPreferences.getInstance();
    final calendar = CalendarController(prefs, NotificationService());
    await calendar.bindIsolated(MemorySeriesRepository());
    if (!mounted) {
      calendar.dispose();
      return;
    }
    setState(() => _calendar = calendar);
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
      child: const ExpertCalendarScreen(),
    );
  }
}
