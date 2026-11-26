import 'package:cloud_firestore/cloud_firestore.dart';

import '../logic/series_edit.dart';
import '../models/buy_series.dart';
import 'series_repository.dart';

class FirestoreSeriesRepository implements SeriesRepository {
  FirestoreSeriesRepository(this.userId);

  final String userId;

  CollectionReference<Map<String, dynamic>> get _series => FirebaseFirestore
      .instance
      .collection('users')
      .doc(userId)
      .collection('series');

  @override
  Stream<List<BuySeries>> watch() {
    return _series.snapshots().map((snapshot) {
      return [
        for (final doc in snapshot.docs) BuySeries.fromJson(doc.id, doc.data()),
      ];
    });
  }

  @override
  Future<void> saveNew(BuySeries series) {
    return _series.doc(series.id).set(series.toJson());
  }

  @override
  Future<void> saveMany(List<BuySeries> series) async {
    if (series.isEmpty) return;
    final batch = FirebaseFirestore.instance.batch();
    for (final item in series) {
      batch.set(_series.doc(item.id), item.toJson());
    }
    await batch.commit();
  }

  @override
  Future<void> replaceAll(List<BuySeries> series) async {
    await clearAll();
    if (series.isNotEmpty) await saveMany(series);
  }

  @override
  Future<void> clearAll() async {
    while (true) {
      final snapshot = await _series.limit(500).get();
      if (snapshot.docs.isEmpty) return;
      final batch = FirebaseFirestore.instance.batch();
      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
      if (snapshot.docs.length < 500) return;
    }
  }

  @override
  Future<void> apply(String originalId, SeriesChange change) async {
    final batch = FirebaseFirestore.instance.batch();
    final original = _series.doc(originalId);
    if (change.deleteOriginal) {
      batch.delete(original);
    } else if (change.updated != null) {
      batch.set(original, change.updated!.toJson());
    }
    final created = change.created;
    if (created != null) {
      batch.set(_series.doc(created.id), created.toJson());
    }
    await batch.commit();
  }
}
