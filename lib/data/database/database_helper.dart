import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:flutter_laundry_offline_app/core/constants/app_constants.dart';
import 'package:flutter_laundry_offline_app/core/utils/password_helper.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB(AppConstants.databaseName);
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: AppConstants.databaseVersion,
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
      onConfigure: _configureDB,
    );
  }

  Future<void> _configureDB(Database db) async {
    // Enable foreign keys
    await db.execute('PRAGMA foreign_keys = ON');
  }

  Future<void> _createDB(Database db, int version) async {
    // Create Outlets table (for multi-outlet support)
    await db.execute('''
      CREATE TABLE outlets (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        remote_id TEXT,
        name TEXT NOT NULL,
        address TEXT,
        phone TEXT,
        invoice_prefix TEXT DEFAULT 'INV',
        owner_id TEXT,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP,
        updated_at TEXT DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    // Create Users table
    await db.execute('''
      CREATE TABLE users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        outlet_id INTEGER,
        username TEXT UNIQUE NOT NULL,
        password_hash TEXT NOT NULL,
        name TEXT NOT NULL,
        role TEXT NOT NULL,
        is_active INTEGER DEFAULT 1,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP,
        updated_at TEXT DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (outlet_id) REFERENCES outlets(id) ON DELETE SET NULL
      )
    ''');

    // Create Customers table
    await db.execute('''
      CREATE TABLE customers (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        remote_id TEXT,
        outlet_id TEXT,
        name TEXT NOT NULL,
        phone TEXT UNIQUE,
        address TEXT,
        notes TEXT,
        total_orders INTEGER DEFAULT 0,
        total_spent INTEGER DEFAULT 0,
        last_order_date TEXT,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP,
        updated_at TEXT DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    // Create Services table
    await db.execute('''
      CREATE TABLE services (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        remote_id TEXT,
        outlet_id TEXT,
        name TEXT NOT NULL,
        unit TEXT NOT NULL,
        price INTEGER NOT NULL,
        duration_days INTEGER DEFAULT 3,
        is_active INTEGER DEFAULT 1,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    // Create Orders table
    await db.execute('''
      CREATE TABLE orders (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        remote_id TEXT,
        outlet_id TEXT,
        invoice_no TEXT UNIQUE NOT NULL,
        customer_id INTEGER,
        customer_name TEXT NOT NULL,
        customer_phone TEXT,
        order_date TEXT NOT NULL,
        due_date TEXT,
        status TEXT NOT NULL,
        total_items INTEGER DEFAULT 0,
        total_weight REAL DEFAULT 0,
        total_price INTEGER NOT NULL,
        paid INTEGER DEFAULT 0,
        notes TEXT,
        created_by INTEGER,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP,
        updated_at TEXT DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (customer_id) REFERENCES customers(id) ON DELETE SET NULL
      )
    ''');

    // Create Order Items table
    await db.execute('''
      CREATE TABLE order_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        remote_id TEXT,
        order_id INTEGER NOT NULL,
        service_id INTEGER,
        service_name TEXT NOT NULL,
        quantity REAL NOT NULL,
        unit TEXT NOT NULL,
        price_per_unit INTEGER NOT NULL,
        subtotal INTEGER NOT NULL,
        FOREIGN KEY (order_id) REFERENCES orders(id) ON DELETE CASCADE,
        FOREIGN KEY (service_id) REFERENCES services(id) ON DELETE SET NULL
      )
    ''');

    // Create Payments table
    await db.execute('''
      CREATE TABLE payments (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        remote_id TEXT,
        order_id INTEGER NOT NULL,
        amount INTEGER NOT NULL,
        change INTEGER DEFAULT 0,
        payment_date TEXT NOT NULL,
        payment_method TEXT NOT NULL,
        notes TEXT,
        received_by INTEGER,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (order_id) REFERENCES orders(id) ON DELETE CASCADE
      )
    ''');

    // Create App Settings table
    await db.execute('''
      CREATE TABLE app_settings (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');

    // Create Sync Queue table for offline-first sync
    await db.execute('''
      CREATE TABLE sync_queue (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        table_name TEXT NOT NULL,
        record_id INTEGER NOT NULL,
        operation TEXT NOT NULL,
        data TEXT,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP,
        synced_at TEXT
      )
    ''');

    // Create indexes
    await _createIndexes(db);

    // Seed default data
    await _seedData(db);
  }

  Future<void> _createIndexes(Database db) async {
    // Outlets indexes
    await db.execute('CREATE INDEX idx_outlets_remote ON outlets(remote_id)');

    // Users indexes
    await db.execute('CREATE INDEX idx_users_username ON users(username)');
    await db.execute('CREATE INDEX idx_users_role ON users(role)');
    await db.execute('CREATE INDEX idx_users_outlet ON users(outlet_id)');

    // Customers indexes
    await db.execute('CREATE INDEX idx_customers_phone ON customers(phone)');
    await db.execute('CREATE INDEX idx_customers_name ON customers(name)');
    await db.execute('CREATE INDEX idx_customers_outlet ON customers(outlet_id)');

    // Services indexes
    await db.execute('CREATE INDEX idx_services_outlet ON services(outlet_id)');

    // Orders indexes
    await db.execute('CREATE INDEX idx_orders_status ON orders(status)');
    await db.execute('CREATE INDEX idx_orders_date ON orders(order_date)');
    await db.execute('CREATE INDEX idx_orders_invoice ON orders(invoice_no)');
    await db.execute('CREATE INDEX idx_orders_customer ON orders(customer_id)');
    await db.execute('CREATE INDEX idx_orders_outlet ON orders(outlet_id)');

    // Order Items indexes
    await db.execute('CREATE INDEX idx_order_items_order ON order_items(order_id)');

    // Payments indexes
    await db.execute('CREATE INDEX idx_payments_order ON payments(order_id)');
    await db.execute('CREATE INDEX idx_payments_date ON payments(payment_date)');

    // v6: modul internal (absen, shift, pengeluaran kas)
    await _createV6Tables(db);

    // v7: pengajuan pembatalan order
    await _createV7Tables(db);
  }

  Future<void> _seedData(Database db) async {
    // Seed default outlet
    final outletId = await db.insert('outlets', {
      'name': AppConstants.defaultLaundryName,
      'address': AppConstants.defaultLaundryAddress,
      'phone': AppConstants.defaultLaundryPhone,
      'invoice_prefix': AppConstants.defaultInvoicePrefix,
    });

    // Seed default owner
    final passwordHash = PasswordHelper.hashPassword(AppConstants.defaultOwnerPassword);
    await db.insert('users', {
      'outlet_id': outletId,
      'username': AppConstants.defaultOwnerUsername,
      'password_hash': passwordHash,
      'name': AppConstants.defaultOwnerName,
      'role': 'owner',
      'is_active': 1,
    });

    // Seed default services for the outlet
    final services = [
      {'name': 'Cuci Kering', 'unit': 'kg', 'price': 8000, 'duration_days': 3},
      {'name': 'Cuci Setrika', 'unit': 'kg', 'price': 10000, 'duration_days': 3},
      {'name': 'Setrika Saja', 'unit': 'kg', 'price': 5000, 'duration_days': 2},
      {'name': 'Cuci Bed Cover', 'unit': 'pcs', 'price': 25000, 'duration_days': 4},
      {'name': 'Cuci Karpet', 'unit': 'pcs', 'price': 35000, 'duration_days': 5},
      {'name': 'Cuci Boneka', 'unit': 'pcs', 'price': 15000, 'duration_days': 3},
    ];

    for (final service in services) {
      await db.insert('services', {
        ...service,
        'outlet_id': outletId.toString(),
        'is_active': 1,
      });
    }

    // Seed default settings
    final settings = {
      AppConstants.keyLaundryName: AppConstants.defaultLaundryName,
      AppConstants.keyLaundryAddress: AppConstants.defaultLaundryAddress,
      AppConstants.keyLaundryPhone: AppConstants.defaultLaundryPhone,
      AppConstants.keyInvoicePrefix: AppConstants.defaultInvoicePrefix,
      AppConstants.keyPrinterAddress: '',
      AppConstants.keyLastInvoiceDate: '',
      AppConstants.keyLastInvoiceNumber: '0',
      AppConstants.keyCurrentOutletId: outletId.toString(),
    };

    for (final entry in settings.entries) {
      await db.insert('app_settings', {
        'key': entry.key,
        'value': entry.value,
      });
    }
  }

  Future<void> _upgradeDB(Database db, int oldVersion, int newVersion) async {
    // Handle migrations here
    if (oldVersion < 2) {
      // Add change column to payments table
      await db.execute('ALTER TABLE payments ADD COLUMN change INTEGER DEFAULT 0');
    }

    if (oldVersion < 3) {
      // Add sync_queue table for offline-first sync
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

      // Add remote_id and outlet_id columns to existing tables
      await db.execute('ALTER TABLE customers ADD COLUMN remote_id TEXT');
      await db.execute('ALTER TABLE customers ADD COLUMN outlet_id TEXT');
      await db.execute('ALTER TABLE services ADD COLUMN remote_id TEXT');
      await db.execute('ALTER TABLE services ADD COLUMN outlet_id TEXT');
      await db.execute('ALTER TABLE orders ADD COLUMN remote_id TEXT');
      await db.execute('ALTER TABLE orders ADD COLUMN outlet_id TEXT');
      await db.execute('ALTER TABLE order_items ADD COLUMN remote_id TEXT');
      await db.execute('ALTER TABLE payments ADD COLUMN remote_id TEXT');
    }

    if (oldVersion < 4) {
      // Recreate orders table without created_by FK constraint
      await db.execute('DROP TABLE IF EXISTS orders_backup');
      await db.execute('''
        CREATE TABLE orders_backup AS SELECT * FROM orders
      ''');
      await db.execute('DROP TABLE orders');
      await db.execute('''
        CREATE TABLE orders (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          remote_id TEXT,
          outlet_id TEXT,
          invoice_no TEXT UNIQUE NOT NULL,
          customer_id INTEGER,
          customer_name TEXT NOT NULL,
          customer_phone TEXT,
          order_date TEXT NOT NULL,
          due_date TEXT,
          status TEXT NOT NULL,
          total_items INTEGER DEFAULT 0,
          total_weight REAL DEFAULT 0,
          total_price INTEGER NOT NULL,
          paid INTEGER DEFAULT 0,
          notes TEXT,
          created_by INTEGER,
          created_at TEXT DEFAULT CURRENT_TIMESTAMP,
          updated_at TEXT DEFAULT CURRENT_TIMESTAMP,
          FOREIGN KEY (customer_id) REFERENCES customers(id) ON DELETE SET NULL
        )
      ''');
      await db.execute('''
        INSERT INTO orders SELECT * FROM orders_backup
      ''');
      await db.execute('DROP TABLE orders_backup');

      // Recreate payments table without received_by FK constraint
      await db.execute('DROP TABLE IF EXISTS payments_backup');
      await db.execute('''
        CREATE TABLE payments_backup AS SELECT * FROM payments
      ''');
      await db.execute('DROP TABLE payments');
      await db.execute('''
        CREATE TABLE payments (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          remote_id TEXT,
          order_id INTEGER NOT NULL,
          amount INTEGER NOT NULL,
          change INTEGER DEFAULT 0,
          payment_date TEXT NOT NULL,
          payment_method TEXT NOT NULL,
          notes TEXT,
          received_by INTEGER,
          created_at TEXT DEFAULT CURRENT_TIMESTAMP,
          FOREIGN KEY (order_id) REFERENCES orders(id) ON DELETE CASCADE
        )
      ''');
      await db.execute('''
        INSERT INTO payments SELECT * FROM payments_backup
      ''');
      await db.execute('DROP TABLE payments_backup');
    }

    if (oldVersion < 5) {
      // Add outlets table for multi-outlet support
      await db.execute('''
        CREATE TABLE IF NOT EXISTS outlets (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          remote_id TEXT,
          name TEXT NOT NULL,
          address TEXT,
          phone TEXT,
          invoice_prefix TEXT DEFAULT 'INV',
          owner_id TEXT,
          created_at TEXT DEFAULT CURRENT_TIMESTAMP,
          updated_at TEXT DEFAULT CURRENT_TIMESTAMP
        )
      ''');

      // Add outlet_id column to users if not exists
      try {
        await db.execute('ALTER TABLE users ADD COLUMN outlet_id INTEGER');
      } catch (_) {
        // Column might already exist
      }

      // Create default outlet from existing settings
      final settings = await db.query('app_settings');
      String laundryName = AppConstants.defaultLaundryName;
      String laundryAddress = AppConstants.defaultLaundryAddress;
      String laundryPhone = AppConstants.defaultLaundryPhone;
      String invoicePrefix = AppConstants.defaultInvoicePrefix;

      for (final setting in settings) {
        final key = setting['key'] as String;
        final value = setting['value'] as String?;
        if (key == AppConstants.keyLaundryName && value != null) {
          laundryName = value;
        } else if (key == AppConstants.keyLaundryAddress && value != null) {
          laundryAddress = value;
        } else if (key == AppConstants.keyLaundryPhone && value != null) {
          laundryPhone = value;
        } else if (key == AppConstants.keyInvoicePrefix && value != null) {
          invoicePrefix = value;
        }
      }

      // Insert default outlet
      final outletId = await db.insert('outlets', {
        'name': laundryName,
        'address': laundryAddress,
        'phone': laundryPhone,
        'invoice_prefix': invoicePrefix,
      });

      // Update all users to belong to this outlet
      await db.update('users', {'outlet_id': outletId});

      // Update all existing data to belong to this outlet
      final outletIdStr = outletId.toString();
      await db.execute('UPDATE customers SET outlet_id = ? WHERE outlet_id IS NULL', [outletIdStr]);
      await db.execute('UPDATE services SET outlet_id = ? WHERE outlet_id IS NULL', [outletIdStr]);
      await db.execute('UPDATE orders SET outlet_id = ? WHERE outlet_id IS NULL', [outletIdStr]);

      // Save current outlet id in settings
      await db.insert(
        'app_settings',
        {'key': AppConstants.keyCurrentOutletId, 'value': outletIdStr},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      // Create indexes for outlets
      await db.execute('CREATE INDEX IF NOT EXISTS idx_outlets_remote ON outlets(remote_id)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_users_outlet ON users(outlet_id)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_customers_outlet ON customers(outlet_id)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_services_outlet ON services(outlet_id)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_orders_outlet ON orders(outlet_id)');
    }

    if (oldVersion < 6) {
      // v6: modul internal (absen + checklist, shift + rekonsiliasi kas,
      // pengeluaran kas per shift)
      await _createV6Tables(db);
    }

    if (oldVersion < 7) {
      // v7: pengajuan pembatalan order
      await _createV7Tables(db);
    }
  }

  /// v6: tabel modul internal. Kolom `uuid` dibuat di client dan menjadi
  /// primary key di tabel cloud — sync memakai UPSERT ber-id ini sehingga
  /// tidak perlu remapping remote_id dan retry selalu idempoten.
  /// Konvensi outlet_id TEXT (id outlet lokal sebagai string) mengikuti
  /// tabel orders/customers yang sudah ada.
  Future<void> _createV6Tables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS attendance (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        uuid TEXT NOT NULL UNIQUE,
        outlet_id TEXT NOT NULL,
        user_id INTEGER,
        user_name TEXT NOT NULL,
        check_in_at TEXT NOT NULL,
        checklist_json TEXT NOT NULL,
        checklist_duration_sec INTEGER,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS shifts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        uuid TEXT NOT NULL UNIQUE,
        outlet_id TEXT NOT NULL,
        user_id INTEGER,
        user_name TEXT NOT NULL,
        status TEXT NOT NULL DEFAULT 'open',
        opened_at TEXT NOT NULL,
        closed_at TEXT,
        opening_cash INTEGER NOT NULL DEFAULT 0,
        cash_sales INTEGER,
        cash_expenses_total INTEGER,
        expected_cash INTEGER,
        actual_cash INTEGER,
        difference INTEGER,
        notes TEXT,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS cash_expenses (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        uuid TEXT NOT NULL UNIQUE,
        outlet_id TEXT NOT NULL,
        shift_uuid TEXT NOT NULL,
        user_name TEXT NOT NULL,
        amount INTEGER NOT NULL,
        description TEXT NOT NULL,
        spent_at TEXT NOT NULL,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_shifts_outlet_status ON shifts(outlet_id, status)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_expenses_shift ON cash_expenses(shift_uuid)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_attendance_outlet ON attendance(outlet_id, check_in_at)');
  }

  /// v7: pengajuan pembatalan order oleh kasir, direview owner.
  /// Mengikuti pola v6 (uuid client-generated = PK cloud, upsert-based sync).
  /// `order_snapshot` menyimpan salinan order+item+payment saat pengajuan
  /// dibuat sehingga tetap bisa ditampilkan sebagai riwayat walau order
  /// aslinya sudah dihapus setelah di-approve.
  Future<void> _createV7Tables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS order_cancellation_requests (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        uuid TEXT NOT NULL UNIQUE,
        outlet_id TEXT NOT NULL,
        order_local_id INTEGER,
        order_remote_id TEXT,
        invoice_no TEXT NOT NULL,
        customer_name TEXT NOT NULL,
        customer_phone TEXT,
        total_price INTEGER NOT NULL,
        paid INTEGER NOT NULL DEFAULT 0,
        order_snapshot TEXT NOT NULL,
        reason TEXT,
        status TEXT NOT NULL DEFAULT 'pending',
        requested_by INTEGER,
        requested_by_remote_id TEXT,
        requested_by_name TEXT NOT NULL,
        reviewed_by INTEGER,
        reviewed_by_remote_id TEXT,
        reviewed_by_name TEXT,
        review_note TEXT,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP,
        reviewed_at TEXT
      )
    ''');

    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_cancel_requests_outlet_status ON order_cancellation_requests(outlet_id, status)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_cancel_requests_order ON order_cancellation_requests(order_local_id)');
  }

  // Utility methods
  Future<void> close() async {
    final db = await instance.database;
    db.close();
    _database = null;
  }

  Future<void> deleteDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, AppConstants.databaseName);
    await databaseFactory.deleteDatabase(path);
    _database = null;
  }

  Future<void> resetDatabase() async {
    await deleteDatabase();
    await database; // This will recreate the database
  }

  /// Recalculate paid amount for all orders based on payments table
  /// This fixes any data inconsistency where paid column wasn't updated
  Future<int> recalculateOrderPaidAmounts() async {
    final db = await database;

    // Get all orders with their calculated paid amount from payments
    final result = await db.rawQuery('''
      SELECT
        o.id,
        o.total_price,
        o.paid as current_paid,
        COALESCE(SUM(p.amount - COALESCE(p.change, 0)), 0) as calculated_paid
      FROM orders o
      LEFT JOIN payments p ON p.order_id = o.id
      GROUP BY o.id
      HAVING current_paid != calculated_paid OR (current_paid = 0 AND calculated_paid > 0)
    ''');

    int updatedCount = 0;

    for (final row in result) {
      final orderId = row['id'] as int;
      final totalPrice = row['total_price'] as int;
      var calculatedPaid = (row['calculated_paid'] as int?) ?? 0;

      // Cap at total_price
      if (calculatedPaid > totalPrice) {
        calculatedPaid = totalPrice;
      }

      await db.update(
        'orders',
        {'paid': calculatedPaid, 'updated_at': DateTime.now().toIso8601String()},
        where: 'id = ?',
        whereArgs: [orderId],
      );
      updatedCount++;
    }

    return updatedCount;
  }
}
