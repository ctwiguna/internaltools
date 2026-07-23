import 'package:flutter/foundation.dart';
import 'package:flutter_laundry_offline_app/core/constants/app_constants.dart';
import 'package:flutter_laundry_offline_app/data/database/database_helper.dart';
import 'package:flutter_laundry_offline_app/data/models/outlet.dart';

/// Singleton service to manage current outlet context
class OutletService {
  static final OutletService instance = OutletService._init();
  OutletService._init();

  int? _currentOutletId;
  String? _currentOutletIdStr;
  Outlet? _currentOutlet;

  /// UUID outlet aktif di Supabase (konteks untuk repository online)
  String? _currentOutletUuid;

  int? get currentOutletId => _currentOutletId;
  String? get currentOutletIdStr => _currentOutletIdStr;
  Outlet? get currentOutlet => _currentOutlet;

  /// UUID outlet aktif di Supabase — dipakai repository online
  /// untuk memfilter data per outlet.
  String? get currentOutletUuid => _currentOutletUuid;

  static const String _keyCurrentOutletUuid = 'current_outlet_uuid';

  /// Initialize the service by loading current outlet from settings
  Future<void> initialize() async {
    try {
      await loadCurrentOutlet();
    } catch (e) {
      debugPrint('OutletService.initialize error: $e');
    }
  }

  /// Load current outlet from settings
  Future<void> loadCurrentOutlet() async {
    final db = await DatabaseHelper.instance.database;

    // Load UUID outlet aktif (konteks online) — prioritas utama
    final uuidSettings = await db.query(
      'app_settings',
      where: 'key = ?',
      whereArgs: [_keyCurrentOutletUuid],
    );
    if (uuidSettings.isNotEmpty) {
      _currentOutletUuid = uuidSettings.first['value'] as String?;
    }

    // Get current outlet id from settings
    final settings = await db.query(
      'app_settings',
      where: 'key = ?',
      whereArgs: [AppConstants.keyCurrentOutletId],
    );

    if (settings.isEmpty) {
      // Try to get first outlet as default
      final outlets = await db.query('outlets', limit: 1);
      if (outlets.isNotEmpty) {
        _currentOutletId = outlets.first['id'] as int;
        _currentOutletIdStr = _currentOutletId.toString();
        _currentOutlet = Outlet.fromMap(outlets.first);

        // Save to settings
        await db.insert('app_settings', {
          'key': AppConstants.keyCurrentOutletId,
          'value': _currentOutletIdStr,
        });
      }
      _currentOutletUuid ??= _currentOutlet?.remoteId;
      return;
    }

    final outletIdStr = settings.first['value'] as String?;
    if (outletIdStr == null) {
      _currentOutletUuid ??= _currentOutlet?.remoteId;
      return;
    }

    _currentOutletId = int.tryParse(outletIdStr);
    _currentOutletIdStr = outletIdStr;

    if (_currentOutletId != null) {
      final outlets = await db.query(
        'outlets',
        where: 'id = ?',
        whereArgs: [_currentOutletId],
      );
      if (outlets.isNotEmpty) {
        _currentOutlet = Outlet.fromMap(outlets.first);
      }
    }
    _currentOutletUuid ??= _currentOutlet?.remoteId;
  }

  /// Set current outlet (lokal, int id)
  Future<void> setCurrentOutlet(int outletId) async {
    final db = await DatabaseHelper.instance.database;

    _currentOutletId = outletId;
    _currentOutletIdStr = outletId.toString();

    // Update settings
    final existing = await db.query(
      'app_settings',
      where: 'key = ?',
      whereArgs: [AppConstants.keyCurrentOutletId],
    );

    if (existing.isNotEmpty) {
      await db.update(
        'app_settings',
        {'value': _currentOutletIdStr},
        where: 'key = ?',
        whereArgs: [AppConstants.keyCurrentOutletId],
      );
    } else {
      await db.insert('app_settings', {
        'key': AppConstants.keyCurrentOutletId,
        'value': _currentOutletIdStr,
      });
    }

    // Load outlet details
    final outlets = await db.query(
      'outlets',
      where: 'id = ?',
      whereArgs: [outletId],
    );
    if (outlets.isNotEmpty) {
      _currentOutlet = Outlet.fromMap(outlets.first);
      _currentOutletUuid = _currentOutlet?.remoteId;
      await _persistUuid();
    }
  }

  /// Set current outlet berbasis UUID Supabase (dipakai saat online /
  /// switch outlet oleh owner). Sekaligus mirror outlet ke SQLite lokal
  /// agar konteks int legacy tetap konsisten.
  Future<void> setCurrentOutletRemote(String uuid, {Outlet? outlet}) async {
    final db = await DatabaseHelper.instance.database;

    _currentOutletUuid = uuid;
    await _persistUuid();

    if (outlet == null) return;

    // Mirror outlet ke SQLite lokal (upsert by remote_id)
    final rows = await db.query(
      'outlets',
      where: 'remote_id = ?',
      whereArgs: [uuid],
    );

    int localId;
    if (rows.isEmpty) {
      localId = await db.insert('outlets', {
        'remote_id': uuid,
        'name': outlet.name,
        'address': outlet.address,
        'phone': outlet.phone,
        'invoice_prefix': outlet.invoicePrefix,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });
    } else {
      localId = rows.first['id'] as int;
      await db.update(
        'outlets',
        {
          'name': outlet.name,
          'address': outlet.address,
          'phone': outlet.phone,
          'invoice_prefix': outlet.invoicePrefix,
          'updated_at': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [localId],
      );
    }

    // Sinkronkan juga konteks int legacy (sekaligus persist)
    await setCurrentOutlet(localId);

    // Pastikan UUID aktif tetap yang benar & outlet membawa id lokal mirror
    _currentOutletUuid = uuid;
    await _persistUuid();
    _currentOutlet = outlet.copyWith(id: localId);
  }

  Future<void> _persistUuid() async {
    if (_currentOutletUuid == null) return;
    final db = await DatabaseHelper.instance.database;
    final existing = await db.query(
      'app_settings',
      where: 'key = ?',
      whereArgs: [_keyCurrentOutletUuid],
    );
    if (existing.isNotEmpty) {
      await db.update(
        'app_settings',
        {'value': _currentOutletUuid},
        where: 'key = ?',
        whereArgs: [_keyCurrentOutletUuid],
      );
    } else {
      await db.insert('app_settings', {
        'key': _keyCurrentOutletUuid,
        'value': _currentOutletUuid,
      });
    }
  }

  /// Get current outlet's remote id (for Supabase)
  String? get currentOutletRemoteId => _currentOutlet?.remoteId;
}
