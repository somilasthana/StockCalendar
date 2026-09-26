import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../logic/series_edit.dart';
import '../models/buy_series.dart';
import 'series_repository.dart';

/// Buys stored on the phone until Firebase is connected.
class LocalSeriesRepository implements SeriesRepository {
  LocalSeriesRepository(this._prefs, this.userId);

  final SharedPreferences _prefs;
  final String userId;
  final _updates = StreamController<List<BuySeries>>.broadcast();

  String get _key => 'series_$userId';

  List<BuySeries> _read() {
    final raw = _prefs.getString(_key);
    if (raw == null || raw.isEmpty) return [];
    final list = jsonDecode(raw) as List<dynamic>;
    return list.map((item) {
      final map = Map<String, dynamic>.from(item as Map);
      final id = map.remove('id') as String;
      return BuySeries.fromJson(id, map);
    }).toList();
  }

  Future<void> _write(List<BuySeries> items) async {
    final encoded = jsonEncode([
      for (final item in items) {'id': item.id, ...item.toJson()},
    ]);
    await _prefs.setString(_key, encoded);
    if (!_updates.isClosed) _updates.add(items);
  }

  @override
  Stream<List<BuySeries>> watch() async* {
    yield _read();
    yield* _updates.stream;
  }

  @override
  Future<void> saveNew(BuySeries series) async {
    final items = _read()..add(series);
    await _write(items);
  }

  @override
  Future<void> apply(String originalId, SeriesChange change) async {
    final items = _read();
    items.removeWhere((item) => item.id == originalId);
    if (!change.deleteOriginal && change.updated != null) {
      items.add(change.updated!);
    }
    if (change.created != null) items.add(change.created!);
    await _write(items);
  }
}
