import 'package:connectivity_plus/connectivity_plus.dart';
import 'local_database_service.dart';
import 'supabase_service.dart';
import '../models/reading.dart';

class SyncService {
  final LocalDatabaseService localDb;
  final SupabaseService remote;

  SyncService({required this.localDb, required this.remote});

  Future<bool> get hasConnectivity async {
    final result = await Connectivity().checkConnectivity();
    return result != ConnectivityResult.none;
  }

  Future<SyncResult> syncAll() async {
    if (!await hasConnectivity || !remote.isAvailable) {
      return SyncResult(pushed: 0, pulled: 0, errors: 0, offline: true);
    }

    int pushed = 0;
    int pulled = 0;
    int errors = 0;

    // Push unsynced local readings to Supabase
    final unsynced = await localDb.getUnsyncedReadings();
    for (final reading in unsynced) {
      try {
        await remote.upsertReading(reading);
        await localDb.markSynced(reading.id);
        pushed++;
      } catch (e) {
        errors++;
      }
    }

    // Pull remote readings not in local DB
    try {
      final remoteReadings = await remote.fetchAllReadings();
      for (final reading in remoteReadings) {
        await localDb.insertReadingFromRemote(reading);
        pulled++;
      }
    } catch (e) {
      errors++;
    }

    return SyncResult(pushed: pushed, pulled: pulled, errors: errors);
  }

  Future<int> pushPending() async {
    if (!await hasConnectivity || !remote.isAvailable) return 0;

    final unsynced = await localDb.getUnsyncedReadings();
    int count = 0;
    for (final reading in unsynced) {
      try {
        await remote.upsertReading(reading);
        await localDb.markSynced(reading.id);
        count++;
      } catch (_) {}
    }
    return count;
  }

  Stream<dynamic> get connectivityStream =>
      Connectivity().onConnectivityChanged;
}

class SyncResult {
  final int pushed;
  final int pulled;
  final int errors;
  final bool offline;

  const SyncResult({
    required this.pushed,
    required this.pulled,
    required this.errors,
    this.offline = false,
  });

  String get summary {
    if (offline) return 'Sin conexion - datos guardados localmente';
    final parts = <String>[];
    if (pushed > 0) parts.add('$pushed enviados');
    if (pulled > 0) parts.add('$pulled recibidos');
    if (errors > 0) parts.add('$errors errores');
    return parts.isEmpty ? 'Todo sincronizado' : parts.join(' | ');
  }
}
