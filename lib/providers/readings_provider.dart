import 'package:flutter/material.dart';
import '../models/reading.dart';
import '../services/local_database_service.dart';
import '../services/supabase_service.dart';
import '../services/thermodynamics_service.dart';

enum ViewFilter { last24h, last7d, all }

class ReadingsProvider extends ChangeNotifier {
  final LocalDatabaseService _localDb;
  final SupabaseService _remote;

  List<Reading> _readings = [];
  ViewFilter _filter = ViewFilter.last24h;
  bool _loading = false;
  String? _error;

  ReadingsProvider(this._localDb, this._remote) {
    loadReadings();
  }

  List<Reading> get readings => _readings;
  ViewFilter get filter => _filter;
  bool get loading => _loading;
  String? get error => _error;

  List<Reading> get filteredReadings {
    final now = DateTime.now();
    switch (_filter) {
      case ViewFilter.last24h:
        final cutoff = now.subtract(const Duration(hours: 24));
        return _readings
            .where((r) => r.marcaTemporal.isAfter(cutoff))
            .toList();
      case ViewFilter.last7d:
        final cutoff = now.subtract(const Duration(days: 7));
        return _readings
            .where((r) => r.marcaTemporal.isAfter(cutoff))
            .toList();
      case ViewFilter.all:
        return _readings;
    }
  }

  Reading? get lastReading =>
      filteredReadings.isNotEmpty ? filteredReadings.first : null;

  Map<String, double> get diagnostics =>
      ThermodynamicsService.diagnostics(_readings);

  void setFilter(ViewFilter f) {
    _filter = f;
    notifyListeners();
  }

  Future<void> loadReadings() async {
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      // Try remote first
      if (_remote.isAvailable) {
        try {
          final remote = await _remote.fetchAllReadings();
          if (remote.isNotEmpty) {
            _readings = remote;
            // Cache locally
            for (final r in remote) {
              await _localDb.insertReadingFromRemote(r);
            }
            _loading = false;
            notifyListeners();
            return;
          }
        } catch (_) {}
      }

      // Fallback to local
      _readings = await _localDb.getAllReadings();
      if (_readings.isNotEmpty) {
        _readings = ThermodynamicsService.computeAll(_readings);
      }
    } catch (e) {
      _error = e.toString();
    }

    _loading = false;
    notifyListeners();
  }

  Future<void> addReading(Reading reading) async {
    await _localDb.insertReading(reading);

    // Try to push to remote
    if (_remote.isAvailable) {
      try {
        await _remote.insertReading(reading);
        await _localDb.markSynced(reading.id);
      } catch (_) {}
    }

    await loadReadings();
  }

  String buildDataSnapshot() {
    if (_readings.isEmpty) return 'No hay datos disponibles.';

    final last = filteredReadings.isNotEmpty ? filteredReadings.first : _readings.first;
    final thermo = last.thermodynamics;

    final buf = StringBuffer()
      ..writeln('=== SNAPSHOT TIEMPO REAL ===')
      ..writeln('Tiempo: ${last.marcaTemporal}')
      ..writeln('Temperatura: ${last.temperaturaCelsius.toStringAsFixed(2)} C')
      ..writeln('Presion: ${last.presionPsi.toStringAsFixed(2)} PSI')
      ..writeln('Vessel Pressure: ${last.vesselPressure.toStringAsFixed(2)} PSIA');

    if (thermo != null) {
      buf
        ..writeln('Factor Z: ${thermo.compressibilityFactorZ.toStringAsFixed(6)}')
        ..writeln('Volumen M3: ${thermo.volumeCubicMeters.toStringAsFixed(4)}')
        ..writeln('Consumo Absoluto: ${thermo.consumoAbsolutoM3.toStringAsFixed(4)} M3');
    }

    buf.writeln('Total registros: ${_readings.length}');
    buf.writeln('===========================');
    return buf.toString();
  }
}
