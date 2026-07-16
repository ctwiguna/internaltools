import 'package:flutter_laundry_offline_app/core/services/supabase_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Remote datasource wrapper for Supabase operations
/// This provides a clean interface for remote database operations
class RemoteDatasource {
  final SupabaseService _supabase;

  RemoteDatasource({SupabaseService? supabase})
      : _supabase = supabase ?? SupabaseService.instance;

  SupabaseClient get _client => _supabase.client;

  // ==================== GENERIC OPERATIONS ====================

  /// Get all records from a table
  Future<List<Map<String, dynamic>>> getAll(
    String table, {
    String? orderBy,
    bool ascending = true,
    int? limit,
    int? offset,
  }) async {
    PostgrestTransformBuilder query = _client.from(table).select();

    if (orderBy != null) {
      query = query.order(orderBy, ascending: ascending);
    }

    if (limit != null) {
      query = query.limit(limit);
    }

    if (offset != null) {
      query = query.range(offset, offset + (limit ?? 10) - 1);
    }

    final response = await query;
    return List<Map<String, dynamic>>.from(response);
  }

  /// Get records with filter
  Future<List<Map<String, dynamic>>> getWhere(
    String table, {
    required String column,
    required dynamic value,
    String? orderBy,
    bool ascending = true,
    int? limit,
  }) async {
    PostgrestTransformBuilder query = _client.from(table).select().eq(column, value);

    if (orderBy != null) {
      query = query.order(orderBy, ascending: ascending);
    }

    if (limit != null) {
      query = query.limit(limit);
    }

    final response = await query;
    return List<Map<String, dynamic>>.from(response);
  }

  /// Get single record by ID
  Future<Map<String, dynamic>?> getById(String table, String id) async {
    final response = await _client
        .from(table)
        .select()
        .eq('id', id)
        .maybeSingle();
    return response;
  }

  /// Insert a record
  Future<Map<String, dynamic>> insert(
    String table,
    Map<String, dynamic> data,
  ) async {
    final response = await _client
        .from(table)
        .insert(data)
        .select()
        .single();
    return response;
  }

  /// Insert multiple records
  Future<List<Map<String, dynamic>>> insertMany(
    String table,
    List<Map<String, dynamic>> data,
  ) async {
    final response = await _client
        .from(table)
        .insert(data)
        .select();
    return List<Map<String, dynamic>>.from(response);
  }

  /// Update a record by ID
  Future<Map<String, dynamic>> update(
    String table,
    String id,
    Map<String, dynamic> data,
  ) async {
    final response = await _client
        .from(table)
        .update(data)
        .eq('id', id)
        .select()
        .single();
    return response;
  }

  /// Delete a record by ID
  Future<void> delete(String table, String id) async {
    await _client.from(table).delete().eq('id', id);
  }

  /// Upsert (insert or update) a record
  Future<Map<String, dynamic>> upsert(
    String table,
    Map<String, dynamic> data,
  ) async {
    final response = await _client
        .from(table)
        .upsert(data)
        .select()
        .single();
    return response;
  }

  /// Upsert multiple records
  Future<List<Map<String, dynamic>>> upsertMany(
    String table,
    List<Map<String, dynamic>> data,
  ) async {
    final response = await _client
        .from(table)
        .upsert(data)
        .select();
    return List<Map<String, dynamic>>.from(response);
  }

  // ==================== QUERY HELPERS ====================

  /// Get records updated since a timestamp
  Future<List<Map<String, dynamic>>> getUpdatedSince(
    String table,
    DateTime since,
  ) async {
    final response = await _client
        .from(table)
        .select()
        .gte('updated_at', since.toIso8601String())
        .order('updated_at', ascending: true);
    return List<Map<String, dynamic>>.from(response);
  }

  /// Count records in a table
  Future<int> count(String table, {String? column, dynamic value}) async {
    if (column != null && value != null) {
      final response = await _client
          .from(table)
          .select()
          .eq(column, value)
          .count(CountOption.exact);
      return response.count;
    }

    final response = await _client
        .from(table)
        .select()
        .count(CountOption.exact);
    return response.count;
  }

  /// Search records
  Future<List<Map<String, dynamic>>> search(
    String table,
    String column,
    String query, {
    int? limit,
  }) async {
    PostgrestTransformBuilder q = _client
        .from(table)
        .select()
        .ilike(column, '%$query%');

    if (limit != null) {
      q = q.limit(limit);
    }

    final response = await q;
    return List<Map<String, dynamic>>.from(response);
  }

  // ==================== REALTIME ====================

  /// Subscribe to table changes
  RealtimeChannel subscribeToTable(
    String table, {
    void Function(Map<String, dynamic> record)? onInsert,
    void Function(Map<String, dynamic> record)? onUpdate,
    void Function(Map<String, dynamic> record)? onDelete,
  }) {
    return _client
        .channel('public:$table')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: table,
          callback: (payload) {
            if (onInsert != null) {
              onInsert(payload.newRecord);
            }
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: table,
          callback: (payload) {
            if (onUpdate != null) {
              onUpdate(payload.newRecord);
            }
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.delete,
          schema: 'public',
          table: table,
          callback: (payload) {
            if (onDelete != null) {
              onDelete(payload.oldRecord);
            }
          },
        )
        .subscribe();
  }

  /// Unsubscribe from a channel
  Future<void> unsubscribe(RealtimeChannel channel) async {
    await _client.removeChannel(channel);
  }

  // ==================== AUTH HELPERS ====================

  /// Get current user ID
  String? get currentUserId => _supabase.currentUser?.id;

  /// Check if authenticated
  bool get isAuthenticated => _supabase.isAuthenticated;
}
