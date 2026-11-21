import 'dart:async';

import '../data/series_repository.dart';
import '../logic/series_edit.dart';
import '../models/buy_series.dart';

/// Buys that live only while the expert calendar is open.
class MemorySeriesRepository implements SeriesRepository {
  final _updates = StreamController<List<BuySeries>>.broadcast();
  List<BuySeries> _items = [];

  void _publish() {
    if (!_updates.isClosed) _updates.add(List<BuySeries>.unmodifiable(_items));
  }

  @override
  Stream<List<BuySeries>> watch() async* {
    yield List<BuySeries>.unmodifiable(_items);
    yield* _updates.stream;
  }

  @override
  Future<void> saveNew(BuySeries series) async {
    _items = [..._items, series];
    _publish();
  }

  @override
  Future<void> saveMany(List<BuySeries> series) async {
    if (series.isEmpty) return;
    _items = [..._items, ...series];
    _publish();
  }

  @override
  Future<void> clearAll() async {
    _items = [];
    _publish();
  }

  @override
  Future<void> apply(String originalId, SeriesChange change) async {
    final items = [..._items]..removeWhere((item) => item.id == originalId);
    if (!change.deleteOriginal && change.updated != null) {
      items.add(change.updated!);
    }
    if (change.created != null) items.add(change.created!);
    _items = items;
    _publish();
  }
}
