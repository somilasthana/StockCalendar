import 'dart:convert';

import '../models/buy_series.dart';
import 'dates.dart';
import 'recurrence.dart';

/// Shown when the calendar has no buys that can be written out.
const noBuysToExport = 'There are no buys to export.';

/// JSON text in the same shape as `input.json`.
class ExportDocument {
  const ExportDocument({required this.json, required this.count});

  final String json;
  final int count;
}

/// File name offered in the save dialog. [day] is the calendar day of the export.
String exportFileName(DateTime day) => 'output-${formatIsoDate(day)}.json';

/// Sentence for the dialog after the file is saved.
String describeExport(int count) {
  final noun = count == 1 ? 'buy' : 'buys';
  return 'Exported $count $noun.';
}

/// One row per saved buy that still appears on the calendar, ordered by buy
/// date and then stock name.
///
/// A rule that was stopped early, because a later day was edited or deleted,
/// is written as "Until" the last day it still appears. A later rule is its
/// own row. A rule that no longer appears is left out.
///
/// Returns null when there is nothing to export.
ExportDocument? exportBuys(List<BuySeries> series) {
  final visible = series.where(_onCalendar).toList()..sort(_byDateThenName);
  if (visible.isEmpty) return null;
  final rows = [for (final item in visible) _row(item)];
  return ExportDocument(
    json: const JsonEncoder.withIndent('    ').convert(rows),
    count: rows.length,
  );
}

int _byDateThenName(BuySeries a, BuySeries b) {
  final byDate = a.anchorDate.compareTo(b.anchorDate);
  if (byDate != 0) return byDate;
  final byName = a.stockName.toLowerCase().compareTo(b.stockName.toLowerCase());
  if (byName != 0) return byName;
  final bySymbol = a.symbol.compareTo(b.symbol);
  if (bySymbol != 0) return bySymbol;
  return a.id.compareTo(b.id);
}

/// The anchor is the first day of a rule, so the rule is on the calendar
/// exactly when that day itself is still shown.
bool _onCalendar(BuySeries series) {
  if (isWeekend(series.anchorDate)) return false;
  final cut = series.cutBefore;
  if (cut != null && !series.anchorDate.isBefore(dateOnly(cut))) return false;
  switch (series.endType) {
    case RepeatEnd.forever:
      return true;
    case RepeatEnd.count:
      return (series.count ?? 0) >= 1;
    case RepeatEnd.until:
      final until = series.untilDate;
      if (until == null) return false;
      return !series.anchorDate.isAfter(dateOnly(until));
  }
}

Map<String, Object?> _row(BuySeries series) {
  return {
    'stock_name': series.stockName.trim(),
    'stock_code': normalizeSymbol(series.symbol),
    'buy_date': formatIsoDate(series.anchorDate),
    'notes': series.notes.trim(),
    'Repeat': _repeat(series),
  };
}

Map<String, Object?> _repeat(BuySeries series) {
  final type = switch (series.frequency) {
    RepeatFrequency.none => "Don't repeat",
    RepeatFrequency.days => 'Every day',
    RepeatFrequency.weeks => 'Every week',
    RepeatFrequency.months => 'Every month',
    RepeatFrequency.years => 'Every year',
  };
  if (series.frequency == RepeatFrequency.none) {
    return {'type': type};
  }

  final stopped = _lastKeptDay(series);
  final duration = stopped == null ? series.endType : RepeatEnd.until;
  final Object inputValue = switch (duration) {
    RepeatEnd.forever => -1,
    RepeatEnd.count => series.count ?? 1,
    RepeatEnd.until => formatIsoDate(
      stopped ?? series.untilDate ?? series.anchorDate,
    ),
  };

  return {
    'type': type,
    if (series.frequency == RepeatFrequency.days) 'frequency': series.interval,
    'duration': switch (duration) {
      RepeatEnd.forever => 'Forever',
      RepeatEnd.count => '# times total',
      RepeatEnd.until => 'Until',
    },
    'input_value': inputValue,
  };
}

/// Last day still shown when [BuySeries.cutBefore] removes a later day.
/// Null when that cut does not change the days the rule already had.
DateTime? _lastKeptDay(BuySeries series) {
  final cut = series.cutBefore;
  if (cut == null || !_hidesLaterDay(series, cut)) return null;
  final kept = expandSeries(
    series,
    from: series.anchorDate,
    to: addDays(cut, -1),
  );
  if (kept.isEmpty) return null;
  return kept.last;
}

bool _hidesLaterDay(BuySeries series, DateTime cut) {
  if (series.frequency == RepeatFrequency.none) return false;
  final uncut = series.copyWith(cutBefore: null);
  switch (uncut.endType) {
    case RepeatEnd.forever:
      return true;
    case RepeatEnd.count:
      final limit = uncut.count ?? 0;
      if (limit <= 0) return false;
      final before = expandSeries(
        uncut,
        from: uncut.anchorDate,
        to: addDays(cut, -1),
      );
      return before.length < limit;
    case RepeatEnd.until:
      final until = uncut.untilDate;
      if (until == null || dateOnly(until).isBefore(dateOnly(cut))) {
        return false;
      }
      return expandSeries(uncut, from: cut, to: until).isNotEmpty;
  }
}
