import '../logic/series_edit.dart';
import '../models/buy_series.dart';

abstract class SeriesRepository {
  Stream<List<BuySeries>> watch();
  Future<void> saveNew(BuySeries series);
  Future<void> saveMany(List<BuySeries> series);

  /// Replaces the saved list. An empty list clears it.
  Future<void> replaceAll(List<BuySeries> series);
  Future<void> apply(String originalId, SeriesChange change);
  Future<void> clearAll();
}
