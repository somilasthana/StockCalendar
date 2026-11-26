import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:stock_calendar/expertpick/expert_simulation_store.dart';
import 'package:stock_calendar/logic/dates.dart';
import 'package:stock_calendar/logic/fixed_amount_plan.dart';
import 'package:stock_calendar/models/buy_series.dart';
import 'package:stock_calendar/models/expert_run.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final created = DateTime.utc(2026, 11, 21);

  PlanStock stock(String name, String code) =>
      PlanStock(name: name, code: code);

  Map<String, double> flat(double price, List<String> days) => {
    for (final day in days) day: price,
  };

  test('buys round robin across weekdays and skips the weekend', () {
    final plan = planFixedAmount(
      title: 'Roadmap',
      basket: [
        stock('Stock A', 'AAA'),
        stock('Stock B', 'BBB'),
        stock('Stock C', 'CCC'),
      ],
      amount: 2000,
      published: DateTime(2026, 10, 21),
      today: DateTime(2026, 10, 27),
      closes: {
        'AAA': flat(100, [
          '2026-10-21',
          '2026-10-22',
          '2026-10-23',
          '2026-10-26',
          '2026-10-27',
        ]),
        'BBB': flat(100, [
          '2026-10-21',
          '2026-10-22',
          '2026-10-23',
          '2026-10-26',
          '2026-10-27',
        ]),
        'CCC': flat(100, [
          '2026-10-21',
          '2026-10-22',
          '2026-10-23',
          '2026-10-26',
          '2026-10-27',
        ]),
      },
      createdAt: created,
    );

    expect(plan.status, FixedAmountStatus.ready);
    expect(plan.missingPrice, isEmpty);
    expect(
      plan.buys
          .map((buy) => '${formatIsoDate(buy.anchorDate)} ${buy.symbol}')
          .toList(),
      [
        '2026-10-21 AAA',
        '2026-10-22 BBB',
        '2026-10-23 CCC',
        '2026-10-26 AAA',
        '2026-10-27 BBB',
      ],
    );
    expect(
      plan.buys.first.notes,
      'Based on Expert Scrip Roadmap we bought 20 from the market at the closing price',
    );
    expect(plan.buys.first.numberOfShares, 20);
    expect(plan.buys.first.frequency, RepeatFrequency.none);
    expect(plan.buys.first.stockName, 'Stock A');
  });

  test('a weekend publish date starts on the next weekday', () {
    final plan = planFixedAmount(
      title: 'Roadmap',
      basket: [stock('Stock A', 'AAA'), stock('Stock B', 'BBB')],
      amount: 2000,
      published: DateTime(2026, 10, 24),
      today: DateTime(2026, 10, 27),
      closes: {
        'AAA': flat(100, ['2026-10-26', '2026-10-27']),
        'BBB': flat(100, ['2026-10-26', '2026-10-27']),
      },
      createdAt: created,
    );

    expect(
      plan.buys
          .map((buy) => '${formatIsoDate(buy.anchorDate)} ${buy.symbol}')
          .toList(),
      ['2026-10-26 AAA', '2026-10-27 BBB'],
    );
  });

  test('a day with no closes is a holiday and keeps the turn', () {
    final plan = planFixedAmount(
      title: 'Roadmap',
      basket: [stock('Stock A', 'AAA'), stock('Stock B', 'BBB')],
      amount: 2000,
      published: DateTime(2026, 10, 21),
      today: DateTime(2026, 10, 23),
      closes: {
        'AAA': flat(100, ['2026-10-21', '2026-10-23']),
        'BBB': flat(100, ['2026-10-21', '2026-10-23']),
      },
      createdAt: created,
    );

    expect(
      plan.buys
          .map((buy) => '${formatIsoDate(buy.anchorDate)} ${buy.symbol}')
          .toList(),
      ['2026-10-21 AAA', '2026-10-23 BBB'],
    );
    expect(plan.missingPrice, isEmpty);
  });

  test('a stock above the amount yields to the next stock the same day', () {
    final plan = planFixedAmount(
      title: 'Roadmap',
      basket: [
        stock('Stock A', 'AAA'),
        stock('Stock B', 'BBB'),
        stock('Stock C', 'CCC'),
      ],
      amount: 2000,
      published: DateTime(2026, 10, 21),
      today: DateTime(2026, 10, 23),
      closes: {
        'AAA': {'2026-10-21': 5000, '2026-10-22': 100, '2026-10-23': 100},
        'BBB': flat(100, ['2026-10-21', '2026-10-22', '2026-10-23']),
        'CCC': flat(100, ['2026-10-21', '2026-10-22', '2026-10-23']),
      },
      createdAt: created,
    );

    expect(
      plan.buys
          .map((buy) => '${formatIsoDate(buy.anchorDate)} ${buy.symbol}')
          .toList(),
      ['2026-10-21 BBB', '2026-10-22 CCC', '2026-10-23 AAA'],
    );
    expect(plan.missingPrice, isEmpty);
  });

  test(
    'when every stock is above the amount the same stock is tried next day',
    () {
      final plan = planFixedAmount(
        title: 'Roadmap',
        basket: [stock('Stock A', 'AAA'), stock('Stock B', 'BBB')],
        amount: 2000,
        published: DateTime(2026, 10, 21),
        today: DateTime(2026, 10, 22),
        closes: {
          'AAA': {'2026-10-21': 5000, '2026-10-22': 2000},
          'BBB': {'2026-10-21': 4000, '2026-10-22': 100},
        },
        createdAt: created,
      );

      expect(
        plan.buys
            .map((buy) => '${formatIsoDate(buy.anchorDate)} ${buy.symbol}')
            .toList(),
        ['2026-10-22 AAA'],
      );
      expect(plan.buys.single.notes, contains('we bought 1 from the market'));
    },
  );

  test('a missing close is skipped and the stock stays in the basket', () {
    final plan = planFixedAmount(
      title: 'Roadmap',
      basket: [
        stock('Stock A', 'AAA'),
        stock('Stock B', 'BBB'),
        stock('Stock C', 'CCC'),
      ],
      amount: 2000,
      published: DateTime(2026, 10, 21),
      today: DateTime(2026, 10, 23),
      closes: {
        'AAA': {'2026-10-23': 500},
        'BBB': flat(400, ['2026-10-21', '2026-10-22', '2026-10-23']),
        'CCC': flat(100, ['2026-10-21', '2026-10-22', '2026-10-23']),
      },
      createdAt: created,
    );

    expect(
      plan.buys
          .map((buy) => '${formatIsoDate(buy.anchorDate)} ${buy.symbol}')
          .toList(),
      ['2026-10-21 BBB', '2026-10-22 CCC', '2026-10-23 AAA'],
    );
    expect(plan.buys.last.notes, contains('we bought 4 from the market'));
    expect(plan.buys.last.numberOfShares, 4);
    expect(plan.missingPrice.map((stock) => stock.code), ['AAA']);
    expect(
      describeFixedAmount(plan, 2000),
      contains('AAA (Stock A) had no closing price'),
    );
  });

  test('no prices and a future publish date leave the result unapplied', () {
    final noPrices = planFixedAmount(
      title: 'Roadmap',
      basket: [stock('Stock A', 'AAA')],
      amount: 2000,
      published: DateTime(2026, 10, 21),
      today: DateTime(2026, 10, 21),
      closes: const {},
      createdAt: created,
    );
    expect(noPrices.status, FixedAmountStatus.noPrices);
    expect(noPrices.buys, isEmpty);

    final future = planFixedAmount(
      title: 'Roadmap',
      basket: [stock('Stock A', 'AAA')],
      amount: 2000,
      published: DateTime(2026, 12, 1),
      today: DateTime(2026, 11, 21),
      closes: const {
        'AAA': {'2026-12-01': 100},
      },
      createdAt: created,
    );
    expect(future.status, FixedAmountStatus.noMarketDays);
  });

  test('a new simulation file replaces the previous one', () async {
    final dir = await Directory.systemTemp.createTemp('expert_scrip');
    addTearDown(() async {
      if (dir.existsSync()) await dir.delete(recursive: true);
    });
    final store = ExpertSimulationStore(directory: () async => dir);
    final first = BuySeries(
      id: '1',
      stockName: 'Stock A',
      symbol: 'AAA',
      notes: 'first',
      anchorDate: DateTime(2026, 10, 21),
      frequency: RepeatFrequency.none,
      interval: 1,
      endType: RepeatEnd.forever,
      createdAt: created,
    );
    final second = first.copyWith(
      id: '2',
      stockName: 'Stock B',
      symbol: 'BBB',
      notes: 'second',
      numberOfShares: 15,
    );

    expect(await store.write([first]), isNull);
    expect((await store.read()).single.symbol, 'AAA');
    expect(await store.write([second]), isNull);
    final saved = await store.read();
    expect(saved.single.symbol, 'BBB');
    expect(saved.single.notes, 'second');
    expect(saved.single.numberOfShares, 15);
    final run = ExpertRun(
      scripName: 'Default Scrip',
      strategy: fixedStockInvestedAmount,
      amount: 2000,
      published: DateTime(2026, 10, 18),
    );
    expect(await store.write([second], run: run), isNull);
    final stored = await store.readRun();
    expect(stored, run);
    expect(await store.write(const []), isNull);
    expect(await store.read(), isEmpty);
    expect(await store.readRun(), isNull);
  });
}
