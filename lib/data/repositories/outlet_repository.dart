import 'package:flutter_laundry_offline_app/core/constants/app_constants.dart';
import 'package:flutter_laundry_offline_app/data/database/database_helper.dart';
import 'package:flutter_laundry_offline_app/data/models/outlet.dart';

class OutletRepository {
  final DatabaseHelper _databaseHelper;

  OutletRepository({DatabaseHelper? databaseHelper})
      : _databaseHelper = databaseHelper ?? DatabaseHelper.instance;

  /// Get all outlets
  Future<List<Outlet>> getAllOutlets() async {
    final db = await _databaseHelper.database;
    final result = await db.query('outlets', orderBy: 'created_at DESC');
    return result.map((e) => Outlet.fromMap(e)).toList();
  }

  /// Get outlet by id
  Future<Outlet?> getOutletById(int id) async {
    final db = await _databaseHelper.database;
    final result = await db.query(
      'outlets',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (result.isEmpty) return null;
    return Outlet.fromMap(result.first);
  }

  /// Get outlet by remote id
  Future<Outlet?> getOutletByRemoteId(String remoteId) async {
    final db = await _databaseHelper.database;
    final result = await db.query(
      'outlets',
      where: 'remote_id = ?',
      whereArgs: [remoteId],
    );
    if (result.isEmpty) return null;
    return Outlet.fromMap(result.first);
  }

  /// Get current outlet id from settings
  Future<int?> getCurrentOutletId() async {
    final db = await _databaseHelper.database;
    final result = await db.query(
      'app_settings',
      where: 'key = ?',
      whereArgs: [AppConstants.keyCurrentOutletId],
    );
    if (result.isEmpty) return null;
    final value = result.first['value'] as String?;
    return value != null ? int.tryParse(value) : null;
  }

  /// Get current outlet
  Future<Outlet?> getCurrentOutlet() async {
    final currentId = await getCurrentOutletId();
    if (currentId == null) return null;
    return getOutletById(currentId);
  }

  /// Set current outlet id
  Future<void> setCurrentOutletId(int outletId) async {
    final db = await _databaseHelper.database;
    final existing = await db.query(
      'app_settings',
      where: 'key = ?',
      whereArgs: [AppConstants.keyCurrentOutletId],
    );

    if (existing.isNotEmpty) {
      await db.update(
        'app_settings',
        {'value': outletId.toString()},
        where: 'key = ?',
        whereArgs: [AppConstants.keyCurrentOutletId],
      );
    } else {
      await db.insert('app_settings', {
        'key': AppConstants.keyCurrentOutletId,
        'value': outletId.toString(),
      });
    }
  }

  /// Create new outlet
  Future<Outlet> createOutlet(Outlet outlet) async {
    final db = await _databaseHelper.database;
    final now = DateTime.now().toIso8601String();

    final id = await db.insert('outlets', {
      'remote_id': outlet.remoteId,
      'name': outlet.name,
      'address': outlet.address,
      'phone': outlet.phone,
      'invoice_prefix': outlet.invoicePrefix,
      'owner_id': outlet.ownerId,
      'created_at': now,
      'updated_at': now,
    });

    return outlet.copyWith(
      id: id,
      createdAt: DateTime.parse(now),
      updatedAt: DateTime.parse(now),
    );
  }

  /// Update outlet
  Future<Outlet> updateOutlet(Outlet outlet) async {
    if (outlet.id == null) {
      throw Exception('Cannot update outlet without id');
    }

    final db = await _databaseHelper.database;
    final now = DateTime.now().toIso8601String();

    await db.update(
      'outlets',
      {
        'remote_id': outlet.remoteId,
        'name': outlet.name,
        'address': outlet.address,
        'phone': outlet.phone,
        'invoice_prefix': outlet.invoicePrefix,
        'owner_id': outlet.ownerId,
        'updated_at': now,
      },
      where: 'id = ?',
      whereArgs: [outlet.id],
    );

    return outlet.copyWith(updatedAt: DateTime.parse(now));
  }

  /// Delete outlet
  Future<void> deleteOutlet(int id) async {
    final db = await _databaseHelper.database;
    await db.delete('outlets', where: 'id = ?', whereArgs: [id]);
  }

  /// Sync outlet with remote id
  Future<void> linkOutletToRemote(int localId, String remoteId) async {
    final db = await _databaseHelper.database;
    await db.update(
      'outlets',
      {
        'remote_id': remoteId,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [localId],
    );
  }

  /// Get or create default outlet (for migration purposes)
  Future<Outlet> getOrCreateDefaultOutlet() async {
    final outlets = await getAllOutlets();
    if (outlets.isNotEmpty) {
      return outlets.first;
    }

    // Create default outlet
    return createOutlet(Outlet(
      name: AppConstants.defaultLaundryName,
      address: AppConstants.defaultLaundryAddress,
      phone: AppConstants.defaultLaundryPhone,
      invoicePrefix: AppConstants.defaultInvoicePrefix,
    ));
  }
}
