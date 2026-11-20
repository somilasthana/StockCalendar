import 'package:flutter_test/flutter_test.dart';
import 'package:stock_calendar/logic/ledger.dart';
import 'package:stock_calendar/models/buy_series.dart';

BuySeries buy({
  required String id,
  required String symbol,
  required DateTime anchor,
  String notes = '',
  RepeatFrequency frequency = RepeatFrequency.none,
  int interval = 1,
  RepeatEnd endType = RepeatEnd.forever,
  int? count,
  DateTime? until,
  DateTime? createdAt,
}) {
  return BuySeries(
    id: id,
    stockName: symbol,
    symbol: symbol,
    notes: notes,
    anchorDate: anchor,
    frequency: frequency,
    interval: interval,
    endType: endType,
    count: count,
    untilDate: until,
    createdAt: createdAt ?? DateTime.utc(2026, 1, 1),
  );
}

void main() {
  final today = DateTime(2026, 11, 17);

  test('symbols are unique and alphabetical', () {
    final symbols = ledgerSymbols([
      buy(id: '1', symbol: 'RELIANCE', anchor: DateTime(2026, 11, 4)),
      buy(id: '2', symbol: 'mtar', anchor: DateTime(2026, 11, 5)),
      buy(id: '3', symbol: 'RELIANCE', anchor: DateTime(2026, 11, 6)),
    ]);
    expect(symbols, ['MTAR', 'RELIANCE']);
  });

  test('a repeat shows the notes once, then the same-notes line through today', () {
    final rows = ledgerRows(
      [
        buy(
          id: 'week',
          symbol: 'MANORAMA',
          anchor: DateTime(2026, 11, 4),
          notes: 'Buy 10 shares of Manorama per week',
          frequency: RepeatFrequency.weeks,
        ),
      ],
      'MANORAMA',
      today: today,
    );
    expect(rows.map((row) => row.date), [
      DateTime(2026, 11, 4),
      DateTime(2026, 11, 11),
    ]);
    expect(rows.map((row) => row.text), [
      'Buy 10 shares of Manorama per week',
      sameNotesText,
    ]);
    expect(ledgerDateLabel(rows.first.date), 'November 4, 2026');
  });

  test('every later day of a longer repeat keeps the same-notes line', () {
    final rows = ledgerRows(
      [
        buy(
          id: 'days',
          symbol: 'EXIDEIND',
          anchor: DateTime(2026, 11, 12),
          notes: 'Buy 10 shares',
          frequency: RepeatFrequency.days,
          interval: 1,
        ),
      ],
      'EXIDEIND',
      today: today,
    );
    expect(rows.map((row) => row.date), [
      DateTime(2026, 11, 12),
      DateTime(2026, 11, 13),
      DateTime(2026, 11, 16),
      DateTime(2026, 11, 17),
    ]);
    expect(rows.map((row) => row.text).toList(), [
      'Buy 10 shares',
      sameNotesText,
      sameNotesText,
      sameNotesText,
    ]);
  });

  test('a different note in between brings the full text back', () {
    final rows = ledgerRows(
      [
        buy(
          id: 'repeat',
          symbol: 'KPITTECH',
          anchor: DateTime(2026, 11, 4),
          notes: 'Alpha',
          frequency: RepeatFrequency.weeks,
          createdAt: DateTime.utc(2026, 11, 1),
        ),
        buy(
          id: 'once',
          symbol: 'KPITTECH',
          anchor: DateTime(2026, 11, 6),
          notes: 'Beta',
          createdAt: DateTime.utc(2026, 11, 2),
        ),
      ],
      'KPITTECH',
      today: today,
    );
    expect(rows.map((row) => row.text).toList(), [
      'Alpha',
      'Beta',
      'Alpha',
    ]);
  });

  test('an empty repeat names the gap once, then points at the line above', () {
    final rows = ledgerRows(
      [
        buy(
          id: 'empty-repeat',
          symbol: 'DSSL',
          anchor: DateTime(2026, 11, 16),
          frequency: RepeatFrequency.days,
        ),
      ],
      'DSSL',
      today: today,
    );
    expect(rows.map((row) => row.text).toList(), [noNotesText, sameNotesText]);
  });

  test('one-time buys with no notes each say notes are unavailable', () {
    final rows = ledgerRows(
      [
        buy(
          id: 'a',
          symbol: 'RELIANCE',
          anchor: DateTime(2026, 11, 4),
          createdAt: DateTime.utc(2026, 11, 1),
        ),
        buy(
          id: 'b',
          symbol: 'RELIANCE',
          anchor: DateTime(2026, 11, 5),
          createdAt: DateTime.utc(2026, 11, 2),
        ),
      ],
      'RELIANCE',
      today: today,
    );
    expect(rows.map((row) => row.text).toList(), [noNotesText, noNotesText]);
  });

  test('two buys on the same day stay two rows, earlier buy first', () {
    final rows = ledgerRows(
      [
        buy(
          id: 'later',
          symbol: 'NATCOPHARM',
          anchor: DateTime(2026, 11, 4),
          notes: 'Second lot',
          createdAt: DateTime.utc(2026, 11, 3),
        ),
        buy(
          id: 'earlier',
          symbol: 'NATCOPHARM',
          anchor: DateTime(2026, 11, 4),
          notes: 'First lot',
          createdAt: DateTime.utc(2026, 11, 1),
        ),
      ],
      'NATCOPHARM',
      today: today,
    );
    expect(rows.map((row) => row.text).toList(), ['First lot', 'Second lot']);
    expect(rows.map((row) => row.date).toList(), [
      DateTime(2026, 11, 4),
      DateTime(2026, 11, 4),
    ]);
  });

  test('days after today are left off the list', () {
    final rows = ledgerRows(
      [
        buy(
          id: 'future',
          symbol: 'ESCONET',
          anchor: DateTime(2026, 11, 18),
          notes: 'Next week',
        ),
      ],
      'ESCONET',
      today: today,
    );
    expect(rows, isEmpty);
  });
}
