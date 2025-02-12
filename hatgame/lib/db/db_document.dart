import 'package:flutter/material.dart';
import 'package:hatgame/db/db_columns.dart';
import 'package:cloud_firestore/cloud_firestore.dart' as firestore;
import 'package:hatgame/util/assertion.dart';

enum LocalCacheBehavior {
  noCache,
  cache,
}

abstract class DBDocumentReference {
  String get path;

  Future<void> setColumns(List<DBColumnUpdate> columns);

  // Set new content for each column. Doesn't support nested updates
  // (in contrast to FirebaseFirestore).
  Future<void> updateColumns(List<DBColumnUpdate> columns,
      {LocalCacheBehavior localCache = LocalCacheBehavior.noCache}) {
    checkNoNestedOverrides(columns);
    return updateColumnsImpl(columns, localCache);
  }

  Future<DBDocumentSnapshot> get();

  Future<void> delete();

  void clearLocalCache();
  void assertLocalCacheIsEmpty();

  Stream<DBDocumentSnapshot> snapshots();

  @protected
  Future<void> updateColumnsImpl(
      List<DBColumnUpdate> columns, LocalCacheBehavior localCache);

  @protected
  void checkNoNestedOverrides(List<DBColumnUpdate> columns) {
    for (final col in columns) {
      switch (col) {
        case DBColumnSetValue(:final value):
          if (value is firestore.DocumentReference ||
              value is List ||
              value is Map<dynamic, dynamic>) {
            // Forbid FirebaseFirestore-like nested updates, because they
            // are not supported by LocalDB.
            Assert.fail('Nested updates are not allowed. '
                'Document: "$path". Update: "$columns"');
          }
          break;
        case DBColumnDelete():
          break;
      }
    }
  }
}

abstract class DBDocumentSnapshot {
  DBDocumentReference get reference;

  bool get exists => rawData != null;

  bool contains(DBColumn col) => dbContains(rawData!, col);

  bool containsNonNull(DBColumn col) => dbContainsNonNull(rawData!, col);

  T get<T>(DBColumn<T> col) =>
      dbGet(rawData!, col, documentPath: reference.path);

  T? tryGet<T>(DBColumn<T> col) => dbTryGet(rawData!, col);

  List<DBIndexedColumnData<T>> getAll<T, ColumnT extends DBColumnFamily<T>>(
          DBColumnFamilyManager<T, ColumnT> columnFactory) =>
      dbGetAll(rawData!, columnFactory, documentPath: reference.path);

  @override
  String toString() => rawData.toString();

  @protected
  Map<String, dynamic>? get rawData;
}
