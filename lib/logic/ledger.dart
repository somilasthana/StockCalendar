import '../models/buy_series.dart';
import 'dates.dart';
import 'recurrence.dart';

const sameNotesText = 'Same notes as above...';
const noNotesText = 'No notes available...';

class LedgerRow {
  const LedgerRow({required this.date, required this.text});

  final DateTime date;
  final String text;
}

/// Symbols that have at least one saved buy, in alphabetical order.
List<String> ledgerSymbols(List<BuySeries> seriesList) {
  final symbols = <String>{
    for (final series in seriesList)
      if (normalizeSymbol(series.symbol).isNotEmpty) normalizeSymbol(series.symbol),
  };
  return symbols.toList()..sort();
}

String ledgerDateLabel(DateTime date) {
  final day = dateOnly(date);
  return '${monthLong[day.month - 1]} ${day.day}, ${day.year}';
}

/// Buy days for [symbol] on or before [today], oldest first.
///
/// Each saved buy is expanded with the same repeat rules as the calendar,
/// including two buys that land on one day. A later day whose notes match
/// the day above shows [sameNotesText]. A one-time buy with no notes, and
/// the first day of a repeat with no notes, show [noNotesText]. Later days
/// of that empty repeat show [sameNotesText].
List<LedgerRow> ledgerRows(
  List<BuySeries> seriesList,
  String symbol, {
  required DateTime today,
}) {
  final wanted = normalizeSymbol(symbol);
  if (wanted.isEmpty) return const [];
  final end = dateOnly(today);
  final hits = <_Hit>[];
  for (final series in seriesList) {
    if (normalizeSymbol(series.symbol) != wanted) continue;
    for (final date in expandSeries(series, from: series.anchorDate, to: end)) {
      hits.add(_Hit(date, series));
    }
  }
  hits.sort((a, b) {
    final byDate = a.date.compareTo(b.date);
    if (byDate != 0) return byDate;
    final byCreated = a.series.createdAt.compareTo(b.series.createdAt);
    if (byCreated != 0) return byCreated;
    return a.series.id.compareTo(b.series.id);
  });

  final rows = <LedgerRow>[];
  String? previousNotes;
  for (final hit in hits) {
    final notes = hit.series.notes.trim();
    rows.add(
      LedgerRow(
        date: hit.date,
        text: _noteText(
          frequency: hit.series.frequency,
          notes: notes,
          previousNotes: previousNotes,
        ),
      ),
    );
    previousNotes = notes;
  }
  return rows;
}

String _noteText({
  required RepeatFrequency frequency,
  required String notes,
  required String? previousNotes,
}) {
  final same = previousNotes != null && previousNotes == notes;
  final repeats = frequency != RepeatFrequency.none;
  if (notes.isEmpty) {
    if (repeats && same) return sameNotesText;
    return noNotesText;
  }
  if (same) return sameNotesText;
  return notes;
}

class _Hit {
  const _Hit(this.date, this.series);

  final DateTime date;
  final BuySeries series;
}
