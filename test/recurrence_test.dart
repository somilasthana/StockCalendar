import 'package:flutter_test/flutter_test.dart';
import 'package:stock_calendar/logic/dates.dart';
import 'package:stock_calendar/logic/notification_plan.dart';
import 'package:stock_calendar/logic/recurrence.dart';
import 'package:stock_calendar/logic/series_edit.dart';
import 'package:stock_calendar/models/buy_series.dart';

BuySeries series({
  String id = 'a',
  String stockName = 'ITC',
  String symbol = 'ITC',
  required DateTime anchor,
  RepeatFrequency frequency = RepeatFrequency.days,
  int interval = 1,
  RepeatEnd endType = RepeatEnd.count,
  int? count = 10,
  DateTime? until,
  DateTime? cutBefore,
  DateTime? createdAt,
}) {
  return BuySeries(
    id: id,
    stockName: stockName,
    symbol: symbol,
    notes: '',
    anchorDate: anchor,
    frequency: frequency,
    interval: interval,
    endType: endType,
    count: count,
    untilDate: until,
    cutBefore: cutBefore,
    createdAt: createdAt ?? DateTime.utc(2026, 9, 1),
  );
}

void main() {
  final start = DateTime(2026, 9, 23);

  test('23 Sep 2026 is a Wednesday', () {
    expect(start.weekday, DateTime.wednesday);
  });

  test('every 1 weekday, 10 times, includes Friday 2 Oct', () {
    final dates = expandSeries(
      series(anchor: start, interval: 1, count: 10),
      from: start,
      to: DateTime(2026, 12, 31),
    );
    expect(dates, [
      DateTime(2026, 9, 23),
      DateTime(2026, 9, 24),
      DateTime(2026, 9, 25),
      DateTime(2026, 9, 28),
      DateTime(2026, 9, 29),
      DateTime(2026, 9, 30),
      DateTime(2026, 10, 1),
      DateTime(2026, 10, 2),
      DateTime(2026, 10, 5),
      DateTime(2026, 10, 6),
    ]);
  });

  test('every 3 weekdays, 4 times', () {
    final dates = expandSeries(
      series(anchor: start, interval: 3, count: 4),
      from: start,
      to: DateTime(2026, 12, 31),
    );
    expect(dates, [
      DateTime(2026, 9, 23),
      DateTime(2026, 9, 28),
      DateTime(2026, 10, 1),
      DateTime(2026, 10, 6),
    ]);
  });

  test('monthly skips a weekend date and does not count it', () {
    final dates = expandSeries(
      series(anchor: start, frequency: RepeatFrequency.months, count: 5),
      from: start,
      to: DateTime(2027, 12, 31),
    );
    expect(dates, [
      DateTime(2026, 9, 23),
      DateTime(2026, 10, 23),
      DateTime(2026, 11, 23),
      DateTime(2026, 12, 23),
      DateTime(2027, 2, 23),
    ]);
    expect(dates.contains(DateTime(2027, 1, 23)), isFalse);
    expect(DateTime(2027, 1, 23).weekday, DateTime.saturday);
  });

  test('a 31st uses the last weekday when the month is shorter', () {
    expect(lastWeekdayOfMonth(2026, 2), DateTime(2026, 2, 27));
    expect(DateTime(2026, 2, 28).weekday, DateTime.saturday);

    final dates = expandSeries(
      series(
        anchor: DateTime(2026, 3, 31),
        frequency: RepeatFrequency.months,
        count: 2,
      ),
      from: DateTime(2026, 3, 1),
      to: DateTime(2026, 5, 1),
    );
    expect(dates, [DateTime(2026, 3, 31), DateTime(2026, 4, 30)]);
  });

  test('yearly skips weekend anniversaries without counting them', () {
    final dates = expandSeries(
      series(anchor: start, frequency: RepeatFrequency.years, count: 3),
      from: start,
      to: DateTime(2031, 1, 1),
    );
    expect(dates, [
      DateTime(2026, 9, 23),
      DateTime(2027, 9, 23),
      DateTime(2030, 9, 23),
    ]);
  });

  test('until date is inclusive', () {
    final dates = expandSeries(
      series(
        anchor: start,
        endType: RepeatEnd.until,
        count: null,
        until: DateTime(2026, 10, 2),
      ),
      from: start,
      to: DateTime(2026, 10, 31),
    );
    expect(dates.last, DateTime(2026, 10, 2));
    expect(dates.length, 8);
  });

  test('cutBefore drops that day and every later day', () {
    final dates = expandSeries(
      series(
        anchor: start,
        endType: RepeatEnd.forever,
        count: null,
        cutBefore: DateTime(2026, 10, 1),
      ),
      from: start,
      to: DateTime(2026, 10, 6),
    );
    expect(dates, [
      DateTime(2026, 9, 23),
      DateTime(2026, 9, 24),
      DateTime(2026, 9, 25),
      DateTime(2026, 9, 28),
      DateTime(2026, 9, 29),
      DateTime(2026, 9, 30),
    ]);
  });

  test('weekly repeat stays on the same weekday', () {
    final dates = expandSeries(
      series(anchor: start, frequency: RepeatFrequency.weeks, count: 3),
      from: start,
      to: DateTime(2026, 10, 31),
    );
    expect(dates, [
      DateTime(2026, 9, 23),
      DateTime(2026, 9, 30),
      DateTime(2026, 10, 7),
    ]);
  });

  test('edit from a middle day keeps earlier days and the remaining count', () {
    final original = series(anchor: start, interval: 1, count: 10);
    final change = editFromDate(
      series: original,
      day: DateTime(2026, 9, 28),
      stockName: 'ITC Hotels',
      symbol: 'itc',
      notes: 'limit',
      newId: 'b',
    );

    final earlier = expandSeries(
      change.updated!,
      from: start,
      to: DateTime(2026, 10, 31),
    );
    final later = expandSeries(
      change.created!,
      from: start,
      to: DateTime(2026, 10, 31),
    );

    expect(earlier, [
      DateTime(2026, 9, 23),
      DateTime(2026, 9, 24),
      DateTime(2026, 9, 25),
    ]);
    expect(later.first, DateTime(2026, 9, 28));
    expect(later.length, 7);
    expect(change.created!.symbol, 'ITC');
    expect(change.created!.stockName, 'ITC Hotels');
    expect(later.last, DateTime(2026, 10, 6));
  });

  test('delete from the first day removes the series', () {
    final change = deleteFromDate(series(anchor: start), start);
    expect(change.deleteOriginal, isTrue);
  });

  test('the same symbol is shown once on a day', () {
    final first = series(
      id: '1',
      anchor: start,
      frequency: RepeatFrequency.none,
      endType: RepeatEnd.forever,
      count: null,
    );
    final second = series(
      id: '2',
      anchor: start,
      frequency: RepeatFrequency.none,
      endType: RepeatEnd.forever,
      count: null,
      stockName: 'ITC again',
      createdAt: DateTime.utc(2026, 9, 2),
    );
    final other = series(
      id: '3',
      anchor: start,
      frequency: RepeatFrequency.none,
      endType: RepeatEnd.forever,
      count: null,
      stockName: 'Reliance',
      symbol: 'RELIANCE',
      createdAt: DateTime.utc(2026, 9, 3),
    );

    final buys = buysOn([second, other, first], start);
    expect(buys.map((buy) => buy.series.stockName).toList(), ['ITC', 'Reliance']);
  });

  test('10:30 IST is 05:00 UTC and is skipped once that moment has passed', () {
    expect(indiaInstant(start, 10, 30), DateTime.utc(2026, 9, 23, 5, 0));
    expect(indiaInstant(start, 15, 0), DateTime.utc(2026, 9, 23, 9, 30));

    final item = series(
      anchor: start,
      frequency: RepeatFrequency.none,
      endType: RepeatEnd.forever,
      count: null,
    );
    final beforeOpen = planAlerts(
      series: [item],
      nowUtc: DateTime.utc(2026, 9, 23, 4, 0),
      horizonDays: 3,
    );
    expect(beforeOpen.map((alert) => alert.slot).toList(), ['open', 'close']);

    final afterOpen = planAlerts(
      series: [item],
      nowUtc: DateTime.utc(2026, 9, 23, 6, 0),
      horizonDays: 3,
    );
    expect(afterOpen.map((alert) => alert.slot).toList(), ['close']);
  });

  test('duplicate symbols produce one pair of alerts', () {
    final first = series(
      id: '1',
      anchor: start,
      frequency: RepeatFrequency.none,
      endType: RepeatEnd.forever,
      count: null,
    );
    final second = series(
      id: '2',
      anchor: start,
      frequency: RepeatFrequency.none,
      endType: RepeatEnd.forever,
      count: null,
      createdAt: DateTime.utc(2026, 9, 2),
    );
    final alerts = planAlerts(
      series: [first, second],
      nowUtc: DateTime.utc(2026, 9, 23, 1, 0),
      horizonDays: 1,
    );
    expect(alerts.length, 2);
    expect(alerts.every((alert) => alert.symbol == 'ITC'), isTrue);
  });
}
