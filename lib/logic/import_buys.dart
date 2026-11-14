import 'dart:convert';

import '../models/buy_series.dart';
import 'series_edit.dart';

/// One buy the file could not add.
class ImportSkip {
  const ImportSkip({
    required this.row,
    required this.label,
    required this.message,
  });

  /// 1-based position in the JSON list.
  final int row;
  final String label;
  final String message;
}

/// Buys accepted from a file, plus rows that were left out.
///
/// [fileError] means nothing was read as a list of buys. Accepted rows are
/// still returned when other rows are skipped.
class ImportResult {
  const ImportResult({
    this.fileError,
    this.accepted = const [],
    this.skipped = const [],
  });

  final String? fileError;
  final List<BuySeries> accepted;
  final List<ImportSkip> skipped;
}

/// Reads an `input.json` file and checks each buy with the same rules as the
/// Stock to buy dialog. [existing] is not modified. Earlier accepted rows in
/// the same file count as already saved, so a repeated symbol on the same day
/// is skipped.
ImportResult parseImportBuys(
  String text, {
  required List<BuySeries> existing,
  DateTime? now,
}) {
  final Object? decoded;
  try {
    decoded = jsonDecode(text);
  } catch (_) {
    return const ImportResult(fileError: 'This file could not be read.');
  }
  if (decoded is! List) {
    return const ImportResult(fileError: 'This file is not a list of buys.');
  }
  if (decoded.isEmpty) {
    return const ImportResult(fileError: 'This file has no buys.');
  }

  final clock = (now ?? DateTime.now()).toUtc();
  final idBase = clock.microsecondsSinceEpoch;
  final pending = List<BuySeries>.of(existing);
  final accepted = <BuySeries>[];
  final skipped = <ImportSkip>[];

  for (var index = 0; index < decoded.length; index++) {
    final row = index + 1;
    final raw = decoded[index];
    if (raw is! Map) {
      skipped.add(
        ImportSkip(
          row: row,
          label: 'Buy $row',
          message: 'This entry is not a buy.',
        ),
      );
      continue;
    }
    final map = Map<String, dynamic>.from(raw);
    final label = _label(map, row);
    final draft = _draftBuy(map, id: '${idBase}_$index', createdAt: clock);
    if (draft.message != null) {
      skipped.add(ImportSkip(row: row, label: label, message: draft.message!));
      continue;
    }
    final series = draft.series!;
    final message = validateBuy(
      stockName: series.stockName,
      symbol: series.symbol,
      anchor: series.anchorDate,
      frequency: series.frequency,
      interval: series.interval,
      endType: series.endType,
      count: series.count ?? 1,
      untilDate: series.untilDate,
      existing: pending,
    );
    if (message != null) {
      skipped.add(ImportSkip(row: row, label: label, message: message));
      continue;
    }
    accepted.add(series);
    pending.add(series);
  }

  return ImportResult(accepted: accepted, skipped: skipped);
}

/// Text for the result dialog.
String describeImport(ImportResult result) {
  final error = result.fileError;
  if (error != null) return error;
  final count = result.accepted.length;
  final noun = count == 1 ? 'buy' : 'buys';
  final skipped = result.skipped;
  final buffer = StringBuffer('Imported $count $noun.');
  if (skipped.isEmpty) return buffer.toString();
  final word = skipped.length == 1 ? 'was' : 'were';
  buffer.write(' ${skipped.length} $word skipped.');
  for (final skip in skipped) {
    buffer.writeln();
    buffer.write('${skip.row}. ${skip.label}: ${skip.message}');
  }
  return buffer.toString();
}

String _label(Map<String, dynamic> map, int row) {
  final name = map['stock_name'];
  if (name is String && name.trim().isNotEmpty) return name.trim();
  final code = map['stock_code'];
  if (code is String && code.trim().isNotEmpty) return normalizeSymbol(code);
  return 'Buy $row';
}

class _Draft {
  const _Draft.ok(this.series) : message = null;
  const _Draft.fail(this.message) : series = null;

  final BuySeries? series;
  final String? message;
}

_Draft _draftBuy(
  Map<String, dynamic> map, {
  required String id,
  required DateTime createdAt,
}) {
  final buyDate = map['buy_date'];
  if (buyDate is! String) {
    return const _Draft.fail('Enter a date as year-month-day.');
  }
  final anchor = _parseDate(buyDate);
  if (anchor == null) {
    return const _Draft.fail('Enter a date as year-month-day.');
  }

  final repeat = map['Repeat'];
  if (repeat is! Map) return const _Draft.fail('Choose how this buy repeats.');
  final repeatMap = Map<String, dynamic>.from(repeat);
  final parsed = _parseRepeat(repeatMap);
  if (parsed.message != null) return _Draft.fail(parsed.message!);

  final notes = map['notes'];
  return _Draft.ok(
    BuySeries(
      id: id,
      stockName: map['stock_name'] is String
          ? (map['stock_name'] as String).trim()
          : '',
      symbol: normalizeSymbol(
        map['stock_code'] is String ? map['stock_code'] as String : '',
      ),
      notes: notes is String ? notes.trim() : '',
      anchorDate: anchor,
      frequency: parsed.frequency!,
      interval: parsed.interval!,
      endType: parsed.endType!,
      count: parsed.count,
      untilDate: parsed.untilDate,
      createdAt: createdAt,
    ),
  );
}

class _Repeat {
  const _Repeat.ok({
    required this.frequency,
    required this.interval,
    required this.endType,
    this.count,
    this.untilDate,
  }) : message = null;

  const _Repeat.fail(this.message)
    : frequency = null,
      interval = null,
      endType = null,
      count = null,
      untilDate = null;

  final RepeatFrequency? frequency;
  final int? interval;
  final RepeatEnd? endType;
  final int? count;
  final DateTime? untilDate;
  final String? message;
}

_Repeat _parseRepeat(Map<String, dynamic> repeat) {
  final frequency = switch (repeat['type']) {
    "Don't repeat" => RepeatFrequency.none,
    'Every day' => RepeatFrequency.days,
    'Every week' => RepeatFrequency.weeks,
    'Every month' => RepeatFrequency.months,
    'Every year' => RepeatFrequency.years,
    _ => null,
  };
  if (frequency == null) {
    return const _Repeat.fail('Choose how this buy repeats.');
  }
  if (frequency == RepeatFrequency.none) {
    return const _Repeat.ok(
      frequency: RepeatFrequency.none,
      interval: 1,
      endType: RepeatEnd.forever,
    );
  }

  var interval = 1;
  if (frequency == RepeatFrequency.days) {
    final days = _wholeNumber(repeat['frequency']);
    if (days == null || days < 1) {
      return const _Repeat.fail('Enter how many days between buys.');
    }
    interval = days;
  }

  switch (repeat['duration']) {
    case 'Forever':
      return _Repeat.ok(
        frequency: frequency,
        interval: interval,
        endType: RepeatEnd.forever,
      );
    case '# times total':
      final times = _wholeNumber(repeat['input_value']);
      if (times == null || times < 1) {
        return const _Repeat.fail('Enter how many times to repeat.');
      }
      return _Repeat.ok(
        frequency: frequency,
        interval: interval,
        endType: RepeatEnd.count,
        count: times,
      );
    case 'Until':
      final raw = repeat['input_value'];
      if (raw is! String) return const _Repeat.fail('Choose the last date.');
      final until = _parseDate(raw);
      if (until == null) return const _Repeat.fail('Choose the last date.');
      return _Repeat.ok(
        frequency: frequency,
        interval: interval,
        endType: RepeatEnd.until,
        untilDate: until,
      );
    default:
      return const _Repeat.fail('Choose how long this buy repeats.');
  }
}

int? _wholeNumber(Object? value) {
  if (value is int) return value;
  if (value is double && value == value.roundToDouble()) return value.toInt();
  return null;
}

/// Year-month-day only. A day or month that does not exist is rejected.
DateTime? _parseDate(String value) {
  final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(value.trim());
  if (match == null) return null;
  final year = int.parse(match.group(1)!);
  final month = int.parse(match.group(2)!);
  final day = int.parse(match.group(3)!);
  if (month < 1 || month > 12) return null;
  final date = DateTime(year, month, day);
  if (date.year != year || date.month != month || date.day != day) return null;
  return date;
}
