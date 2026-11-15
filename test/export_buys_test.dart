import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:stock_calendar/logic/export_buys.dart';
import 'package:stock_calendar/logic/import_buys.dart';
import 'package:stock_calendar/logic/recurrence.dart';
import 'package:stock_calendar/models/buy_series.dart';

BuySeries _buy({
  String id = 'a',
  String stockName = 'Reliance',
  String symbol = 'RELIANCE',
  String notes = 'A note',
  DateTime? anchor,
  RepeatFrequency frequency = RepeatFrequency.none,
  int interval = 1,
  RepeatEnd endType = RepeatEnd.forever,
  int? count,
  DateTime? until,
  DateTime? cutBefore,
}) {
  return BuySeries(
    id: id,
    stockName: stockName,
    symbol: symbol,
    notes: notes,
    anchorDate: anchor ?? DateTime(2026, 10, 27),
    frequency: frequency,
    interval: interval,
    endType: endType,
    count: count,
    untilDate: until,
    cutBefore: cutBefore,
    createdAt: DateTime.utc(2026, 1, 1),
  );
}

List<Map<String, dynamic>> _rows(List<BuySeries> series) {
  final document = exportBuys(series);
  expect(document, isNotNull);
  final decoded = jsonDecode(document!.json);
  return [
    for (final row in decoded as List) Map<String, dynamic>.from(row as Map),
  ];
}

void main() {
  test('an empty calendar exports nothing', () {
    expect(exportBuys(const []), isNull);
    final hidden = _buy(cutBefore: DateTime(2026, 10, 27));
    expect(exportBuys([hidden]), isNull);
  });

  test("Don't repeat writes only the type", () {
    final document = exportBuys([_buy(notes: '  trimmed  ')])!;

    expect(document.count, 1);
    expect(document.json, startsWith('[\n    {'));
    final row = _rows([_buy(notes: '  trimmed  ')]).single;
    expect(row.keys, [
      'stock_name',
      'stock_code',
      'buy_date',
      'notes',
      'Repeat',
    ]);
    expect(row['stock_name'], 'Reliance');
    expect(row['stock_code'], 'RELIANCE');
    expect(row['buy_date'], '2026-10-27');
    expect(row['notes'], 'trimmed');
    final repeat = Map<String, dynamic>.from(row['Repeat'] as Map);
    expect(repeat.keys, ['type']);
    expect(repeat['type'], "Don't repeat");
  });

  test('week, day, count, and until keep the input.json fields', () {
    final rows = _rows([
      _buy(
        id: 'week',
        stockName: 'MTAR Technologies Ltd',
        symbol: 'mtar',
        anchor: DateTime(2026, 10, 28),
        frequency: RepeatFrequency.weeks,
      ),
      _buy(
        id: 'day',
        stockName: 'Manorama Industries Ltd',
        symbol: 'MANORAMA',
        anchor: DateTime(2026, 11, 2),
        frequency: RepeatFrequency.days,
        interval: 3,
        endType: RepeatEnd.until,
        until: DateTime(2026, 12, 25),
      ),
      _buy(
        id: 'count',
        stockName: 'Coforge Ltd',
        symbol: 'COFORGE',
        anchor: DateTime(2026, 10, 30),
        frequency: RepeatFrequency.weeks,
        endType: RepeatEnd.count,
        count: 10,
      ),
    ]);

    final week = Map<String, dynamic>.from(rows[0]['Repeat'] as Map);
    expect(rows[0]['stock_code'], 'MTAR');
    expect(week.keys, ['type', 'duration', 'input_value']);
    expect(week['type'], 'Every week');
    expect(week['duration'], 'Forever');
    expect(week['input_value'], -1);

    final count = Map<String, dynamic>.from(rows[1]['Repeat'] as Map);
    expect(count['duration'], '# times total');
    expect(count['input_value'], 10);

    final day = Map<String, dynamic>.from(rows[2]['Repeat'] as Map);
    expect(day.keys, ['type', 'frequency', 'duration', 'input_value']);
    expect(day['frequency'], 3);
    expect(day['duration'], 'Until');
    expect(day['input_value'], '2026-12-25');
  });

  test('rows are ordered by buy date and then stock name', () {
    final rows = _rows([
      _buy(
        id: 'kpit',
        stockName: 'KPIT Technologies Ltd',
        symbol: 'KPITTECH',
        anchor: DateTime(2026, 10, 30),
      ),
      _buy(
        id: 'later',
        stockName: 'AAA',
        symbol: 'AAA',
        anchor: DateTime(2026, 11, 2),
      ),
      _buy(
        id: 'coforge',
        stockName: 'Coforge Ltd',
        symbol: 'COFORGE',
        anchor: DateTime(2026, 10, 30),
      ),
    ]);

    expect(rows.map((row) => row['stock_code']), [
      'COFORGE',
      'KPITTECH',
      'AAA',
    ]);
  });

  test('a rule stopped early ends on its last remaining day', () {
    final rows = _rows([
      _buy(
        id: 'early',
        stockName: 'MTAR Technologies Ltd',
        symbol: 'MTAR',
        notes: 'original',
        anchor: DateTime(2026, 10, 28),
        frequency: RepeatFrequency.weeks,
        cutBefore: DateTime(2026, 11, 11),
      ),
      _buy(
        id: 'later',
        stockName: 'MTAR Technologies Ltd',
        symbol: 'MTAR',
        notes: 'changed',
        anchor: DateTime(2026, 11, 11),
        frequency: RepeatFrequency.weeks,
      ),
    ]);

    expect(rows[0]['buy_date'], '2026-10-28');
    expect(rows[0]['notes'], 'original');
    final early = Map<String, dynamic>.from(rows[0]['Repeat'] as Map);
    expect(early['type'], 'Every week');
    expect(early['duration'], 'Until');
    expect(early['input_value'], '2026-11-04');

    expect(rows[1]['buy_date'], '2026-11-11');
    expect(rows[1]['notes'], 'changed');
    final later = Map<String, dynamic>.from(rows[1]['Repeat'] as Map);
    expect(later['duration'], 'Forever');
    expect(later['input_value'], -1);
  });

  test('a cut that removes no day keeps the original ending', () {
    final counted = _rows([
      _buy(
        frequency: RepeatFrequency.weeks,
        endType: RepeatEnd.count,
        count: 2,
        cutBefore: DateTime(2027, 1, 1),
      ),
    ]).single;
    final repeat = Map<String, dynamic>.from(counted['Repeat'] as Map);
    expect(repeat['duration'], '# times total');
    expect(repeat['input_value'], 2);

    final until = _rows([
      _buy(
        anchor: DateTime(2026, 10, 28),
        frequency: RepeatFrequency.weeks,
        endType: RepeatEnd.until,
        until: DateTime(2026, 11, 6),
        cutBefore: DateTime(2026, 11, 6),
      ),
    ]).single;
    final untilRepeat = Map<String, dynamic>.from(until['Repeat'] as Map);
    expect(untilRepeat['duration'], 'Until');
    expect(untilRepeat['input_value'], '2026-11-06');
  });

  test('a stopped rule imports back onto the same days', () {
    final original = _buy(
      stockName: 'Dynacons Systems & Solutions Ltd',
      symbol: 'DSSL',
      notes: 'often',
      anchor: DateTime(2026, 11, 4),
      frequency: RepeatFrequency.days,
      interval: 5,
      endType: RepeatEnd.count,
      count: 5,
      cutBefore: DateTime(2026, 11, 18),
    );
    final document = exportBuys([original])!;
    final imported = parseImportBuys(
      document.json,
      existing: const [],
      now: DateTime.utc(2026, 1, 1),
    );

    expect(imported.fileError, isNull);
    expect(imported.skipped, isEmpty);
    final again = imported.accepted.single;
    expect(again.interval, 5);
    expect(again.endType, RepeatEnd.until);
    final from = DateTime(2026, 11, 1);
    final to = DateTime(2026, 12, 31);
    expect(
      expandSeries(again, from: from, to: to),
      expandSeries(original, from: from, to: to),
    );
  });

  test('assets/input.json round-trips the buys it can import', () {
    final text = File('assets/input.json').readAsStringSync();
    final first = parseImportBuys(
      text,
      existing: const [],
      now: DateTime.utc(2026, 1, 1),
    );
    final document = exportBuys(first.accepted)!;
    final second = parseImportBuys(
      document.json,
      existing: const [],
      now: DateTime.utc(2026, 1, 1),
    );

    expect(second.skipped, isEmpty);
    expect(second.accepted.length, first.accepted.length);
    for (var index = 0; index < first.accepted.length; index++) {
      final before = first.accepted[index];
      final after = second.accepted[index];
      expect(after.stockName, before.stockName);
      expect(after.symbol, before.symbol);
      expect(after.notes, before.notes);
      expect(after.anchorDate, before.anchorDate);
      expect(after.frequency, before.frequency);
      expect(after.interval, before.interval);
      expect(after.endType, before.endType);
      expect(after.count, before.count);
      expect(after.untilDate, before.untilDate);
    }
  });

  test('the save dialog name uses the export day', () {
    expect(exportFileName(DateTime(2026, 11, 3)), 'output-2026-11-03.json');
    expect(describeExport(1), 'Exported 1 buy.');
    expect(describeExport(12), 'Exported 12 buys.');
  });
}
