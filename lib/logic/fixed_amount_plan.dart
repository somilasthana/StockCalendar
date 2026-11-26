import '../models/buy_series.dart';
import 'dates.dart';

/// One stock the simulation may buy.
class PlanStock {
  const PlanStock({required this.name, required this.code});

  final String name;
  final String code;
}

enum FixedAmountStatus {
  /// Buys, including an empty list, should replace the expert calendar.
  ready,

  /// Start date through today has no weekday. Leave the calendar as it is.
  noMarketDays,

  /// No stock had a closing price. Leave the calendar as it is.
  noPrices,
}

class FixedAmountPlan {
  const FixedAmountPlan({
    required this.status,
    this.buys = const [],
    this.missingPrice = const [],
  });

  final FixedAmountStatus status;
  final List<BuySeries> buys;

  /// Stocks skipped on a day because that day's close was missing.
  /// They stay in the basket.
  final List<PlanStock> missingPrice;
}

/// Whole shares. A close at or under [amount] buys at least one share.
int sharesForAmount(int amount, double price) {
  if (price <= 0 || price > amount) return 0;
  final shares = (amount / price).floor();
  return shares < 1 ? 1 : shares;
}

/// Note stored on each simulated buy. [title] is the expert scrip title.
String fixedAmountNote(String title, int shares) {
  final name = title.trim().isEmpty ? 'Default Scrip' : title.trim();
  return 'Based on Expert Scrip $name we bought $shares from the market at the closing price';
}

bool hasMarketDay(DateTime from, DateTime to) {
  var date = dateOnly(from);
  final last = dateOnly(to);
  if (date.isAfter(last)) return false;
  while (!date.isAfter(last)) {
    if (!isWeekend(date)) return true;
    date = addDays(date, 1);
  }
  return false;
}

/// `Rs 2000` and `2000` both become 2000.
int? rupeeAmount(String label) {
  final digits = label.replaceAll(RegExp(r'[^0-9]'), '');
  if (digits.isEmpty) return null;
  return int.tryParse(digits);
}

/// Round-robin buys from the start date [published] through [today], weekdays only.
///
/// [closes] maps a symbol to that symbol's positive closing prices, keyed by
/// `yyyy-MM-dd`. One stock is bought on a weekday. A stock priced above
/// [amount], or missing a close while another stock has one, yields to the
/// next stock that same day. When nobody can be bought, the same stock is
/// tried again on the next open day. A weekday with no close for anyone is a
/// market holiday: it is skipped and does not move the turn.
FixedAmountPlan planFixedAmount({
  required String title,
  required List<PlanStock> basket,
  required int amount,
  required DateTime published,
  required DateTime today,
  required Map<String, Map<String, double>> closes,
  required DateTime createdAt,
}) {
  if (basket.isEmpty || amount < 1) {
    return const FixedAmountPlan(status: FixedAmountStatus.noPrices);
  }
  if (!hasMarketDay(published, today)) {
    return const FixedAmountPlan(status: FixedAmountStatus.noMarketDays);
  }

  final buys = <BuySeries>[];
  final missing = <PlanStock>[];
  final missingCodes = <String>{};
  var pointer = 0;
  var sawPrice = false;
  var date = dateOnly(published);
  final last = dateOnly(today);

  while (!date.isAfter(last)) {
    if (!isWeekend(date)) {
      final iso = formatIsoDate(date);
      final quotes = <int, double>{};
      for (var index = 0; index < basket.length; index++) {
        final price = _close(closes, basket[index].code, iso);
        if (price != null) quotes[index] = price;
      }
      if (quotes.isNotEmpty) {
        sawPrice = true;
        var cursor = pointer;
        var placedAt = -1;
        for (var step = 0; step < basket.length; step++) {
          final price = quotes[cursor];
          if (price == null) {
            final stock = basket[cursor];
            final code = normalizeSymbol(stock.code);
            if (missingCodes.add(code)) missing.add(stock);
          } else {
            final shares = sharesForAmount(amount, price);
            if (shares >= 1) {
              final stock = basket[cursor];
              buys.add(
                BuySeries(
                  id: '${createdAt.microsecondsSinceEpoch}_${buys.length}',
                  stockName: stock.name.trim().isEmpty
                      ? normalizeSymbol(stock.code)
                      : stock.name.trim(),
                  symbol: stock.code,
                  notes: fixedAmountNote(title, shares),
                  numberOfShares: shares,
                  anchorDate: date,
                  frequency: RepeatFrequency.none,
                  interval: 1,
                  endType: RepeatEnd.forever,
                  createdAt: createdAt,
                ),
              );
              placedAt = cursor;
              break;
            }
          }
          cursor = (cursor + 1) % basket.length;
        }
        if (placedAt >= 0) pointer = (placedAt + 1) % basket.length;
      }
    }
    date = addDays(date, 1);
  }

  if (!sawPrice) {
    return const FixedAmountPlan(status: FixedAmountStatus.noPrices);
  }
  return FixedAmountPlan(
    status: FixedAmountStatus.ready,
    buys: buys,
    missingPrice: missing,
  );
}

String describeFixedAmount(FixedAmountPlan plan, int amount) {
  switch (plan.status) {
    case FixedAmountStatus.noMarketDays:
      return 'There is no market day from the starting date through today. '
          'The calendar was left unchanged.';
    case FixedAmountStatus.noPrices:
      return 'No closing prices were found. The calendar was left unchanged.';
    case FixedAmountStatus.ready:
      final buffer = StringBuffer();
      final count = plan.buys.length;
      if (count == 0) {
        buffer.write(
          'No stock was priced at or under Rs $amount. '
          'The expert calendar was replaced.',
        );
      } else {
        final noun = count == 1 ? 'buy' : 'buys';
        buffer.write('Added $count $noun.');
      }
      for (final stock in plan.missingPrice) {
        buffer.writeln();
        buffer.write(
          '${normalizeSymbol(stock.code)} (${stock.name}) had no closing price '
          'on some days and was skipped on those days.',
        );
      }
      return buffer.toString();
  }
}

double? _close(
  Map<String, Map<String, double>> closes,
  String code,
  String iso,
) {
  final price = closes[normalizeSymbol(code)]?[iso];
  if (price == null || price <= 0) return null;
  return price;
}
