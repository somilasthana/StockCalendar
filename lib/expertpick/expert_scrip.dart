import 'dart:convert';

import 'package:flutter/services.dart';

class ExpertStock {
  const ExpertStock({required this.name, required this.code});

  final String name;
  final String code;
}

class ExpertScrip {
  const ExpertScrip({
    required this.authorName,
    required this.investmentFirm,
    required this.description,
    required this.publishedDate,
    required this.youtubeUrl,
    required this.stocks,
  });

  final String authorName;
  final String investmentFirm;
  final String description;
  final String publishedDate;
  final String youtubeUrl;
  final List<ExpertStock> stocks;
}

const _sampleAsset = 'assets/icon/veteran.json';

const _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

Future<ExpertScrip> loadSampleScrip() async {
  return parseExpertScrip(await rootBundle.loadString(_sampleAsset));
}

ExpertScrip parseExpertScrip(String raw) {
  final decoded = jsonDecode(raw);
  if (decoded is! Map) {
    throw const FormatException('The sample could not be read.');
  }
  final map = Map<String, dynamic>.from(decoded);
  return ExpertScrip(
    authorName: _text(map['author_name']),
    investmentFirm: _text(map['investment_firm']),
    description: _text(map['description']),
    publishedDate: _text(map['published_date']),
    youtubeUrl: _text(map['youtube_url']),
    stocks: _stocks(map['stocks']),
  );
}

String formatPublishedDate(String raw) {
  final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})').firstMatch(raw.trim());
  if (match == null) return raw.trim();
  final month = int.tryParse(match.group(2)!);
  final day = int.tryParse(match.group(3)!);
  if (month == null || day == null || month < 1 || month > 12) {
    return raw.trim();
  }
  return '$day ${_months[month - 1]} ${match.group(1)}';
}

String? youtubeVideoId(String url) {
  final uri = Uri.tryParse(url.trim());
  if (uri == null) return null;
  if (uri.host.contains('youtu.be')) {
    if (uri.pathSegments.isEmpty) return null;
    return _cleanId(uri.pathSegments.first);
  }
  final query = uri.queryParameters['v'];
  if (query != null && query.isNotEmpty) return _cleanId(query);
  final segments = uri.pathSegments;
  for (final marker in ['embed', 'shorts']) {
    final index = segments.indexOf(marker);
    if (index >= 0 && index + 1 < segments.length) {
      return _cleanId(segments[index + 1]);
    }
  }
  return null;
}

String? _cleanId(String value) {
  final id = value.trim();
  if (!RegExp(r'^[A-Za-z0-9_-]{6,}$').hasMatch(id)) return null;
  return id;
}

String _text(Object? value) => value?.toString().trim() ?? '';

List<ExpertStock> _stocks(Object? value) {
  if (value is! List) return const [];
  final stocks = <ExpertStock>[];
  for (final item in value) {
    if (item is! Map) continue;
    final row = Map<String, dynamic>.from(item);
    final code = _text(row['stock_code']);
    if (code.isEmpty) continue;
    final name = _text(row['stock_name']);
    stocks.add(ExpertStock(name: name.isEmpty ? code : name, code: code));
  }
  return stocks;
}
