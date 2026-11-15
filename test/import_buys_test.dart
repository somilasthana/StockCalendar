import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:stock_calendar/logic/import_buys.dart';
import 'package:stock_calendar/models/buy_series.dart';

const _now = '2026-01-01T00:00:00.000Z';

BuySeries _existing({
  String id = 'saved',
  String symbol = 'RELIANCE',
  DateTime? anchor,
}) {
  return BuySeries(
    id: id,
    stockName: 'Reliance',
    symbol: symbol,
    notes: '',
    anchorDate: anchor ?? DateTime(2026, 10, 27),
    frequency: RepeatFrequency.none,
    interval: 1,
    endType: RepeatEnd.forever,
    createdAt: DateTime.utc(2026, 1, 1),
  );
}

ImportResult _import(String json, {List<BuySeries> existing = const []}) {
  return parseImportBuys(json, existing: existing, now: DateTime.parse(_now));
}

String _one(
  Map<String, Object?> repeat, {
  String date = '2026-10-27',
  String code = 'RELIANCE',
}) {
  return jsonEncode([
    {
      'stock_name': 'Reliance',
      'stock_code': code,
      'buy_date': date,
      'notes': '  A note  ',
      'Repeat': repeat,
    },
  ]);
}

void main() {
  test("Don't repeat keeps a single weekday buy", () {
    final result = _import(
      _one({"type": "Don't repeat", "duration": "Forever"}),
    );

    expect(result.fileError, isNull);
    expect(result.skipped, isEmpty);
    final buy = result.accepted.single;
    expect(buy.stockName, 'Reliance');
    expect(buy.symbol, 'RELIANCE');
    expect(buy.notes, 'A note');
    expect(buy.anchorDate, DateTime(2026, 10, 27));
    expect(buy.frequency, RepeatFrequency.none);
    expect(buy.endType, RepeatEnd.forever);
    expect(buy.count, isNull);
    expect(buy.untilDate, isNull);
    expect(buy.id, endsWith('_0'));
  });

  test('every week forever, a fixed count, and until a date', () {
    final result = _import('''
[
  {
    "stock_name": "MTAR",
    "stock_code": "mtar",
    "buy_date": "2026-10-28",
    "notes": "weekly",
    "Repeat": {"type": "Every week", "duration": "Forever", "input_value": -1}
  },
  {
    "stock_name": "Coforge",
    "stock_code": "COFORGE",
    "buy_date": "2026-10-30",
    "notes": "counted",
    "Repeat": {"type": "Every week", "duration": "# times total", "input_value": 10}
  },
  {
    "stock_name": "KPIT",
    "stock_code": "KPITTECH",
    "buy_date": "2026-10-30",
    "notes": "until",
    "Repeat": {"type": "Every week", "duration": "Until", "input_value": "2026-11-30"}
  }
]
''');

    expect(result.skipped, isEmpty);
    expect(result.accepted[0].symbol, 'MTAR');
    expect(result.accepted[0].frequency, RepeatFrequency.weeks);
    expect(result.accepted[0].endType, RepeatEnd.forever);
    expect(result.accepted[0].count, isNull);
    expect(result.accepted[1].endType, RepeatEnd.count);
    expect(result.accepted[1].count, 10);
    expect(result.accepted[2].endType, RepeatEnd.until);
    expect(result.accepted[2].untilDate, DateTime(2026, 11, 30));
    expect(result.accepted.map((buy) => buy.id).toSet(), hasLength(3));
  });

  test('every day uses frequency as the interval', () {
    final result = _import('''
[
  {
    "stock_name": "Manorama",
    "stock_code": "MANORAMA",
    "buy_date": "2026-11-02",
    "notes": "",
    "Repeat": {"type": "Every day", "frequency": 3, "duration": "Until", "input_value": "2026-12-25"}
  },
  {
    "stock_name": "Exide",
    "stock_code": "EXIDEIND",
    "buy_date": "2026-11-03",
    "notes": "",
    "Repeat": {"type": "Every day", "frequency": 4, "duration": "Forever", "input_value": -1}
  },
  {
    "stock_name": "Dynacons",
    "stock_code": "DSSL",
    "buy_date": "2026-11-04",
    "notes": "",
    "Repeat": {"type": "Every day", "frequency": 5, "duration": "# times total", "input_value": 5}
  }
]
''');

    expect(result.skipped, isEmpty);
    expect(result.accepted[0].frequency, RepeatFrequency.days);
    expect(result.accepted[0].interval, 3);
    expect(result.accepted[0].untilDate, DateTime(2026, 12, 25));
    expect(result.accepted[1].interval, 4);
    expect(result.accepted[1].endType, RepeatEnd.forever);
    expect(result.accepted[2].interval, 5);
    expect(result.accepted[2].count, 5);
  });

  test('every month and every year keep a count', () {
    final result = _import('''
[
  {
    "stock_name": "Esconet",
    "stock_code": "ESCONET",
    "buy_date": "2026-11-05",
    "notes": "",
    "Repeat": {"type": "Every year", "duration": "# times total", "input_value": 5}
  },
  {
    "stock_name": "JK Tyre",
    "stock_code": "JKTYRE",
    "buy_date": "2026-11-06",
    "notes": "",
    "Repeat": {"type": "Every month", "duration": "# times total", "input_value": 15}
  }
]
''');

    expect(result.skipped, isEmpty);
    expect(result.accepted[0].frequency, RepeatFrequency.years);
    expect(result.accepted[0].count, 5);
    expect(result.accepted[1].frequency, RepeatFrequency.months);
    expect(result.accepted[1].count, 15);
    expect(result.accepted[1].interval, 1);
  });

  test('a weekend row is skipped and the valid row is kept', () {
    final result = _import('''
[
  {
    "stock_name": "Friday",
    "stock_code": "FRI",
    "buy_date": "2026-10-30",
    "notes": "",
    "Repeat": {"type": "Don't repeat"}
  },
  {
    "stock_name": "Saturday",
    "stock_code": "SAT",
    "buy_date": "2026-10-31",
    "notes": "",
    "Repeat": {"type": "Don't repeat"}
  }
]
''');

    expect(result.accepted.single.symbol, 'FRI');
    expect(result.skipped.single.row, 2);
    expect(result.skipped.single.label, 'Saturday');
    expect(
      result.skipped.single.message,
      'The market is closed on Saturday and Sunday.',
    );
    expect(describeImport(result), contains('Imported 1 buy.'));
    expect(describeImport(result), contains('1 was skipped.'));
    expect(
      describeImport(result),
      contains('2. Saturday: The market is closed'),
    );
  });

  test('a symbol already on that day is skipped and earlier buys stay', () {
    final existing = [_existing()];
    final result = _import('''
[
  {
    "stock_name": "Reliance again",
    "stock_code": "reliance",
    "buy_date": "2026-10-27",
    "notes": "",
    "Repeat": {"type": "Don't repeat"}
  },
  {
    "stock_name": "Pine Labs",
    "stock_code": "PINELABS",
    "buy_date": "2026-10-29",
    "notes": "",
    "Repeat": {"type": "Every week", "duration": "Forever", "input_value": -1}
  }
]
''', existing: existing);

    expect(existing, hasLength(1));
    expect(existing.single.id, 'saved');
    expect(result.accepted.single.symbol, 'PINELABS');
    expect(result.skipped.single.message, 'RELIANCE is already on this day.');
  });

  test('the same symbol twice in one file keeps the first row', () {
    final result = _import('''
[
  {
    "stock_name": "First",
    "stock_code": "ITC",
    "buy_date": "2026-10-27",
    "notes": "",
    "Repeat": {"type": "Don't repeat"}
  },
  {
    "stock_name": "Second",
    "stock_code": "ITC",
    "buy_date": "2026-10-27",
    "notes": "",
    "Repeat": {"type": "Don't repeat"}
  }
]
''');

    expect(result.accepted.single.stockName, 'First');
    expect(result.skipped.single.message, 'ITC is already on this day.');
  });

  test('a broken file saves nothing', () {
    final broken = _import('{');
    expect(broken.fileError, 'This file could not be read.');
    expect(broken.accepted, isEmpty);
    expect(describeImport(broken), 'This file could not be read.');

    final object = _import('{"stock_name": "Reliance"}');
    expect(object.fileError, 'This file is not a list of buys.');

    final empty = _import('[]');
    expect(empty.fileError, 'This file has no buys.');
  });

  test('bad repeat choices name the problem', () {
    ImportSkip skip(String repeat) {
      final result = _import('''
[
  {
    "stock_name": "Bad",
    "stock_code": "BAD",
    "buy_date": "2026-10-27",
    "notes": "",
    "Repeat": $repeat
  }
]
''');
      return result.skipped.single;
    }

    expect(skip('{"type": "Daily"}').message, 'Choose how this buy repeats.');
    expect(
      skip('{"type": "Every day", "duration": "Forever"}').message,
      'Enter how many days between buys.',
    );
    expect(
      skip('{"type": "Every week", "duration": "# times total"}').message,
      'Enter how many times to repeat.',
    );
    expect(
      skip('{"type": "Every week"}').message,
      'Choose how long this buy repeats.',
    );
    expect(
      skip(
        '{"type": "Every week", "duration": "Until", "input_value": "2026-10-01"}',
      ).message,
      'The last date is before this buy.',
    );
    expect(
      skip(
        '{"type": "Every week", "duration": "Until", "input_value": "2026-27-10"}',
      ).message,
      'Choose the last date.',
    );
  });

  test('assets/input.json imports the weekday buys', () {
    final text = File('assets/input.json').readAsStringSync();
    final result = _import(text);

    expect(result.fileError, isNull);
    expect(result.accepted.map((buy) => buy.symbol), [
      'RELIANCE',
      'MTAR',
      'PINELABS',
      'COFORGE',
      'KPITTECH',
      'MANORAMA',
      'EXIDEIND',
      'DSSL',
      'ESCONET',
      'JKTYRE',
    ]);
    expect(result.accepted[0].frequency, RepeatFrequency.none);
    expect(result.accepted[0].anchorDate, DateTime(2026, 10, 27));
    expect(result.accepted[5].interval, 3);
    expect(result.accepted[5].untilDate, DateTime(2026, 12, 25));
    expect(result.skipped.single.label, 'Natco Pharma Ltd');
    expect(
      result.skipped.single.message,
      'The market is closed on Saturday and Sunday.',
    );
  });
}
