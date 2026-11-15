import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:stock_calendar/logic/dashboard_format.dart';
import 'package:stock_calendar/logic/dashboard_metrics.dart';
import 'package:stock_calendar/logic/dates.dart';
import 'package:stock_calendar/logic/recurrence.dart';
import 'package:stock_calendar/models/buy_series.dart';
import 'package:stock_calendar/models/daily_bar.dart';
import 'package:stock_calendar/services/yahoo_price_service.dart';

DayBuy buy(String symbol, DateTime date, {String name = ''}) {
  return DayBuy(
    date: date,
    series: BuySeries(
      id: '$symbol-${formatIsoDate(date)}',
      stockName: name.isEmpty ? symbol : name,
      symbol: symbol,
      notes: '',
      anchorDate: date,
      frequency: RepeatFrequency.none,
      interval: 1,
      endType: RepeatEnd.forever,
      createdAt: DateTime.utc(2026, 1, 1),
    ),
  );
}

DailyBar ohlc(DateTime date, double open, double low, double high, double close) {
  return DailyBar(date: date, open: open, high: high, low: low, close: close);
}

void main() {
  test('daily average uses the four prices, or whichever are present', () {
    expect(
      dailyAverage(open: 5, high: 9, low: 7, close: 11),
      8,
    );
    expect(dailyAverage(open: 5, high: 9, low: 7), 7);
    expect(dailyAverage(), isNull);
  });

  test('rupee labels group in the Indian style and stay short on an axis', () {
    expect(fullRupee(1234.5), '₹1,234.50');
    expect(fullRupee(1234567), '₹12,34,567.00');
    expect(shortRupee(7), '₹7');
    expect(shortRupee(7.5), '₹7.5');
    expect(shortRupee(1500), '₹1500');
    expect(shortRupee(10000), '₹10k');
    expect(niceMax(8), 10);
  });

  test('occurrence counts are buy days per symbol, largest first', () {
    final counts = occurrenceCounts([
      buy('INFY', DateTime(2026, 11, 11), name: 'Infosys'),
      buy('INFY', DateTime(2026, 11, 12), name: 'Infosys'),
      buy('TCS', DateTime(2026, 11, 11), name: 'TCS'),
    ]);
    expect(counts.map((row) => row.symbol), ['INFY', 'TCS']);
    expect(counts.first.count, 2);
    expect(counts.first.share, closeTo(2 / 3, 0.0001));
    expect(counts.first.name, 'Infosys');
  });

  test('a buy day sums the unit price of each symbol bought that day', () {
    final prices = {
      'RELIANCE': [ohlc(DateTime(2026, 11, 9), 10, 10, 10, 10)],
      'INFY': [ohlc(DateTime(2026, 11, 9), 8, 8, 8, 8)],
    };
    final report = eventDayTotals([
      buy('RELIANCE', DateTime(2026, 11, 9)),
      buy('INFY', DateTime(2026, 11, 9)),
    ], prices);
    expect(report.days.single.total, 18);
    expect(report.skippedSymbolDays, 0);
  });

  test('weekly, monthly, and yearly buckets label the period', () {
    final days = [
      DayPriceTotal(date: DateTime(2026, 11, 3), total: 4),
      DayPriceTotal(date: DateTime(2026, 11, 8), total: 5),
      DayPriceTotal(date: DateTime(2026, 11, 14), total: 6),
    ];
    final weekly = histogramBars(days, HistogramSpan.weekly);
    expect(weekly.map((bar) => bar.label), ['3 Nov', '8 Nov', '14 Nov']);
    expect(weekly.map((bar) => bar.total), [4, 5, 6]);

    final monthly = histogramBars(days, HistogramSpan.monthly);
    expect(monthly.map((bar) => bar.label), ['Nov-week1', 'Nov-week2']);
    expect(monthly.map((bar) => bar.total), [4, 11]);

    final yearly = histogramBars(days, HistogramSpan.yearly);
    expect(yearly.single.label, 'Nov 26');
    expect(yearly.single.total, 15);
  });

  test('labels include the year when the history crosses a year', () {
    final days = [
      DayPriceTotal(date: DateTime(2025, 12, 30), total: 1),
      DayPriceTotal(date: DateTime(2026, 1, 2), total: 2),
    ];
    expect(
      histogramBars(days, HistogramSpan.weekly).map((bar) => bar.label),
      ['30 Dec 2025', '2 Jan 2026'],
    );
    expect(
      histogramBars(days, HistogramSpan.monthly).map((bar) => bar.label),
      ['Dec-week5 2025', 'Jan-week1 2026'],
    );
  });

  test('portfolio gain marks every priced buy to the latest price', () {
    final prices = {
      'INFY': [
        ohlc(DateTime(2026, 11, 10), 3, 3, 3, 3),
        ohlc(DateTime(2026, 11, 11), 5, 5, 5, 5),
        ohlc(DateTime(2026, 11, 12), 7, 7, 7, 7),
        ohlc(DateTime(2026, 11, 14), 10, 10, 10, 10),
      ],
      'RELIANCE': [
        ohlc(DateTime(2026, 11, 10), 13, 13, 13, 13),
        ohlc(DateTime(2026, 11, 11), 15, 15, 15, 15),
        ohlc(DateTime(2026, 11, 12), 17, 17, 17, 17),
        ohlc(DateTime(2026, 11, 14), 20, 20, 20, 20),
      ],
    };
    final gain = portfolioGain(
      [
        buy('INFY', DateTime(2026, 11, 10)),
        buy('INFY', DateTime(2026, 11, 11)),
        buy('INFY', DateTime(2026, 11, 12)),
        buy('RELIANCE', DateTime(2026, 11, 10)),
        buy('RELIANCE', DateTime(2026, 11, 11)),
        buy('RELIANCE', DateTime(2026, 11, 12)),
      ],
      prices,
      DateTime(2026, 11, 15),
    );
    expect(gain.invested, 60);
    expect(gain.current, 90);
    expect(gain.amount, 30);
    expect(gain.percent, closeTo(50, 0.001));
    expect(gain.pricedBuys, 6);
  });

  test('a buy day with no price is left out of invested and current', () {
    final gain = portfolioGain(
      [
        buy('INFY', DateTime(2026, 11, 10)),
        buy('INFY', DateTime(2026, 11, 11)),
        buy('INFY', DateTime(2026, 11, 12)),
      ],
      {
        'INFY': [
          ohlc(DateTime(2026, 11, 10), 3, 3, 3, 3),
          ohlc(DateTime(2026, 11, 12), 7, 7, 7, 7),
          ohlc(DateTime(2026, 11, 14), 10, 10, 10, 10),
        ],
      },
      DateTime(2026, 11, 15),
    );
    expect(gain.invested, 10);
    expect(gain.current, 20);
    expect(gain.pricedBuys, 2);
    expect(gain.skippedBuyDays, 1);
    expect(exactDayPrice(
      [ohlc(DateTime(2026, 11, 10), 3, 3, 3, 3)],
      DateTime(2026, 11, 11),
    ), isNull);
  });

  test('Infosys range is 7 to 10 and green when the latest price is higher', () {
    final bars = [
      ohlc(DateTime(2026, 11, 9), 5, 7, 9, 11),
      ohlc(DateTime(2026, 11, 10), 3, 3, 3, 3),
      ohlc(DateTime(2026, 11, 11), 4, 6, 8, 10),
      ohlc(DateTime(2026, 11, 12), 5, 5, 5, 5),
      ohlc(DateTime(2026, 11, 13), 6, 8, 10, 12),
      ohlc(DateTime(2026, 11, 14), 10, 10, 10, 10),
    ];
    final report = rangeReport(
      [
        buy('INFY', DateTime(2026, 11, 11)),
        buy('INFY', DateTime(2026, 11, 12)),
        buy('INFY', DateTime(2026, 11, 13)),
      ],
      {'INFY': bars},
      DateTime(2026, 11, 15),
    );
    final point = report.points.single;
    expect(point.averagePurchase, 7);
    expect(point.current, 10);
    expect(point.above, isTrue);
    expect(point.flat, isFalse);
    expect(point.lower, 7);
    expect(point.upper, 10);
    expect(point.buyDaysPriced, 3);
  });

  test('a lower latest price is red, and an equal price draws no range', () {
    final below = rangeReport(
      [buy('INFY', DateTime(2026, 11, 11))],
      {'INFY': [ohlc(DateTime(2026, 11, 11), 4, 4, 4, 4), ohlc(DateTime(2026, 11, 12), 1, 1, 1, 1)]},
      DateTime(2026, 11, 12),
    ).points.single;
    expect(below.averagePurchase, 4);
    expect(below.current, 1);
    expect(below.above, isFalse);
    expect(below.lower, 1);
    expect(below.upper, 4);

    final even = rangeReport(
      [buy('INFY', DateTime(2026, 11, 11))],
      {'INFY': [ohlc(DateTime(2026, 11, 11), 7.004, 7.004, 7.004, 7.004)]},
      DateTime(2026, 11, 11),
    ).points.single;
    expect(even.flat, isTrue);
  });

  test('a holiday buy uses the previous trading day within five days', () {
    final bars = [ohlc(DateTime(2026, 11, 6), 8, 8, 8, 8)];
    final used = priceOnOrBefore(bars, DateTime(2026, 11, 11), maxGapDays: 5);
    expect(used?.date, DateTime(2026, 11, 6));
    final skipped = priceOnOrBefore(bars, DateTime(2026, 11, 12), maxGapDays: 5);
    expect(skipped, isNull);

    final report = rangeReport(
      [buy('INFY', DateTime(2026, 11, 12))],
      {'INFY': bars},
      DateTime(2026, 11, 12),
    );
    expect(report.points, isEmpty);
    expect(report.unpricedSymbols, ['INFY']);
    expect(report.skippedBuyDays, 0);
  });

  test('the price path marks planned buy days and skips days before the first buy', () {
    final points = pricePath(
      bars: [
        ohlc(DateTime(2026, 11, 9), 8, 8, 8, 8),
        ohlc(DateTime(2026, 11, 11), 7, 7, 7, 7),
        ohlc(DateTime(2026, 11, 12), 5, 5, 5, 5),
        ohlc(DateTime(2026, 11, 14), 10, 10, 10, 10),
      ],
      buyDates: [DateTime(2026, 11, 11), DateTime(2026, 11, 12)],
      firstBuy: DateTime(2026, 11, 11),
      today: DateTime(2026, 11, 15),
    );
    expect(points.map((point) => point.date.day), [11, 12, 14]);
    expect(points.map((point) => point.plannedBuy), [true, true, false]);
    expect(points.map((point) => point.price), [7, 5, 10]);
  });

  test('Yahoo chart JSON becomes India-dated bars', () {
    final unix = DateTime.utc(2026, 11, 13).millisecondsSinceEpoch ~/ 1000;
    final parsed = parseYahooChart('''
      {
        "chart": {
          "result": [{
            "timestamp": [$unix, $unix],
            "indicators": {
              "quote": [{
                "open": [5, null],
                "low": [7, null],
                "high": [9, null],
                "close": [11, null]
              }]
            }
          }],
          "error": null
        }
      }
    ''');
    expect(parsed.error, isNull);
    expect(parsed.bars, hasLength(1));
    expect(parsed.bars.single.date, indiaDate(DateTime.utc(2026, 11, 13)));
    expect(barPrice(parsed.bars.single), 8);
  });

  test('a missing NSE symbol falls back to BSE and then uses the cache', () async {
    final dir = await Directory.systemTemp.createTemp('prices');
    var calls = 0;
    final client = MockClient((request) async {
      calls++;
      if (request.url.path.endsWith('INFY.NS')) {
        return http.Response(
          '{"chart":{"result":null,"error":{"description":"No data found"}}}',
          404,
        );
      }
      final unix = DateTime.utc(2026, 11, 13).millisecondsSinceEpoch ~/ 1000;
      return http.Response(
        '{"chart":{"result":[{"timestamp":[$unix],"indicators":{"quote":[{"open":[4],"high":[8],"low":[6],"close":[10]}]}}],"error":null}}',
        200,
      );
    });
    final service = YahooPriceService(
      client: client,
      directory: () async => dir,
    );
    addTearDown(() async {
      service.close();
      await dir.delete(recursive: true);
    });

    final first = await service.load(
      'infy',
      from: DateTime(2026, 11, 1),
      to: DateTime(2026, 11, 15),
    );
    final second = await service.load(
      'INFY',
      from: DateTime(2026, 11, 1),
      to: DateTime(2026, 11, 15),
    );
    expect(barPrice(first.single), 7);
    expect(second.single.date, first.single.date);
    expect(calls, 2);
  });
}
