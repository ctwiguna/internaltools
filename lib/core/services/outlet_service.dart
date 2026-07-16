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

  int? get currentOutletId => _currentOutletId;
  String? get currentOutletIdStr => _currentOutletIdStr;
  Outlet? get currentOutlet => _currentOutlet;

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
      return;
    }

    final outletIdStr = settings.first['value'] as String?;
    if (outletIdStr == null) return;

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
  }

  /// Set current outlet
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
    }
  }

  /// Get current outlet's remote id (for Supabase)
  String? get currentOutletRemoteId => _currentOutlet?.remoteId;
}
