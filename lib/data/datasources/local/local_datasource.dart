import 'dart:convert';
import 'package:flutter_laundry_offline_app/data/database/database_helper.dart';
import 'package:sqflite/sqflite.dart';

/// Local datasource wrapper for SQLite operations
/// This provides a clean interface for local database operations
/// and will be used alongside RemoteDatasource for sync
class LocalDatasource {
  final DatabaseHelper _dbHelper;

  LocalDatasource({DatabaseHelper? dbHelper})
      : _dbHelper = dbHelper ?? DatabaseHelper.instance;

  Future<Database> get _db => _dbHelper.database;

  // ==================== GENERIC OPERATIONS ====================

  /// Get all records from a table
  Future<List<Map<String, dynamic>>> getAll(
    String table, {
    String? orderBy,
    int? limit,
    int? offset,
  }) async {
    final db = await _db;
    return await db.query(
      table,
      orderBy: orderBy,
      limit: limit,
      offset: offset,
    );
  }

  /// Get records with where clause
  Future<List<Map<String, dynamic>>> getWhere(
    String table, {
    String? where,
    List<Object?>? whereArgs,
    String? orderBy,
    int? limit,
    int? offset,
  }) async {
    final db = await _db;
    return await db.query(
      table,
      where: where,
      whereArgs: whereArgs,
      orderBy: orderBy,
      limit: limit,
      offset: offset,
    );
  }

  /// Get single record by ID
  Future<Map<String, dynamic>?> getById(String table, int id) async {
    final db = await _db;
    final results = await db.query(
      table,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return results.isNotEmpty ? results.first : null;
  }

  /// Insert a record
  Future<int> insert(String table, Map<String, dynamic> data) async {
    final db = await _db;
    return await db.insert(table, data);
  }

  /// Update a record
  Future<int> update(
    String table,
    Map<String, dynamic> data, {
    String? where,
    List<Object?>? whereArgs,
  }) async {
    final db = await _db;
    return await db.update(
      table,
      data,
      where: where,
      whereArgs: whereArgs,
    );
  }

  /// Update record by ID
  Future<int> updateById(
    String table,
    int id,
    Map<String, dynamic> data,
  ) async {
    final db = await _db;
    return await db.update(
      table,
      data,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Delete a record
  Future<int> delete(
    String table, {
    String? where,
    List<Object?>? whereArgs,
  }) async {
    final db = await _db;
    return await db.delete(
      table,
      where: where,
      whereArgs: whereArgs,
    );
  }

  /// Delete record by ID
  Future<int> deleteById(String table, int id) async {
    final db = await _db;
    return await db.delete(
      table,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Execute raw query
  Future<List<Map<String, dynamic>>> rawQuery(
    String sql, [
    List<Object?>? arguments,
  ]) async {
    final db = await _db;
    return await db.rawQuery(sql, arguments);
  }

  /// Execute raw statement (INSERT, UPDATE, DELETE)
  Future<int> rawExecute(String sql, [List<Object?>? arguments]) async {
    final db = await _db;
    return await db.rawInsert(sql, arguments);
  }

  /// Run in transaction
  Future<T> transaction<T>(Future<T> Function(Transaction txn) action) async {
    final db = await _db;
    return await db.transaction(action);
  }

  /// Count records in a table
  Future<int> count(
    String table, {
    String? where,
    List<Object?>? whereArgs,
  }) async {
    final db = await _db;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM $table ${where != null ? 'WHERE $where' : ''}',
      whereArgs,
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  // ==================== SYNC QUEUE OPERATIONS ====================

  /// Add item to sync queue
  Future<int> addToSyncQueue({
    required String tableName,
    required int recordId,
    required String action,
    required Map<String, dynamic> data,
  }) async {
    final db = await _db;

    // Create sync_queue table if not exists (with correct column name 'operation')
    await db.execute('''
      CREATE TABLE IF NOT EXISTS sync_queue (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        table_name TEXT NOT NULL,
        record_id INTEGER NOT NULL,
        operation TEXT NOT NULL,
        data TEXT,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP,
        synced_at TEXT
      )
    ''');

    return await db.insert('sync_queue', {
      'table_name': tableName,
      'record_id': recordId,
      'operation': action,
      'data': jsonEncode(data),
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  /// Get pending sync items
  Future<List<Map<String, dynamic>>> getPendingSyncItems() async {
    final db = await _db;

    // Check if table exists
    final tables = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name='sync_queue'",
    );

    if (tables.isEmpty) return [];

    return await db.query(
      'sync_queue',
      where: 'synced_at IS NULL',
      orderBy: 'created_at ASC',
    );
  }

  /// Mark sync item as synced
  Future<void> markSynced(int syncId) async {
    final db = await _db;
    await db.update(
      'sync_queue',
      {'synced_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [syncId],
    );
  }

  /// Clear synced items
  Future<void> clearSyncedItems() async {
    final db = await _db;
    await db.delete(
      'sync_queue',
      where: 'synced_at IS NOT NULL',
    );
  }
}
