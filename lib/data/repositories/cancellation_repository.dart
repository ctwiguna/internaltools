import 'package:flutter_laundry_offline_app/core/services/outlet_service.dart';
import 'package:flutter_laundry_offline_app/data/database/database_helper.dart';
import 'package:flutter_laundry_offline_app/data/models/cancellation_request.dart';

/// Repository lokal (SQLite) untuk pengajuan pembatalan order.
class CancellationRepository {
  Future<List<CancellationRequest>> getByOutlet({
    CancellationStatus? status,
    int? requestedBy,
  }) async {
    final db = await DatabaseHelper.instance.database;
    final outletIdStr = OutletService.instance.currentOutletIdStr;
    if (outletIdStr == null) return [];

    final whereClauses = <String>['outlet_id = ?'];
    final whereArgs = <dynamic>[outletIdStr];

    if (status != null) {
      whereClauses.add('status = ?');
      whereArgs.add(status.value);
    }
    if (requestedBy != null) {
      whereClauses.add('requested_by = ?');
      whereArgs.add(requestedBy);
    }

    final rows = await db.query(
      'order_cancellation_requests',
      where: whereClauses.join(' AND '),
      whereArgs: whereArgs,
      orderBy: 'created_at DESC',
    );
    return rows.map((e) => CancellationRequest.fromMap(e)).toList();
  }

  /// Cari pengajuan yang masih pending untuk satu order lokal tertentu.
  Future<CancellationRequest?> getPendingForOrder(int orderLocalId) async {
    final db = await DatabaseHelper.instance.database;
    final rows = await db.query(
      'order_cancellation_requests',
      where: 'order_local_id = ? AND status = ?',
      whereArgs: [orderLocalId, CancellationStatus.pending.value],
      orderBy: 'created_at DESC',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return CancellationRequest.fromMap(rows.first);
  }

  Future<int> insert(CancellationRequest request) async {
    final db = await DatabaseHelper.instance.database;
    final map = request.toMap()..remove('id');
    return db.insert('order_cancellation_requests', map);
  }

  Future<void> updateReview(
    String uuid, {
    required CancellationStatus status,
    int? reviewedBy,
    String? reviewedByRemoteId,
    required String reviewedByName,
    String? reviewNote,
  }) async {
    final db = await DatabaseHelper.instance.database;
    await db.update(
      'order_cancellation_requests',
      {
        'status': status.value,
        'reviewed_by': reviewedBy,
        'reviewed_by_remote_id': reviewedByRemoteId,
        'reviewed_by_name': reviewedByName,
        'review_note': reviewNote,
        'reviewed_at': DateTime.now().toIso8601String(),
      },
      where: 'uuid = ?',
      whereArgs: [uuid],
    );
  }

  Future<CancellationRequest?> getByUuid(String uuid) async {
    final db = await DatabaseHelper.instance.database;
    final rows = await db.query(
      'order_cancellation_requests',
      where: 'uuid = ?',
      whereArgs: [uuid],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return CancellationRequest.fromMap(rows.first);
  }
}
