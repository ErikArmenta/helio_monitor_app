import 'package:uuid/uuid.dart';

class Reading {
  final String id;
  final DateTime marcaTemporal;
  final String technicianName;
  final DateTime fecha;
  final String turno;
  final double temperaturaCelsius;
  final double presionPsi;
  final String? evidenciaVisualUrl;
  final String source;
  final String? deviceId;
  final bool synced;
  final String? localId;

  // Computed fields
  double get temperaturaFahrenheit => temperaturaCelsius * 1.8 + 32;
  double get vesselPressure => presionPsi + 14.7;

  ThermodynamicResult? thermodynamics;

  Reading({
    String? id,
    DateTime? marcaTemporal,
    required this.technicianName,
    DateTime? fecha,
    required this.turno,
    required this.temperaturaCelsius,
    required this.presionPsi,
    this.evidenciaVisualUrl,
    this.source = 'manual',
    this.deviceId,
    this.synced = false,
    String? localId,
    this.thermodynamics,
  })  : id = id ?? const Uuid().v4(),
        marcaTemporal = marcaTemporal ?? DateTime.now(),
        fecha = fecha ?? DateTime.now(),
        localId = localId ?? const Uuid().v4();

  Map<String, dynamic> toSupabaseMap() => {
        'marca_temporal': marcaTemporal.toIso8601String(),
        'technician_name': technicianName,
        'fecha': '${fecha.year}-${fecha.month.toString().padLeft(2, '0')}-${fecha.day.toString().padLeft(2, '0')}',
        'turno': turno,
        'temperatura_celsius': temperaturaCelsius,
        'presion_psi': presionPsi,
        'evidencia_visual_url': evidenciaVisualUrl,
        'source': source,
        'device_id': deviceId,
        'synced': true,
        'local_id': localId,
      };

  Map<String, dynamic> toSqliteMap() => {
        'id': id,
        'marca_temporal': marcaTemporal.toIso8601String(),
        'technician_name': technicianName,
        'fecha': fecha.toIso8601String(),
        'turno': turno,
        'temperatura_celsius': temperaturaCelsius,
        'presion_psi': presionPsi,
        'evidencia_visual_url': evidenciaVisualUrl,
        'source': source,
        'device_id': deviceId,
        'synced': synced ? 1 : 0,
        'local_id': localId,
      };

  factory Reading.fromSupabase(Map<String, dynamic> map) {
    final r = Reading(
      id: map['id'],
      marcaTemporal: DateTime.parse(map['marca_temporal']),
      technicianName: map['technician_name'] ?? '',
      fecha: DateTime.parse(map['fecha']),
      turno: map['turno'] ?? 'Manana',
      temperaturaCelsius: (map['temperatura_celsius'] as num).toDouble(),
      presionPsi: (map['presion_psi'] as num).toDouble(),
      evidenciaVisualUrl: map['evidencia_visual_url'],
      source: map['source'] ?? 'manual',
      deviceId: map['device_id'],
      synced: true,
      localId: map['local_id'],
    );
    if (map['compressibility_factor_z'] != null) {
      r.thermodynamics = ThermodynamicResult(
        compressibilityFactorZ: (map['compressibility_factor_z'] as num).toDouble(),
        volumeFactorFv: (map['volume_factor_fv'] as num).toDouble(),
        volumeHeliumFt3: (map['volume_helium_ft3'] as num).toDouble(),
        volumeCubicMeters: (map['volume_cubic_meters'] as num).toDouble(),
        diferenciaM3: (map['diferencia_m3'] as num).toDouble(),
        consumoAbsolutoM3: (map['consumo_absoluto_m3'] as num).toDouble(),
      );
    }
    return r;
  }

  factory Reading.fromSqlite(Map<String, dynamic> map) {
    final r = Reading(
      id: map['id'],
      marcaTemporal: DateTime.parse(map['marca_temporal']),
      technicianName: map['technician_name'] ?? '',
      fecha: DateTime.parse(map['fecha']),
      turno: map['turno'] ?? 'Manana',
      temperaturaCelsius: (map['temperatura_celsius'] as num).toDouble(),
      presionPsi: (map['presion_psi'] as num).toDouble(),
      evidenciaVisualUrl: map['evidencia_visual_url'],
      source: map['source'] ?? 'manual',
      deviceId: map['device_id'],
      synced: map['synced'] == 1,
      localId: map['local_id'],
    );
    if (map['compressibility_factor_z'] != null) {
      r.thermodynamics = ThermodynamicResult(
        compressibilityFactorZ: (map['compressibility_factor_z'] as num).toDouble(),
        volumeFactorFv: (map['volume_factor_fv'] as num).toDouble(),
        volumeHeliumFt3: (map['volume_helium_ft3'] as num).toDouble(),
        volumeCubicMeters: (map['volume_cubic_meters'] as num).toDouble(),
        diferenciaM3: (map['diferencia_m3'] as num?)?.toDouble() ?? 0,
        consumoAbsolutoM3: (map['consumo_absoluto_m3'] as num?)?.toDouble() ?? 0,
      );
    }
    return r;
  }
}

class ThermodynamicResult {
  final double compressibilityFactorZ;
  final double volumeFactorFv;
  final double volumeHeliumFt3;
  final double volumeCubicMeters;
  final double diferenciaM3;
  final double consumoAbsolutoM3;

  const ThermodynamicResult({
    required this.compressibilityFactorZ,
    required this.volumeFactorFv,
    required this.volumeHeliumFt3,
    required this.volumeCubicMeters,
    required this.diferenciaM3,
    required this.consumoAbsolutoM3,
  });

  bool get isAlert => consumoAbsolutoM3 > 5;
}
