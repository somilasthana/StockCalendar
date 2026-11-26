import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/firestore_series_repository.dart';
import '../data/local_series_repository.dart';
import '../data/series_repository.dart';
import '../logic/dates.dart';
import '../logic/series_edit.dart';
import '../models/buy_series.dart';
import '../models/expert_run.dart';
import '../services/notification_service.dart';

enum CalendarView { year, month, week, day }

class CalendarController extends ChangeNotifier {
  CalendarController(this._prefs, this._notifications);

  final SharedPreferences _prefs;
  final NotificationService _notifications;

  SeriesRepository? _repo;
  StreamSubscription<List<BuySeries>>? _sub;
  bool _isolated = false;

  /// Expert calendar buys come from a scrip. They are not typed in by hand.
  bool get manualBuysLocked => _isolated;

  CalendarView view = CalendarView.month;
  DateTime selected = dateOnly(DateTime.now());
  List<BuySeries> series = [];

  /// Scrip name, strategy, and amount last applied on the expert calendar.
  ExpertRun? expertRun;
  bool loading = false;
  String? error;
  String? alertMessage;

  void show(CalendarView next) {
    view = next;
    notifyListeners();
  }

  void goToToday() {
    selected = dateOnly(DateTime.now());
    notifyListeners();
  }

  void select(DateTime day, {CalendarView? open}) {
    selected = dateOnly(day);
    if (open != null) view = open;
    notifyListeners();
  }

  void shift(int direction) {
    switch (view) {
      case CalendarView.month:
        final month = DateTime(selected.year, selected.month + direction, 1);
        selected = clampDate(month.year, month.month, selected.day);
      case CalendarView.week:
        selected = addDays(selected, 7 * direction);
      case CalendarView.day:
        selected = addDays(selected, direction);
      case CalendarView.year:
        selected = clampDate(
          selected.year + direction,
          selected.month,
          selected.day,
        );
    }
    notifyListeners();
  }

  String get title {
    return switch (view) {
      CalendarView.year => '${selected.year}',
      CalendarView.week => weekTitle(selected),
      CalendarView.month || CalendarView.day => monthTitle(selected),
    };
  }

  Future<void> bind({required String? uid, required bool firebase}) async {
    await _sub?.cancel();
    _sub = null;
    _repo = null;
    if (uid == null) {
      series = [];
      loading = false;
      error = null;
      notifyListeners();
      await _notifications.cancelAll();
      return;
    }

    _repo = firebase
        ? FirestoreSeriesRepository(uid)
        : LocalSeriesRepository(_prefs, uid);
    loading = true;
    error = null;
    notifyListeners();
    _sub = _repo!.watch().listen(
      (items) async {
        series = items;
        loading = false;
        error = null;
        notifyListeners();
        alertMessage = await _notifications.reschedule(items);
        notifyListeners();
      },
      onError: (Object _) {
        loading = false;
        error = 'Could not load buys.';
        notifyListeners();
      },
    );
  }

  void dismissAlert() {
    alertMessage = null;
    notifyListeners();
  }

  /// Keeps this calendar off the signed-in buy list and off device alerts.
  Future<void> bindIsolated(SeriesRepository repo) async {
    await _sub?.cancel();
    _isolated = true;
    _repo = repo;
    loading = false;
    error = null;
    series = [];
    notifyListeners();
    _sub = repo.watch().listen(
      (items) {
        series = items;
        loading = false;
        error = null;
        notifyListeners();
      },
      onError: (Object _) {
        loading = false;
        error = 'Could not load buys.';
        notifyListeners();
      },
    );
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> refreshAlerts() async {
    if (_isolated) return;
    alertMessage = await _notifications.reschedule(series);
    notifyListeners();
  }

  Future<void> sendTestAlert() => _notifications.showTestAlert();

  Future<String?> createBuy({
    required String stockName,
    required String symbol,
    required String notes,
    required DateTime day,
    required RepeatFrequency frequency,
    required int interval,
    required RepeatEnd endType,
    required int count,
    required DateTime? untilDate,
  }) async {
    final message = validateBuy(
      stockName: stockName,
      symbol: symbol,
      anchor: day,
      frequency: frequency,
      interval: interval,
      endType: endType,
      count: count,
      untilDate: untilDate,
      existing: series,
    );
    if (message != null) return message;
    final item = BuySeries(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      stockName: stockName.trim(),
      symbol: normalizeSymbol(symbol),
      notes: notes.trim(),
      anchorDate: day,
      frequency: frequency,
      interval: frequency == RepeatFrequency.days ? interval : 1,
      endType: frequency == RepeatFrequency.none ? RepeatEnd.forever : endType,
      count: frequency != RepeatFrequency.none && endType == RepeatEnd.count
          ? count
          : null,
      untilDate: frequency != RepeatFrequency.none && endType == RepeatEnd.until
          ? untilDate
          : null,
      createdAt: DateTime.now().toUtc(),
    );
    try {
      await _repo?.saveNew(item);
    } catch (_) {
      return 'Could not save this buy.';
    }
    return null;
  }

  void setExpertRun(ExpertRun value) {
    expertRun = value;
    notifyListeners();
  }

  /// Removes every buy, including repeats, and clears scheduled alerts.
  Future<String?> resetCalendar() async {
    final repo = _repo;
    if (repo == null) return 'Could not reset the calendar.';
    try {
      expertRun = null;
      await repo.clearAll();
      if (!_isolated) await _notifications.cancelAll();
    } catch (_) {
      return 'Could not reset the calendar.';
    }
    return null;
  }

  /// Replaces every buy. Used by the expert simulation, which owns the calendar.
  Future<String?> replaceBuys(List<BuySeries> items) async {
    final repo = _repo;
    if (repo == null) return 'Could not save these buys.';
    try {
      await repo.replaceAll(items);
    } catch (_) {
      return 'Could not save these buys.';
    }
    return null;
  }

  /// Appends imported buys in one write. Buys already on the phone stay.
  Future<String?> saveImported(List<BuySeries> items) async {
    if (items.isEmpty) return null;
    final repo = _repo;
    if (repo == null) return 'Could not save these buys.';
    try {
      await repo.saveMany(items);
    } catch (_) {
      return 'Could not save these buys.';
    }
    return null;
  }

  Future<String?> updateBuy({
    required BuySeries series,
    required DateTime day,
    required String stockName,
    required String symbol,
    required String notes,
  }) async {
    final message = validateBuy(
      stockName: stockName,
      symbol: symbol,
      anchor: day,
      frequency: series.frequency,
      interval: series.interval,
      endType: series.endType,
      count: series.count ?? 1,
      untilDate: series.untilDate,
      existing: this.series,
      ignoreSeriesId: series.id,
    );
    if (message != null) return message;
    final change = editFromDate(
      series: series,
      day: day,
      stockName: stockName,
      symbol: symbol,
      notes: notes,
      newId: DateTime.now().microsecondsSinceEpoch.toString(),
    );
    try {
      await _repo?.apply(series.id, change);
    } catch (_) {
      return 'Could not save this buy.';
    }
    return null;
  }

  Future<void> deleteBuy(BuySeries series, DateTime day) async {
    final change = deleteFromDate(series, day);
    await _repo?.apply(series.id, change);
  }
}
