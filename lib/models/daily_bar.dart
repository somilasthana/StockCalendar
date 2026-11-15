import '../logic/dates.dart';

/// One daily trading bar. The dashboard price is the average of whichever
/// of open, high, low, and close are present.
class DailyBar {
  const DailyBar({
    required this.date,
    this.open,
    this.high,
    this.low,
    this.close,
  });

  final DateTime date;
  final double? open;
  final double? high;
  final double? low;
  final double? close;

  Map<String, dynamic> toJson() {
    return {
      'date': formatIsoDate(date),
      if (open != null) 'open': open,
      if (high != null) 'high': high,
      if (low != null) 'low': low,
      if (close != null) 'close': close,
    };
  }

  factory DailyBar.fromJson(Map<String, dynamic> json) {
    return DailyBar(
      date: parseIsoDate(json['date'] as String),
      open: (json['open'] as num?)?.toDouble(),
      high: (json['high'] as num?)?.toDouble(),
      low: (json['low'] as num?)?.toDouble(),
      close: (json['close'] as num?)?.toDouble(),
    );
  }
}
