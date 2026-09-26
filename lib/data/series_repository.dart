import '../logic/series_edit.dart';
import '../models/buy_series.dart';

abstract class SeriesRepository {
  Stream<List<BuySeries>> watch();
  Future<void> saveNew(BuySeries series);
  Future<void> apply(String originalId, SeriesChange change);
}
