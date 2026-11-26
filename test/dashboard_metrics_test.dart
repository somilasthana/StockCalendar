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

DayBuy buy(String symbol, DateTime date, {String name = '', int shares = 1}) {
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
      numberOfShares: shares,
      createdAt: DateTime.utc(2026, 1, 1),
    ),
  );
}

DailyBar ohlc(
  DateTime date,
  double open,
  double low,
  double high,
  double close,
) {
  return DailyBar(date: date, open: open, high: high, low: low, close: close);
}

void main() {
  test('daily average uses the four prices, or whichever are present', () {
    expect(dailyAverage(open: 5, high: 9, low: 7, close: 11), 8);
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
    expect(histogramBars(days, HistogramSpan.weekly).map((bar) => bar.label), [
      '30 Dec 2025',
      '2 Jan 2026',
    ]);
    expect(histogramBars(days, HistogramSpan.monthly).map((bar) => bar.label), [
      'Dec-week5 2025',
      'Jan-week1 2026',
    ]);
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
    expect(
      exactDayPrice([
        ohlc(DateTime(2026, 11, 10), 3, 3, 3, 3),
      ], DateTime(2026, 11, 11)),
      isNull,
    );
  });

  test(
    'Infosys range is 9 to 10 and green when the latest close is higher',
    () {
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
      expect(point.averagePurchase, 9);
      expect(point.current, 10);
      expect(point.above, isTrue);
      expect(point.flat, isFalse);
      expect(point.lower, 9);
      expect(point.upper, 10);
      expect(point.buyDaysPriced, 3);
    },
  );

  test('a lower latest price is red, and an equal price draws no range', () {
    final below = rangeReport(
      [buy('INFY', DateTime(2026, 11, 11))],
      {
        'INFY': [
          ohlc(DateTime(2026, 11, 11), 4, 4, 4, 4),
          ohlc(DateTime(2026, 11, 12), 1, 1, 1, 1),
        ],
      },
      DateTime(2026, 11, 12),
    ).points.single;
    expect(below.averagePurchase, 4);
    expect(below.current, 1);
    expect(below.above, isFalse);
    expect(below.lower, 1);
    expect(below.upper, 4);

    final even = rangeReport(
      [buy('INFY', DateTime(2026, 11, 11))],
      {
        'INFY': [ohlc(DateTime(2026, 11, 11), 7.004, 7.004, 7.004, 7.004)],
      },
      DateTime(2026, 11, 11),
    ).points.single;
    expect(even.flat, isTrue);
  });

  test('a buy day does not borrow an earlier close', () {
    final bars = [ohlc(DateTime(2026, 11, 6), 8, 8, 8, 8)];
    expect(
      priceOnOrBefore(bars, DateTime(2026, 11, 12))?.date,
      DateTime(2026, 11, 6),
    );

    final report = rangeReport(
      [buy('INFY', DateTime(2026, 11, 12))],
      {'INFY': bars},
      DateTime(2026, 11, 12),
    );
    expect(report.points, isEmpty);
    expect(report.unpricedSymbols, ['INFY']);
    expect(report.skippedBuyDays, 0);
  });

  test(
    'the price path marks planned buy days and skips days before the first buy',
    () {
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
    },
  );

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

  test('personal totals ignore the stored share count and use the close', () {
    final gain = portfolioGain(
      [buy('INFY', DateTime(2026, 11, 10), shares: 20)],
      {
        'INFY': [
          ohlc(DateTime(2026, 11, 10), 1, 1, 9, 5),
          ohlc(DateTime(2026, 11, 14), 2, 2, 14, 8),
        ],
      },
      DateTime(2026, 11, 15),
    );
    expect(gain.invested, 5);
    expect(gain.current, 8);
    expect(
      portfolioShareCount([buy('INFY', DateTime(2026, 11, 10), shares: 20)]),
      20,
    );
  });

  test('expert money uses the close times the shares', () {
    final prices = {
      'INFY': [
        ohlc(DateTime(2026, 11, 10), 1, 1, 1, 100),
        DailyBar(date: DateTime(2026, 11, 11), open: 8, high: 8, low: 8),
        ohlc(DateTime(2026, 11, 12), 9, 9, 9, 50),
      ],
    };
    final buys = [
      buy('INFY', DateTime(2026, 11, 10), shares: 20),
      buy('INFY', DateTime(2026, 11, 11), shares: 10),
      buy('INFY', DateTime(2026, 11, 12), shares: 4),
    ];
    final gain = portfolioGain(
      buys,
      prices,
      DateTime(2026, 11, 15),
      expert: true,
    );
    expect(gain.invested, 2200);
    expect(gain.current, 1200);
    expect(gain.amount, -1000);
    expect(gain.percent, closeTo(-1000 / 2200 * 100, 0.001));
    expect(gain.pricedBuys, 2);
    expect(gain.skippedBuyDays, 1);

    final days = eventDayTotals(buys, prices, expert: true);
    expect(days.days.map((day) => day.total), [2000, 200]);
    expect(days.skippedSymbolDays, 1);

    final point = rangeReport(
      buys,
      prices,
      DateTime(2026, 11, 15),
      expert: true,
    ).points.single;
    expect(point.averagePurchase, closeTo(2200 / 24, 0.001));
    expect(point.current, 50);
    expect(point.above, isFalse);
    expect(point.lower, 50);
    expect(point.upper, closeTo(2200 / 24, 0.001));
    expect(point.buyDaysPriced, 2);
  });

  test(
    'expert gain bar is green when the latest close is above the paid average',
    () {
      final prices = {
        'INFY': [
          ohlc(DateTime(2026, 11, 10), 1, 1, 1, 100),
          ohlc(DateTime(2026, 11, 12), 1, 1, 1, 40),
          ohlc(DateTime(2026, 11, 13), 1, 1, 1, 50),
        ],
      };
      final point = rangeReport(
        [
          buy('INFY', DateTime(2026, 11, 10), shares: 4),
          buy('INFY', DateTime(2026, 11, 12), shares: 40),
        ],
        prices,
        DateTime(2026, 11, 13),
        expert: true,
      ).points.single;
      expect(point.averagePurchase, closeTo(2000 / 44, 0.001));
      expect(point.current, 50);
      expect(point.above, isTrue);
      expect(point.lower, closeTo(2000 / 44, 0.001));
      expect(point.upper, 50);
    },
  );

  test('a buy with no close that day is left out', () {
    final bars = [ohlc(DateTime(2026, 11, 10), 4, 4, 4, 8)];
    final personal = rangeReport(
      [buy('INFY', DateTime(2026, 11, 11))],
      {'INFY': bars},
      DateTime(2026, 11, 12),
    );
    expect(personal.points, isEmpty);
    expect(personal.unpricedSymbols, ['INFY']);

    final expert = rangeReport(
      [buy('INFY', DateTime(2026, 11, 11), shares: 5)],
      {'INFY': bars},
      DateTime(2026, 11, 12),
      expert: true,
    );
    expect(expert.points, isEmpty);
    expect(expert.unpricedSymbols, ['INFY']);
  });

  test('price path uses the close', () {
    final points = pricePath(
      bars: [ohlc(DateTime(2026, 11, 11), 1, 3, 7, 10)],
      buyDates: [DateTime(2026, 11, 11)],
      firstBuy: DateTime(2026, 11, 11),
      today: DateTime(2026, 11, 11),
    );
    expect(points.single.price, 10);
  });

  test('expert stock count is the number of symbols bought', () {
    final buys = [
      buy('INFY', DateTime(2026, 11, 9), shares: 20),
      buy('INFY', DateTime(2026, 11, 10), shares: 10),
      buy('TCS', DateTime(2026, 11, 10), shares: 5),
    ];
    expect(uniqueBoughtStocks(buys), 2);
  });

  test('buying pattern weights each stock by its current value', () {
    final prices = {
      'INFY': [
        ohlc(DateTime(2026, 11, 9), 1, 1, 1, 10),
        ohlc(DateTime(2026, 11, 10), 1, 1, 1, 10),
        ohlc(DateTime(2026, 11, 14), 1, 1, 1, 12),
      ],
      'TCS': [
        ohlc(DateTime(2026, 11, 10), 1, 1, 1, 200),
        ohlc(DateTime(2026, 11, 14), 1, 1, 1, 180),
      ],
    };
    final rows = holdingValueBySymbol(
      [
        buy('INFY', DateTime(2026, 11, 9), name: 'Infosys', shares: 20),
        buy('INFY', DateTime(2026, 11, 10), name: 'Infosys', shares: 10),
        buy('INFY', DateTime(2026, 11, 11), name: 'Infosys', shares: 50),
        buy('TCS', DateTime(2026, 11, 10), name: 'TCS', shares: 5),
        buy('HDFC', DateTime(2026, 11, 10), name: 'HDFC', shares: 100),
      ],
      prices,
      DateTime(2026, 11, 15),
    );
    // INFY holds 80 shares at 12. TCS holds 5 at 180. HDFC has no close.
    expect(rows.map((row) => row.symbol), ['INFY', 'TCS']);
    expect(rows.first.amount, 960);
    expect(rows.first.share, closeTo(960 / 1860, 0.0001));
    expect(rows.first.name, 'Infosys');
    expect(rows.last.amount, 900);
    expect(rows.last.share, closeTo(900 / 1860, 0.0001));
  });

  test('a priced buy recovers the dropdown amount', () {
    final prices = {
      'INFY': [ohlc(DateTime(2026, 11, 9), 1, 1, 1, 100)],
    };
    expect(
      inferDropdownAmount([
        buy('INFY', DateTime(2026, 11, 9), shares: 20),
      ], prices),
      2000,
    );
    expect(
      inferDropdownAmount([
        buy('INFY', DateTime(2026, 11, 9), shares: 20),
      ], const {}),
      isNull,
    );
  });

  test('portfolio worth plots open market days and skips a missing close', () {
    final prices = {
      'INFY': [
        ohlc(DateTime(2026, 11, 9), 1, 1, 1, 100),
        ohlc(DateTime(2026, 11, 10), 1, 1, 1, 110),
        ohlc(DateTime(2026, 11, 16), 1, 1, 1, 120),
      ],
      'TCS': [
        ohlc(DateTime(2026, 11, 9), 1, 1, 1, 50),
        ohlc(DateTime(2026, 11, 10), 1, 1, 1, 200),
        ohlc(DateTime(2026, 11, 13), 1, 1, 1, 190),
        ohlc(DateTime(2026, 11, 16), 1, 1, 1, 180),
      ],
    };
    final points = portfolioWorthSeries(
      buys: [
        buy('INFY', DateTime(2026, 11, 9), shares: 10),
        buy('TCS', DateTime(2026, 11, 10), shares: 5),
      ],
      prices: prices,
      today: DateTime(2026, 11, 16),
      amount: 1000,
      start: DateTime(2026, 11, 9),
    );
    expect(points.map((point) => point.date), [
      DateTime(2026, 11, 9),
      DateTime(2026, 11, 10),
      DateTime(2026, 11, 16),
    ]);
    expect(points.map((point) => point.invested), [1000, 2000, 3000]);
    expect(points[0].worth, 1000);
    expect(points[1].worth, 2100);
    expect(points[2].worth, 2100);

    final gain = gainOnLastWorth(points.last);
    expect(gain.invested, 3000);
    expect(gain.current, 2100);
    expect(gain.amount, points.last.worth - points.last.invested);
    expect(gain.percent, closeTo(-900 / 3000 * 100, 0.001));
  });

  test('a weekday without a close is plotted at the open', () {
    final points = portfolioWorthSeries(
      buys: [buy('INFY', DateTime(2026, 11, 16), shares: 10)],
      prices: {
        'INFY': [
          ohlc(DateTime(2026, 11, 16), 1, 1, 1, 100),
          DailyBar(date: DateTime(2026, 11, 17), open: 130),
        ],
      },
      today: DateTime(2026, 11, 17),
      amount: 1000,
      start: DateTime(2026, 11, 16),
    );
    expect(points.map((point) => point.date), [
      DateTime(2026, 11, 16),
      DateTime(2026, 11, 17),
    ]);
    expect(points.last.invested, 2000);
    expect(points.last.worth, 1300);
    expect(gainOnLastWorth(points.last).amount, 1300 - 2000);
  });

  test('a weekend stays off the chart and keeps the last close', () {
    final points = portfolioWorthSeries(
      buys: [buy('INFY', DateTime(2026, 11, 13), shares: 4)],
      prices: {
        'INFY': [ohlc(DateTime(2026, 11, 13), 10, 10, 10, 100)],
      },
      today: DateTime(2026, 11, 15),
      amount: 1000,
      start: DateTime(2026, 11, 13),
    );
    expect(points.map((point) => point.date), [DateTime(2026, 11, 13)]);
    expect(points.single.worth, 400);
    expect(points.single.invested, 1000);
  });

  test('an open day before the first buy still adds the amount', () {
    final points = portfolioWorthSeries(
      buys: [buy('INFY', DateTime(2026, 11, 10), shares: 4)],
      prices: {
        'INFY': [
          ohlc(DateTime(2026, 11, 9), 1, 1, 1, 100),
          ohlc(DateTime(2026, 11, 10), 1, 1, 1, 250),
        ],
      },
      today: DateTime(2026, 11, 10),
      amount: 1000,
      start: DateTime(2026, 11, 9),
    );
    expect(points.map((point) => point.invested), [1000, 2000]);
    expect(points.map((point) => point.worth), [0, 1000]);
  });

  test('personal gain bar averages one close per buy', () {
    final point = rangeReport(
      [
        buy('INFY', DateTime(2026, 11, 10), shares: 4),
        buy('INFY', DateTime(2026, 11, 12), shares: 40),
      ],
      {
        'INFY': [
          ohlc(DateTime(2026, 11, 10), 1, 1, 1, 100),
          ohlc(DateTime(2026, 11, 12), 1, 1, 1, 40),
          ohlc(DateTime(2026, 11, 13), 1, 1, 1, 50),
        ],
      },
      DateTime(2026, 11, 13),
    ).points.single;
    expect(point.averagePurchase, 70);
    expect(point.current, 50);
    expect(point.above, isFalse);
  });

  test('a buy day adds the close once, ignoring the stored share count', () {
    final report = eventDayTotals(
      [buy('INFY', DateTime(2026, 11, 10), shares: 20)],
      {
        'INFY': [ohlc(DateTime(2026, 11, 10), 1, 1, 9, 100)],
      },
    );
    expect(report.days.single.total, 100);
    expect(report.skippedSymbolDays, 0);
  });

  test('personal buying pattern counts one share at the latest close', () {
    final rows = holdingValueBySymbol(
      [
        buy('INFY', DateTime(2026, 11, 9), name: 'Infosys', shares: 20),
        buy('INFY', DateTime(2026, 11, 10), name: 'Infosys', shares: 10),
        buy('TCS', DateTime(2026, 11, 10), name: 'TCS', shares: 5),
      ],
      {
        'INFY': [ohlc(DateTime(2026, 11, 14), 1, 1, 1, 12)],
        'TCS': [ohlc(DateTime(2026, 11, 14), 1, 1, 1, 180)],
      },
      DateTime(2026, 11, 15),
      expert: false,
    );
    expect(rows.map((row) => row.symbol), ['TCS', 'INFY']);
    expect(rows.first.amount, 180);
    expect(rows.last.amount, 24);
    expect(rows.last.share, closeTo(24 / 204, 0.0001));
  });

  test(
    'personal worth adds the close on buy days and stays flat otherwise',
    () {
      final points = personalWorthSeries(
        buys: [
          buy('INFY', DateTime(2026, 11, 9), shares: 10),
          buy('TCS', DateTime(2026, 11, 10), shares: 5),
        ],
        prices: {
          'INFY': [
            ohlc(DateTime(2026, 11, 9), 1, 1, 1, 100),
            ohlc(DateTime(2026, 11, 10), 1, 1, 1, 110),
            ohlc(DateTime(2026, 11, 11), 1, 1, 1, 120),
            ohlc(DateTime(2026, 11, 16), 1, 1, 1, 130),
          ],
          'TCS': [
            ohlc(DateTime(2026, 11, 9), 1, 1, 1, 50),
            ohlc(DateTime(2026, 11, 10), 1, 1, 1, 200),
            ohlc(DateTime(2026, 11, 11), 1, 1, 1, 210),
            ohlc(DateTime(2026, 11, 16), 1, 1, 1, 180),
          ],
        },
        today: DateTime(2026, 11, 16),
      );
      expect(points.map((point) => point.date), [
        DateTime(2026, 11, 9),
        DateTime(2026, 11, 10),
        DateTime(2026, 11, 11),
        DateTime(2026, 11, 16),
      ]);
      expect(points.map((point) => point.invested), [100, 300, 300, 300]);
      expect(points[0].worth, 100);
      expect(points[1].worth, 310);
      expect(points[2].worth, 330);
      expect(points[3].worth, 310);
      expect(gainOnLastWorth(points.last).amount, 10);
    },
  );

  test('personal worth starts on the first buy', () {
    final points = personalWorthSeries(
      buys: [buy('INFY', DateTime(2026, 11, 10), shares: 4)],
      prices: {
        'INFY': [
          ohlc(DateTime(2026, 11, 9), 1, 1, 1, 100),
          ohlc(DateTime(2026, 11, 10), 1, 1, 1, 250),
        ],
      },
      today: DateTime(2026, 11, 10),
    );
    expect(points.map((point) => point.date), [DateTime(2026, 11, 10)]);
    expect(points.single.invested, 250);
    expect(points.single.worth, 250);
  });

  test('a buy keeps its cost when that day cannot be plotted', () {
    final points = personalWorthSeries(
      buys: [
        buy('INFY', DateTime(2026, 11, 9)),
        buy('TCS', DateTime(2026, 11, 10)),
      ],
      prices: {
        'INFY': [
          ohlc(DateTime(2026, 11, 9), 1, 1, 1, 100),
          ohlc(DateTime(2026, 11, 11), 1, 1, 1, 110),
        ],
        'TCS': [
          ohlc(DateTime(2026, 11, 10), 1, 1, 1, 200),
          ohlc(DateTime(2026, 11, 11), 1, 1, 1, 210),
        ],
      },
      today: DateTime(2026, 11, 11),
    );
    expect(points.map((point) => point.date), [
      DateTime(2026, 11, 9),
      DateTime(2026, 11, 11),
    ]);
    expect(points.map((point) => point.invested), [100, 300]);
    expect(points.last.worth, 320);
  });

  test(
    'an open session updates worth and leaves out a buy that has no close',
    () {
      final points = personalWorthSeries(
        buys: [
          buy('INFY', DateTime(2026, 11, 16)),
          buy('TCS', DateTime(2026, 11, 17)),
        ],
        prices: {
          'INFY': [
            ohlc(DateTime(2026, 11, 16), 1, 1, 1, 100),
            DailyBar(date: DateTime(2026, 11, 17), open: 130),
          ],
          'TCS': [DailyBar(date: DateTime(2026, 11, 17), open: 80)],
        },
        today: DateTime(2026, 11, 17),
      );
      expect(points.map((point) => point.date), [
        DateTime(2026, 11, 16),
        DateTime(2026, 11, 17),
      ]);
      expect(points.last.invested, 100);
      expect(points.last.worth, 130);
    },
  );

  test('personal worth leaves the weekend off the chart', () {
    final points = personalWorthSeries(
      buys: [buy('INFY', DateTime(2026, 11, 13))],
      prices: {
        'INFY': [ohlc(DateTime(2026, 11, 13), 10, 10, 10, 100)],
      },
      today: DateTime(2026, 11, 15),
    );
    expect(points.map((point) => point.date), [DateTime(2026, 11, 13)]);
    expect(points.single.invested, 100);
    expect(points.single.worth, 100);
  });
}
