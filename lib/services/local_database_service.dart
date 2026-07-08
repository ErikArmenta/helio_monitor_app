import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/reading.dart';
import 'thermodynamics_service.dart';

class LocalDatabaseService {
  Database? _db;

  Future<void> initialize() async {
    final dbPath = await getDatabasesPath();
    _db = await openDatabase(
      join(dbPath, 'helium_recovery.db'),
      version: 2,
      onCreate: _createTables,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _createTables(Database db, int version) async {
    await db.execute('''
      CREATE TABLE readings (
        id TEXT PRIMARY KEY,
        marca_temporal TEXT NOT NULL,
        technician_name TEXT NOT NULL,
        fecha TEXT NOT NULL,
        turno TEXT NOT NULL,
        temperatura_celsius REAL NOT NULL,
        presion_psi REAL NOT NULL,
        evidencia_visual_url TEXT,
        source TEXT DEFAULT 'manual',
        device_id TEXT,
        synced INTEGER DEFAULT 0,
        local_id TEXT UNIQUE,
        compressibility_factor_z REAL,
        volume_factor_fv REAL,
        volume_helium_ft3 REAL,
        volume_cubic_meters REAL,
        diferencia_m3 REAL DEFAULT 0,
        consumo_absoluto_m3 REAL DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE chat_history (
        id TEXT PRIMARY KEY,
        created_at TEXT NOT NULL,
        role TEXT NOT NULL,
        content TEXT NOT NULL,
        session_id TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE sync_queue (
        id TEXT PRIMARY KEY,
        created_at TEXT NOT NULL,
        table_name TEXT NOT NULL,
        operation TEXT NOT NULL,
        record_data TEXT NOT NULL,
        synced INTEGER DEFAULT 0,
        retry_count INTEGER DEFAULT 0
      )
    ''');

    await db.execute(
        'CREATE INDEX idx_readings_temporal ON readings(marca_temporal DESC)');
    await db.execute(
        'CREATE INDEX idx_readings_synced ON readings(synced) WHERE synced = 0');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute(
          'ALTER TABLE readings ADD COLUMN compressibility_factor_z REAL');
      await db.execute(
          'ALTER TABLE readings ADD COLUMN volume_factor_fv REAL');
      await db.execute(
          'ALTER TABLE readings ADD COLUMN volume_helium_ft3 REAL');
      await db.execute(
          'ALTER TABLE readings ADD COLUMN volume_cubic_meters REAL');
      await db.execute(
          'ALTER TABLE readings ADD COLUMN diferencia_m3 REAL DEFAULT 0');
      await db.execute(
          'ALTER TABLE readings ADD COLUMN consumo_absoluto_m3 REAL DEFAULT 0');
    }
  }

  Database get db {
    if (_db == null) throw StateError('Database not initialized');
    return _db!;
  }

  Future<void> insertReading(Reading reading) async {
    final thermo = ThermodynamicsService.compute(
      reading.temperaturaCelsius,
      reading.presionPsi,
    );
    reading.thermodynamics = thermo;

    final map = reading.toSqliteMap();
    map['compressibility_factor_z'] = thermo.compressibilityFactorZ;
    map['volume_factor_fv'] = thermo.volumeFactorFv;
    map['volume_helium_ft3'] = thermo.volumeHeliumFt3;
    map['volume_cubic_meters'] = thermo.volumeCubicMeters;

    await db.insert('readings', map,
        conflictAlgorithm: ConflictAlgorithm.replace);
    await _recomputeDifferentials();
  }

  Future<void> _recomputeDifferentials() async {
    final rows = await db.query('readings',
        orderBy: 'marca_temporal ASC',
        columns: ['id', 'volume_cubic_meters']);

    for (int i = 0; i < rows.length; i++) {
      final vol = (rows[i]['volume_cubic_meters'] as num?)?.toDouble() ?? 0;
      double diff = 0;
      if (i > 0) {
        final prevVol =
            (rows[i - 1]['volume_cubic_meters'] as num?)?.toDouble() ?? 0;
        diff = vol - prevVol;
      }
      await db.update(
        'readings',
        {'diferencia_m3': diff, 'consumo_absoluto_m3': diff.abs()},
        where: 'id = ?',
        whereArgs: [rows[i]['id']],
      );
    }
  }

  Future<List<Reading>> getAllReadings() async {
    final rows =
        await db.query('readings', orderBy: 'marca_temporal DESC');
    return rows.map((r) => Reading.fromSqlite(r)).toList();
  }

  Future<List<Reading>> getReadingsSince(DateTime since) async {
    final rows = await db.query(
      'readings',
      where: 'marca_temporal >= ?',
      whereArgs: [since.toIso8601String()],
      orderBy: 'marca_temporal DESC',
    );
    return rows.map((r) => Reading.fromSqlite(r)).toList();
  }

  Future<List<Reading>> getUnsyncedReadings() async {
    final rows = await db.query(
      'readings',
      where: 'synced = 0',
      orderBy: 'marca_temporal ASC',
    );
    return rows.map((r) => Reading.fromSqlite(r)).toList();
  }

  Future<void> markSynced(String id) async {
    await db.update('readings', {'synced': 1},
        where: 'id = ?', whereArgs: [id]);
  }

  Future<void> insertReadingFromRemote(Reading reading) async {
    final map = reading.toSqliteMap();
    map['synced'] = 1;
    if (reading.thermodynamics != null) {
      map['compressibility_factor_z'] =
          reading.thermodynamics!.compressibilityFactorZ;
      map['volume_factor_fv'] = reading.thermodynamics!.volumeFactorFv;
      map['volume_helium_ft3'] = reading.thermodynamics!.volumeHeliumFt3;
      map['volume_cubic_meters'] = reading.thermodynamics!.volumeCubicMeters;
      map['diferencia_m3'] = reading.thermodynamics!.diferenciaM3;
      map['consumo_absoluto_m3'] = reading.thermodynamics!.consumoAbsolutoM3;
    }
    await db.insert('readings', map,
        conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  Future<void> saveChatMessage(
      String id, String role, String content, String sessionId) async {
    await db.insert('chat_history', {
      'id': id,
      'created_at': DateTime.now().toIso8601String(),
      'role': role,
      'content': content,
      'session_id': sessionId,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Map<String, dynamic>>> getChatHistory(String sessionId) async {
    return db.query(
      'chat_history',
      where: 'session_id = ?',
      whereArgs: [sessionId],
      orderBy: 'created_at ASC',
    );
  }

  Future<int> getReadingCount() async {
    final result = await db.rawQuery('SELECT COUNT(*) as c FROM readings');
    return result.first['c'] as int;
  }
}
