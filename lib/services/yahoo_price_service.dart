import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../logic/dates.dart';
import '../models/daily_bar.dart';

class PriceLookupException implements Exception {
  PriceLookupException(this.message, {this.fatal = false});

  final String message;

  /// A busy or unreachable service. Trying another exchange will not help.
  final bool fatal;

  @override
  String toString() => message;
}

class ParsedChart {
  ParsedChart.ok(this.bars) : error = null;

  ParsedChart.fail(this.error) : bars = const [];

  final List<DailyBar> bars;
  final String? error;
}

/// Reads a Yahoo chart payload into daily bars dated in India.
ParsedChart parseYahooChart(String body) {
  final Object? decoded;
  try {
    decoded = jsonDecode(body);
  } catch (_) {
    return ParsedChart.fail('Price data was not readable.');
  }
  if (decoded is! Map) return ParsedChart.fail('Price data was not readable.');
  final chart = decoded['chart'];
  if (chart is! Map) return ParsedChart.fail('Price data was not readable.');
  final error = chart['error'];
  if (error != null) {
    final description = error is Map ? error['description'] : null;
    return ParsedChart.fail(
      description is String ? description : 'No price data for this symbol.',
    );
  }
  final result = chart['result'];
  if (result is! List || result.isEmpty || result.first is! Map) {
    return ParsedChart.fail('No price data for this symbol.');
  }
  final row = result.first as Map;
  final timestamps = row['timestamp'];
  final indicators = row['indicators'];
  if (timestamps is! List || indicators is! Map) {
    return ParsedChart.fail('No price data for this symbol.');
  }
  final quoteList = indicators['quote'];
  if (quoteList is! List || quoteList.isEmpty || quoteList.first is! Map) {
    return ParsedChart.fail('No price data for this symbol.');
  }
  final quote = quoteList.first as Map;
  final opens = _nums(quote['open']);
  final highs = _nums(quote['high']);
  final lows = _nums(quote['low']);
  final closes = _nums(quote['close']);
  final byDate = <String, DailyBar>{};
  for (var i = 0; i < timestamps.length; i++) {
    final stamp = timestamps[i];
    if (stamp is! num) continue;
    final instant = DateTime.fromMillisecondsSinceEpoch(
      stamp.toInt() * 1000,
      isUtc: true,
    );
    final date = indiaDate(instant);
    final bar = DailyBar(
      date: date,
      open: _at(opens, i),
      high: _at(highs, i),
      low: _at(lows, i),
      close: _at(closes, i),
    );
    if (bar.open == null && bar.high == null && bar.low == null && bar.close == null) {
      continue;
    }
    byDate[formatIsoDate(date)] = bar;
  }
  final bars = byDate.values.toList()
    ..sort((a, b) => a.date.compareTo(b.date));
  return ParsedChart.ok(bars);
}

class YahooPriceService {
  YahooPriceService({
    http.Client? client,
    Future<Directory> Function()? directory,
  }) : _client = client ?? http.Client(),
       _ownsClient = client == null,
       _directory = directory ?? _priceDirectory;

  static const _hosts = [
    'query1.finance.yahoo.com',
    'query2.finance.yahoo.com',
  ];

  final http.Client _client;
  final bool _ownsClient;
  final Future<Directory> Function() _directory;

  void close() {
    if (_ownsClient) _client.close();
  }

  /// Daily bars for [symbol] from [from] through [to], inclusive.
  ///
  /// A file cached earlier today is reused unless [refresh] is set.
  /// NSE (`.NS`) is tried first, then BSE (`.BO`).
  Future<List<DailyBar>> load(
    String symbol, {
    required DateTime from,
    required DateTime to,
    bool refresh = false,
  }) async {
    final normalized = symbol.trim().toUpperCase();
    final start = dateOnly(from);
    final end = dateOnly(to);
    if (!refresh) {
      final cached = await _readCache(normalized, start, end);
      if (cached != null) return cached;
    }
    final bars = await _download(normalized, start, end);
    await _writeCache(normalized, start, end, bars);
    return bars;
  }

  Future<List<DailyBar>> _download(
    String symbol,
    DateTime from,
    DateTime to,
  ) async {
    PriceLookupException? last;
    for (final suffix in ['NS', 'BO']) {
      try {
        final bars = await _downloadSuffix(symbol, suffix, from, to);
        return bars;
      } on PriceLookupException catch (error) {
        last = error;
        if (error.fatal) rethrow;
      }
    }
    if (last != null && last.fatal) throw last;
    return const [];
  }

  Future<List<DailyBar>> _downloadSuffix(
    String symbol,
    String suffix,
    DateTime from,
    DateTime to,
  ) async {
    PriceLookupException? last;
    for (final host in _hosts) {
      try {
        return await _get(host, symbol, suffix, from, to);
      } on PriceLookupException catch (error) {
        last = error;
        if (!error.fatal) rethrow;
      }
    }
    throw last ?? PriceLookupException('No price for $symbol.', fatal: true);
  }

  Future<List<DailyBar>> _get(
    String host,
    String symbol,
    String suffix,
    DateTime from,
    DateTime to,
  ) async {
    final uri = Uri.https(host, '/v8/finance/chart/$symbol.$suffix', {
      'interval': '1d',
      'period1': '${_unix(from)}',
      'period2': '${_unix(addDays(to, 1))}',
    });
    final http.Response response;
    try {
      response = await _client
          .get(
            uri,
            headers: const {
              'User-Agent':
                  'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
              'Accept': 'application/json',
            },
          )
          .timeout(const Duration(seconds: 20));
    } catch (_) {
      throw PriceLookupException(
        'Price service did not respond. Pull down to try again.',
        fatal: true,
      );
    }
    if (response.statusCode == 429 || response.statusCode >= 500) {
      throw PriceLookupException(
        'Price service is busy. Pull down to try again.',
        fatal: true,
      );
    }
    final parsed = parseYahooChart(response.body);
    if (parsed.error != null) {
      throw PriceLookupException(parsed.error!);
    }
    return parsed.bars;
  }

  Future<List<DailyBar>?> _readCache(
    String symbol,
    DateTime from,
    DateTime to,
  ) async {
    final file = await _file(symbol);
    if (!file.existsSync()) return null;
    try {
      final json = jsonDecode(await file.readAsString());
      if (json is! Map) return null;
      if (json['fetchedOn'] != formatIsoDate(DateTime.now())) return null;
      final cachedFrom = parseIsoDate(json['from'] as String);
      final cachedTo = parseIsoDate(json['to'] as String);
      if (cachedFrom.isAfter(from) || cachedTo.isBefore(to)) return null;
      final rows = json['bars'];
      if (rows is! List) return null;
      return [
        for (final row in rows)
          if (row is Map) DailyBar.fromJson(Map<String, dynamic>.from(row)),
      ];
    } catch (_) {
      return null;
    }
  }

  Future<void> _writeCache(
    String symbol,
    DateTime from,
    DateTime to,
    List<DailyBar> bars,
  ) async {
    final file = await _file(symbol);
    final payload = {
      'fetchedOn': formatIsoDate(DateTime.now()),
      'from': formatIsoDate(from),
      'to': formatIsoDate(to),
      'bars': [for (final bar in bars) bar.toJson()],
    };
    await file.writeAsString(jsonEncode(payload));
  }

  Future<File> _file(String symbol) async {
    final dir = await _directory();
    await dir.create(recursive: true);
    final safe = symbol.replaceAll(RegExp(r'[^A-Z0-9]'), '_');
    return File('${dir.path}${Platform.pathSeparator}$safe.json');
  }
}

Future<Directory> _priceDirectory() async {
  final root = await getApplicationSupportDirectory();
  return Directory('${root.path}${Platform.pathSeparator}prices');
}

List<double?> _nums(Object? value) {
  if (value is! List) return const [];
  return [for (final item in value) item is num ? item.toDouble() : null];
}

double? _at(List<double?> values, int index) {
  if (index < 0 || index >= values.length) return null;
  return values[index];
}

int _unix(DateTime date) {
  final day = dateOnly(date);
  return DateTime.utc(day.year, day.month, day.day).millisecondsSinceEpoch ~/
      1000;
}
