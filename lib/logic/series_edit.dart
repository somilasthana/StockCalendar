import '../models/buy_series.dart';
import 'dates.dart';
import 'recurrence.dart';

/// What to write after an edit or delete.
///
/// [deleteOriginal] removes the whole series. [updated] replaces it.
/// [created] is the new series that starts on the edited day.
class SeriesChange {
  const SeriesChange({this.updated, this.created, this.deleteOriginal = false});

  final BuySeries? updated;
  final BuySeries? created;
  final bool deleteOriginal;
}

SeriesChange deleteFromDate(BuySeries series, DateTime day) {
  final target = dateOnly(day);
  if (!target.isAfter(series.anchorDate)) {
    return const SeriesChange(deleteOriginal: true);
  }
  return SeriesChange(updated: series.copyWith(cutBefore: target));
}

SeriesChange editFromDate({
  required BuySeries series,
  required DateTime day,
  required String stockName,
  required String symbol,
  required String notes,
  required String newId,
}) {
  final target = dateOnly(day);
  final name = stockName.trim();
  final code = normalizeSymbol(symbol);
  if (!target.isAfter(series.anchorDate)) {
    return SeriesChange(
      updated: series.copyWith(stockName: name, symbol: code, notes: notes.trim()),
    );
  }

  final alreadyPlaced = expandSeries(
    series,
    from: series.anchorDate,
    to: addDays(target, -1),
  ).length;
  final remaining = series.endType == RepeatEnd.count
      ? (series.count ?? 1) - alreadyPlaced
      : series.count;

  final created = BuySeries(
    id: newId,
    stockName: name,
    symbol: code,
    notes: notes.trim(),
    anchorDate: target,
    frequency: series.frequency,
    interval: series.interval,
    endType: series.endType,
    count: remaining,
    untilDate: series.untilDate,
    createdAt: series.createdAt,
  );
  return SeriesChange(
    updated: series.copyWith(cutBefore: target),
    created: created,
  );
}

String? validateBuy({
  required String stockName,
  required String symbol,
  required DateTime anchor,
  required RepeatFrequency frequency,
  required int interval,
  required RepeatEnd endType,
  required int count,
  required DateTime? untilDate,
  required List<BuySeries> existing,
  String? ignoreSeriesId,
}) {
  if (stockName.trim().isEmpty) return 'Enter the stock to buy.';
  final code = normalizeSymbol(symbol);
  if (code.isEmpty) return 'Enter the stock symbol.';
  if (isWeekend(anchor)) return 'The market is closed on Saturday and Sunday.';
  if (frequency == RepeatFrequency.days && interval < 1) {
    return 'Enter how many days between buys.';
  }
  if (frequency != RepeatFrequency.none && endType == RepeatEnd.count && count < 1) {
    return 'Enter how many times to repeat.';
  }
  if (frequency != RepeatFrequency.none && endType == RepeatEnd.until) {
    if (untilDate == null) return 'Choose the last date.';
    if (isWeekend(untilDate)) return 'Choose a weekday.';
    if (dateOnly(untilDate).isBefore(dateOnly(anchor))) {
      return 'The last date is before this buy.';
    }
  }
  if (symbolTakenOn(existing, anchor, code, ignoreSeriesId: ignoreSeriesId)) {
    return '$code is already on this day.';
  }
  return null;
}
