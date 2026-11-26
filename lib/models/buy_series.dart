import '../logic/dates.dart';

enum RepeatFrequency { none, days, weeks, months, years }

enum RepeatEnd { forever, count, until }

/// One saved buy. Repeated days are calculated from this record, not stored
/// one by one, so "forever" stays a single document.
class BuySeries {
  BuySeries({
    required this.id,
    required this.stockName,
    required this.symbol,
    required this.notes,
    required DateTime anchorDate,
    required this.frequency,
    required this.interval,
    required this.endType,
    required DateTime createdAt,
    this.count,
    int numberOfShares = 1,
    DateTime? untilDate,
    DateTime? cutBefore,
  }) : anchorDate = dateOnly(anchorDate),
       untilDate = untilDate == null ? null : dateOnly(untilDate),
       cutBefore = cutBefore == null ? null : dateOnly(cutBefore),
       createdAt = createdAt.toUtc(),
       numberOfShares = numberOfShares < 1 ? 1 : numberOfShares;

  final String id;
  final String stockName;
  final String symbol;
  final String notes;
  final DateTime anchorDate;
  final RepeatFrequency frequency;
  final int interval;
  final RepeatEnd endType;
  final int? count;

  /// Shares bought on each day of this rule. The calendar dialog does not
  /// show it. Expert Scrip dashboard totals use it. Personal buys stay at 1.
  final int numberOfShares;
  final DateTime? untilDate;

  /// Occurrences on or after this date are removed. Used when a later day
  /// is edited or deleted and earlier days stay as they were.
  final DateTime? cutBefore;
  final DateTime createdAt;

  static const _unset = Object();

  BuySeries copyWith({
    String? id,
    String? stockName,
    String? symbol,
    String? notes,
    DateTime? anchorDate,
    RepeatFrequency? frequency,
    int? interval,
    RepeatEnd? endType,
    Object? count = _unset,
    int? numberOfShares,
    Object? untilDate = _unset,
    Object? cutBefore = _unset,
    DateTime? createdAt,
  }) {
    return BuySeries(
      id: id ?? this.id,
      stockName: stockName ?? this.stockName,
      symbol: symbol ?? this.symbol,
      notes: notes ?? this.notes,
      anchorDate: anchorDate ?? this.anchorDate,
      frequency: frequency ?? this.frequency,
      interval: interval ?? this.interval,
      endType: endType ?? this.endType,
      count: identical(count, _unset) ? this.count : count as int?,
      numberOfShares: numberOfShares ?? this.numberOfShares,
      untilDate: identical(untilDate, _unset) ? this.untilDate : untilDate as DateTime?,
      cutBefore: identical(cutBefore, _unset) ? this.cutBefore : cutBefore as DateTime?,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'stockName': stockName,
      'symbol': symbol,
      'notes': notes,
      'anchorDate': formatIsoDate(anchorDate),
      'frequency': frequency.name,
      'interval': interval,
      'endType': endType.name,
      'createdAt': createdAt.toUtc().toIso8601String(),
      if (count != null) 'count': count,
      if (numberOfShares != 1) 'numberOfShares': numberOfShares,
      if (untilDate != null) 'untilDate': formatIsoDate(untilDate!),
      if (cutBefore != null) 'cutBefore': formatIsoDate(cutBefore!),
    };
  }

  factory BuySeries.fromJson(String id, Map<String, dynamic> json) {
    return BuySeries(
      id: id,
      stockName: json['stockName'] as String? ?? '',
      symbol: (json['symbol'] as String? ?? '').toUpperCase(),
      notes: json['notes'] as String? ?? '',
      anchorDate: parseIsoDate(json['anchorDate'] as String),
      frequency: RepeatFrequency.values.byName(json['frequency'] as String? ?? 'none'),
      interval: json['interval'] as int? ?? 1,
      endType: RepeatEnd.values.byName(json['endType'] as String? ?? 'forever'),
      count: json['count'] as int?,
      numberOfShares: shareCountOf(json['numberOfShares']),
      untilDate: json['untilDate'] == null ? null : parseIsoDate(json['untilDate'] as String),
      cutBefore: json['cutBefore'] == null ? null : parseIsoDate(json['cutBefore'] as String),
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}

String normalizeSymbol(String value) => value.trim().toUpperCase();

/// A positive whole share count. Anything else is one share.
int shareCountOf(Object? value) {
  if (value is int) return value >= 1 ? value : 1;
  if (value is double && value >= 1 && value == value.roundToDouble()) {
    return value.toInt();
  }
  return 1;
}

String repeatLabel(BuySeries series) {
  if (series.frequency == RepeatFrequency.none) return "Doesn't repeat";

  final when = switch (series.frequency) {
    RepeatFrequency.days =>
      'Every ${series.interval} ${series.interval == 1 ? 'day' : 'days'}',
    RepeatFrequency.weeks => 'Every week',
    RepeatFrequency.months => 'Every month',
    RepeatFrequency.years => 'Every year',
    RepeatFrequency.none => "Doesn't repeat",
  };

  final end = switch (series.endType) {
    RepeatEnd.forever => 'forever',
    RepeatEnd.count => '${series.count ?? 0} times total',
    RepeatEnd.until =>
      series.untilDate == null ? 'until a date' : 'until ${prettyDate(series.untilDate!)}',
  };
  return '$when, $end';
}
