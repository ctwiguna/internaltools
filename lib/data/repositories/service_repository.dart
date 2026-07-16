import 'package:flutter/foundation.dart';
import 'package:flutter_laundry_offline_app/core/services/connectivity_service.dart';
import 'package:flutter_laundry_offline_app/core/services/outlet_service.dart';
import 'package:flutter_laundry_offline_app/core/services/supabase_service.dart';
import 'package:flutter_laundry_offline_app/core/services/sync_service.dart';
import 'package:flutter_laundry_offline_app/data/database/database_helper.dart';
import 'package:flutter_laundry_offline_app/data/models/service.dart';

class ServiceRepository {
  final DatabaseHelper _databaseHelper;

  ServiceRepository({DatabaseHelper? databaseHelper})
      : _databaseHelper = databaseHelper ?? DatabaseHelper.instance;

  bool get _isOnline => ConnectivityService.instance.isOnline;
  bool get _isAuthenticated => SupabaseService.instance.isAuthenticated;

  /// Get current outlet ID string for filtering
  String? get _currentOutletIdStr => OutletService.instance.currentOutletIdStr;

  /// Get all active services for current outlet
  Future<List<Service>> getAllServices() async {
    final db = await _databaseHelper.database;
    final outletId = _currentOutletIdStr;

    String where = 'is_active = 1';
    List<dynamic>? whereArgs;

    // Filter by outlet if set (or include services without outlet_id for backward compatibility)
    if (outletId != null) {
      where = 'is_active = 1 AND (outlet_id = ? OR outlet_id IS NULL)';
      whereArgs = [outletId];
    }

    final result = await db.query(
      'services',
      where: where,
      whereArgs: whereArgs,
      orderBy: 'name ASC',
    );
    return result.map((map) => Service.fromMap(map)).toList();
  }

  /// Get all services (including inactive) for current outlet
  Future<List<Service>> getAllServicesIncludingInactive() async {
    final db = await _databaseHelper.database;
    final outletId = _currentOutletIdStr;

    String? where;
    List<dynamic>? whereArgs;

    // Filter by outlet if set
    if (outletId != null) {
      where = 'outlet_id = ? OR outlet_id IS NULL';
      whereArgs = [outletId];
    }

    final result = await db.query(
      'services',
      where: where,
      whereArgs: whereArgs,
      orderBy: 'is_active DESC, name ASC',
    );
    return result.map((map) => Service.fromMap(map)).toList();
  }

  /// Get service by ID (with outlet validation)
  Future<Service?> getServiceById(int id) async {
    final db = await _databaseHelper.database;
    final outletId = _currentOutletIdStr;

    String where = 'id = ?';
    List<dynamic> whereArgs = [id];

    // Validate service belongs to current outlet
    if (outletId != null) {
      where = 'id = ? AND (outlet_id = ? OR outlet_id IS NULL)';
      whereArgs = [id, outletId];
    }

    final result = await db.query(
      'services',
      where: where,
      whereArgs: whereArgs,
    );
    if (result.isEmpty) return null;
    return Service.fromMap(result.first);
  }

  /// Create new service
  Future<Service> createService(Service service) async {
    final db = await _databaseHelper.database;

    // Validate
    if (service.name.trim().isEmpty) {
      throw Exception('Nama layanan tidak boleh kosong');
    }
    if (service.price <= 0) {
      throw Exception('Harga harus lebih dari 0');
    }

    final now = DateTime.now().toIso8601String();
    final outletId = _currentOutletIdStr;

    final id = await db.insert('services', {
      'name': service.name.trim(),
      'unit': service.unit.value,
      'price': service.price,
      'duration_days': service.durationDays,
      'outlet_id': outletId,
      'is_active': 1,
      'created_at': now,
    });

    final createdService = service.copyWith(
      id: id,
      isActive: true,
      createdAt: DateTime.now(),
    );

    // Sync to Supabase
    await _syncServiceCreate(createdService);

    return createdService;
  }

  Future<void> _syncServiceCreate(Service service) async {
    if (!_isAuthenticated) return;

    final data = {
      'name': service.name,
      'unit': service.unit.value,
      'price': service.price,
      'duration_days': service.durationDays,
      'is_active': service.isActive,
      'local_id': service.id,
    };

    if (_isOnline) {
      try {
        final outletId = await _getOutletId();
        if (outletId == null) return;

        data['outlet_id'] = outletId;
        data.remove('local_id');
        final result = await SupabaseService.instance.insert('services', data);

        // Update local with remote_id
        final db = await _databaseHelper.database;
        await db.update(
          'services',
          {'remote_id': result['id']},
          where: 'id = ?',
          whereArgs: [service.id],
        );
        debugPrint('Sync: Service created and synced');
      } catch (e) {
        debugPrint('Sync service error: $e');
        await _queueServiceSync(service.id!, data, SyncAction.insert);
      }
    } else {
      await _queueServiceSync(service.id!, data, SyncAction.insert);
    }
  }

  Future<String?> _getOutletId() async {
    try {
      final userId = SupabaseService.instance.currentUser?.id;
      if (userId == null) return null;
      final profile = await SupabaseService.instance.client
          .from('profiles')
          .select('outlet_id')
          .eq('id', userId)
          .single();
      return profile['outlet_id'] as String?;
    } catch (e) {
      return null;
    }
  }

  Future<void> _queueServiceSync(int localId, Map<String, dynamic> data, SyncAction action) async {
    await SyncService.instance.queueForSync(
      table: 'services',
      localId: localId,
      action: action,
      data: data,
    );
    debugPrint('Sync: Service queued for sync');
  }

  /// Update existing service (with outlet validation)
  Future<Service> updateService(Service service) async {
    final db = await _databaseHelper.database;
    final outletId = _currentOutletIdStr;

    if (service.id == null) {
      throw Exception('Service ID tidak ditemukan');
    }

    // Validate
    if (service.name.trim().isEmpty) {
      throw Exception('Nama layanan tidak boleh kosong');
    }
    if (service.price <= 0) {
      throw Exception('Harga harus lebih dari 0');
    }

    // Build where clause with outlet validation
    String where = 'id = ?';
    List<dynamic> whereArgs = [service.id];

    if (outletId != null) {
      where = 'id = ? AND (outlet_id = ? OR outlet_id IS NULL)';
      whereArgs = [service.id, outletId];
    }

    final updateCount = await db.update(
      'services',
      {
        'name': service.name.trim(),
        'unit': service.unit.value,
        'price': service.price,
        'duration_days': service.durationDays,
      },
      where: where,
      whereArgs: whereArgs,
    );

    // If no rows updated, service doesn't belong to current outlet
    if (updateCount == 0) {
      throw Exception('Layanan tidak ditemukan di outlet ini');
    }

    // Sync update to Supabase
    await _syncServiceUpdate(service);

    return service;
  }

  Future<void> _syncServiceUpdate(Service service) async {
    if (!_isAuthenticated) return;

    final db = await _databaseHelper.database;
    final result = await db.query(
      'services',
      columns: ['remote_id'],
      where: 'id = ?',
      whereArgs: [service.id],
    );

    final remoteId = result.isNotEmpty ? result.first['remote_id'] as String? : null;
    if (remoteId == null) return;

    final data = {
      'remote_id': remoteId,
      'name': service.name,
      'unit': service.unit.value,
      'price': service.price,
      'duration_days': service.durationDays,
    };

    if (_isOnline) {
      try {
        await SupabaseService.instance.client
            .from('services')
            .update(data..remove('remote_id'))
            .eq('id', remoteId);
        debugPrint('Sync: Service updated');
      } catch (e) {
        debugPrint('Sync service update error: $e');
        await _queueServiceSync(service.id!, data, SyncAction.update);
      }
    } else {
      await _queueServiceSync(service.id!, data, SyncAction.update);
    }
  }

  /// Soft delete service (set is_active = 0) with outlet validation
  Future<void> deleteService(int id) async {
    final db = await _databaseHelper.database;
    final outletId = _currentOutletIdStr;

    // Build where clause with outlet validation
    String where = 'id = ?';
    List<dynamic> whereArgs = [id];

    if (outletId != null) {
      where = 'id = ? AND (outlet_id = ? OR outlet_id IS NULL)';
      whereArgs = [id, outletId];
    }

    // Get remote_id (with outlet validation)
    final result = await db.query(
      'services',
      columns: ['remote_id'],
      where: where,
      whereArgs: whereArgs,
    );

    // If service doesn't exist or doesn't belong to current outlet, return
    if (result.isEmpty) return;

    final remoteId = result.first['remote_id'] as String?;

    await db.update(
      'services',
      {'is_active': 0},
      where: where,
      whereArgs: whereArgs,
    );

    // Sync soft delete to Supabase
    if (remoteId != null && _isAuthenticated) {
      final data = {'remote_id': remoteId, 'is_active': false};
      if (_isOnline) {
        try {
          await SupabaseService.instance.client
              .from('services')
              .update({'is_active': false})
              .eq('id', remoteId);
          debugPrint('Sync: Service soft deleted');
        } catch (e) {
          debugPrint('Sync service delete error: $e');
          await _queueServiceSync(id, data, SyncAction.update);
        }
      } else {
        await _queueServiceSync(id, data, SyncAction.update);
      }
    }
  }

  /// Restore deleted service (with outlet validation)
  Future<void> restoreService(int id) async {
    final db = await _databaseHelper.database;
    final outletId = _currentOutletIdStr;

    // Build where clause with outlet validation
    String where = 'id = ?';
    List<dynamic> whereArgs = [id];

    if (outletId != null) {
      where = 'id = ? AND (outlet_id = ? OR outlet_id IS NULL)';
      whereArgs = [id, outletId];
    }

    // Get remote_id (with outlet validation)
    final result = await db.query(
      'services',
      columns: ['remote_id'],
      where: where,
      whereArgs: whereArgs,
    );

    // If service doesn't exist or doesn't belong to current outlet, return
    if (result.isEmpty) return;

    final remoteId = result.first['remote_id'] as String?;

    await db.update(
      'services',
      {'is_active': 1},
      where: where,
      whereArgs: whereArgs,
    );

    // Sync restore to Supabase
    if (remoteId != null && _isAuthenticated) {
      final data = {'remote_id': remoteId, 'is_active': true};
      if (_isOnline) {
        try {
          await SupabaseService.instance.client
              .from('services')
              .update({'is_active': true})
              .eq('id', remoteId);
          debugPrint('Sync: Service restored');
        } catch (e) {
          debugPrint('Sync service restore error: $e');
          await _queueServiceSync(id, data, SyncAction.update);
        }
      } else {
        await _queueServiceSync(id, data, SyncAction.update);
      }
    }
  }

  /// Check if service name exists (for validation) - filtered by current outlet
  Future<bool> serviceNameExists(String name, {int? excludeId}) async {
    final db = await _databaseHelper.database;
    final outletId = _currentOutletIdStr;

    String where = 'LOWER(name) = ? AND is_active = 1';
    List<dynamic> whereArgs = [name.toLowerCase().trim()];

    // Filter by outlet to allow same service name in different outlets
    if (outletId != null) {
      where += ' AND (outlet_id = ? OR outlet_id IS NULL)';
      whereArgs.add(outletId);
    }

    if (excludeId != null) {
      where += ' AND id != ?';
      whereArgs.add(excludeId);
    }

    final result = await db.query(
      'services',
      where: where,
      whereArgs: whereArgs,
    );

    return result.isNotEmpty;
  }

  /// Get service count for current outlet
  Future<int> getServiceCount() async {
    final db = await _databaseHelper.database;
    final outletId = _currentOutletIdStr;

    String query = 'SELECT COUNT(*) as count FROM services WHERE is_active = 1';
    List<dynamic> args = [];

    if (outletId != null) {
      query += ' AND (outlet_id = ? OR outlet_id IS NULL)';
      args.add(outletId);
    }

    final result = await db.rawQuery(query, args);
    return result.first['count'] as int;
  }
}
