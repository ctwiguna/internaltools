import 'dart:convert';
import 'package:uuid/uuid.dart';
import 'package:flutter_laundry_offline_app/core/services/outlet_service.dart';
import 'package:flutter_laundry_offline_app/core/services/sync_service.dart';
import 'package:flutter_laundry_offline_app/data/database/database_helper.dart';

/// Repository modul internal: absen+checklist, shift+rekonsiliasi kas,
/// pengeluaran kas. Semua tulis ke sqflite dulu (offline-first, mengikuti
/// pola app), lalu antre ke SyncService — jalur upsert baru di sync_service
/// yang sudah dipatch akan mendorongnya ke Supabase.
///
/// SESUAIKAN yang ditandai: nama kolom payments/orders lokal sudah
/// diverifikasi dari restore_service.dart (payments: amount, payment_method,
/// payment_date, change; orders: outlet_id, dst) — tapi cek sekali lagi
/// terhadap database_helper.dart milikmu sebelum jalan.
class OpsRepository {
  static const _uuid = Uuid();

  // ==========================================================================
  // ABSEN + CHECKLIST
  // ==========================================================================

  /// [checklist] = hasil centang dengan timestamp PER ITEM, contoh:
  /// [{'item': 'Lantai dipel', 'checked_at': '2026-07-16T08:01:22'}, ...]
  /// UI-mu harus mencatat waktu setiap centang, bukan waktu submit —
  /// selisih waktu antar-centang adalah sinyal anti bulk-ticking.
  Future<String> checkIn({
    required int? userId,
    required String userName,
    required List<Map<String, String>> checklist,
    required int checklistDurationSec,
  }) async {
    final db = await DatabaseHelper.instance.database;
    final outletIdStr = OutletService.instance.currentOutletIdStr!;
    final uuid = _uuid.v4();
    final now = DateTime.now().toIso8601String();

    final row = {
      'uuid': uuid,
      'outlet_id': outletIdStr,
      'user_id': userId,
      'user_name': userName,
      'check_in_at': now,
      'checklist_json': json.encode(checklist),
      'checklist_duration_sec': checklistDurationSec,
    };
    final localId = await db.insert('attendance', row);

    await SyncService.instance.queueForSync(
      table: 'attendance',
      localId: localId,
      action: SyncAction.insert,
      data: {
        'id': uuid, // PK di cloud = uuid client
        'local_outlet_id': outletIdStr,
        'user_name': userName,
        'check_in_at': now,
        'checklist': checklist, // jsonb di cloud
        'checklist_duration_sec': checklistDurationSec,
      },
    );
    return uuid;
  }

  // ==========================================================================
  // SHIFT
  // ==========================================================================

  /// Ada shift yang masih terbuka di outlet ini? (gate: kasir tidak boleh
  /// buka shift baru / input transaksi tanpa shift terbuka)
  Future<Map<String, dynamic>?> shiftTerbuka() async {
    final db = await DatabaseHelper.instance.database;
    final outletIdStr = OutletService.instance.currentOutletIdStr!;
    final rows = await db.query('shifts',
        where: "outlet_id = ? AND status = 'open'",
        whereArgs: [outletIdStr],
        limit: 1);
    return rows.isEmpty ? null : rows.first;
  }

  Future<String> bukaShift({
    required int? userId,
    required String userName,
    required int openingCash,
  }) async {
    if (await shiftTerbuka() != null) {
      throw Exception('Masih ada shift terbuka. Tutup dulu shift sebelumnya.');
    }
    final db = await DatabaseHelper.instance.database;
    final outletIdStr = OutletService.instance.currentOutletIdStr!;
    final uuid = _uuid.v4();
    final now = DateTime.now().toIso8601String();

    final localId = await db.insert('shifts', {
      'uuid': uuid,
      'outlet_id': outletIdStr,
      'user_id': userId,
      'user_name': userName,
      'status': 'open',
      'opened_at': now,
      'opening_cash': openingCash,
    });

    await SyncService.instance.queueForSync(
      table: 'shifts',
      localId: localId,
      action: SyncAction.insert,
      data: {
        'id': uuid,
        'local_outlet_id': outletIdStr,
        'user_name': userName,
        'status': 'open',
        'opened_at': now,
        'opening_cash': openingCash,
      },
    );
    return uuid;
  }

  // ==========================================================================
  // PENGELUARAN KAS
  // ==========================================================================

  Future<void> catatPengeluaran({
    required String shiftUuid,
    required String userName,
    required int amount,
    required String description,
  }) async {
    final db = await DatabaseHelper.instance.database;
    final outletIdStr = OutletService.instance.currentOutletIdStr!;
    final uuid = _uuid.v4();
    final now = DateTime.now().toIso8601String();

    final localId = await db.insert('cash_expenses', {
      'uuid': uuid,
      'outlet_id': outletIdStr,
      'shift_uuid': shiftUuid,
      'user_name': userName,
      'amount': amount,
      'description': description,
      'spent_at': now,
    });

    await SyncService.instance.queueForSync(
      table: 'cash_expenses',
      localId: localId,
      action: SyncAction.insert,
      data: {
        'id': uuid,
        'local_outlet_id': outletIdStr,
        'shift_id': shiftUuid,
        'user_name': userName,
        'amount': amount,
        'description': description,
        'spent_at': now,
      },
    );
  }

  // ==========================================================================
  // TUTUP SHIFT + REKONSILIASI KAS
  // (porting dari fungsi tutup_shift() Postgres kita, jadi transaksi sqflite)
  // ==========================================================================

  /// expected = opening_cash + penjualan TUNAI selama shift - pengeluaran kas.
  /// difference = actual - expected (minus = kas kurang).
  Future<Map<String, int>> tutupShift({
    required String shiftUuid,
    required int actualCash,
    String? notes,
  }) async {
    final db = await DatabaseHelper.instance.database;
    late Map<String, int> hasil;

    // Transaksi sqflite = pengganti `for update` lock di versi Postgres.
    // sqflite serial per-database, jadi race antar-layar aman.
    await db.transaction((txn) async {
      final shiftRows = await txn.query('shifts',
          where: "uuid = ? AND status = 'open'", whereArgs: [shiftUuid]);
      if (shiftRows.isEmpty) {
        throw Exception('Shift tidak ditemukan atau sudah ditutup.');
      }
      final shift = shiftRows.first;
      final openedAt = shift['opened_at'] as String;
      final outletIdStr = shift['outlet_id'] as String;
      final openingCash = (shift['opening_cash'] as int?) ?? 0;
      final now = DateTime.now().toIso8601String();

      // Penjualan tunai selama shift: dari tabel payments milik app,
      // difilter outlet via join ke orders. Kolom sudah diverifikasi dari
      // restore_service.dart. SESUAIKAN bila database_helper-mu berbeda.
      final cashRows = await txn.rawQuery('''
        SELECT COALESCE(SUM(p.amount - COALESCE(p.change, 0)), 0) AS total
        FROM payments p
        JOIN orders o ON o.id = p.order_id
        WHERE o.outlet_id = ?
          AND p.payment_method = 'cash'
          AND p.payment_date >= ?
          AND p.payment_date <= ?
      ''', [outletIdStr, openedAt, now]);
      final cashSales = (cashRows.first['total'] as num?)?.toInt() ?? 0;

      final expRows = await txn.rawQuery(
        'SELECT COALESCE(SUM(amount),0) AS total FROM cash_expenses WHERE shift_uuid = ?',
        [shiftUuid],
      );
      final expensesTotal = (expRows.first['total'] as num?)?.toInt() ?? 0;

      final expected = openingCash + cashSales - expensesTotal;
      final difference = actualCash - expected;

      await txn.update(
        'shifts',
        {
          'status': 'closed',
          'closed_at': now,
          'cash_sales': cashSales,
          'cash_expenses_total': expensesTotal,
          'expected_cash': expected,
          'actual_cash': actualCash,
          'difference': difference,
          'notes': notes,
        },
        where: 'uuid = ?',
        whereArgs: [shiftUuid],
      );

      hasil = {
        'opening_cash': openingCash,
        'cash_sales': cashSales,
        'cash_expenses_total': expensesTotal,
        'expected_cash': expected,
        'actual_cash': actualCash,
        'difference': difference,
      };
    });

    // Kirim ulang baris shift LENGKAP sebagai upsert (id sama) — inilah
    // trik yang menghindari jalur UPDATE sync yang rapuh.
    final shiftRows = await db
        .query('shifts', where: 'uuid = ?', whereArgs: [shiftUuid], limit: 1);
    final s = shiftRows.first;
    await SyncService.instance.queueForSync(
      table: 'shifts',
      localId: s['id'] as int,
      action: SyncAction.insert, // sengaja insert: branch baru memakai upsert
      data: {
        'id': shiftUuid,
        'local_outlet_id': s['outlet_id'],
        'user_name': s['user_name'],
        'status': 'closed',
        'opened_at': s['opened_at'],
        'closed_at': s['closed_at'],
        'opening_cash': s['opening_cash'],
        'cash_sales': s['cash_sales'],
        'cash_expenses_total': s['cash_expenses_total'],
        'expected_cash': s['expected_cash'],
        'actual_cash': s['actual_cash'],
        'difference': s['difference'],
        'notes': s['notes'],
      },
    );

    return hasil;
  }
}
