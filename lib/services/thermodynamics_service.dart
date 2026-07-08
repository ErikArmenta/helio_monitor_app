import '../models/reading.dart';

class ThermodynamicsService {
  static const double baseVolume = 450.0;

  static ThermodynamicResult compute(double tempC, double pressurePsi) {
    final tempF = tempC * 1.8 + 32;
    final vesselPressure = pressurePsi + 14.7;
    final tTerm = 459.7 + tempF;

    final part1 = 0.000102297 -
        (0.000000192998 * tTerm) +
        (0.00000000011836 * (tTerm * tTerm));
    final zFactor =
        1 + (part1 * vesselPressure) - (0.0000000002217 * (vesselPressure * vesselPressure));

    final fTemp = 529.7 / (tempF + 459.7);
    final fPres = vesselPressure / 14.7;
    final fComp = 1.00049 / zFactor;
    final fExpMetal = 1 + (0.0000189 * (tempF - 70));
    final fPresEfect = 1 + (0.00000074 * vesselPressure);
    final fv = fTemp * fPres * fComp * fExpMetal * fPresEfect;

    final volFt3 = baseVolume * fv;
    final volM3 = volFt3 / 35.315;

    return ThermodynamicResult(
      compressibilityFactorZ: zFactor,
      volumeFactorFv: fv,
      volumeHeliumFt3: volFt3,
      volumeCubicMeters: volM3,
      diferenciaM3: 0,
      consumoAbsolutoM3: 0,
    );
  }

  static List<Reading> computeAll(List<Reading> readings) {
    readings.sort((a, b) => a.marcaTemporal.compareTo(b.marcaTemporal));

    for (int i = 0; i < readings.length; i++) {
      final r = readings[i];
      final result = compute(r.temperaturaCelsius, r.presionPsi);

      double diff = 0;
      if (i > 0 && readings[i - 1].thermodynamics != null) {
        diff = result.volumeCubicMeters -
            readings[i - 1].thermodynamics!.volumeCubicMeters;
      }

      r.thermodynamics = ThermodynamicResult(
        compressibilityFactorZ: result.compressibilityFactorZ,
        volumeFactorFv: result.volumeFactorFv,
        volumeHeliumFt3: result.volumeHeliumFt3,
        volumeCubicMeters: result.volumeCubicMeters,
        diferenciaM3: diff,
        consumoAbsolutoM3: diff.abs(),
      );
    }

    return readings;
  }

  static Map<String, double> diagnostics(List<Reading> readings) {
    if (readings.isEmpty) return {};

    final consumos = readings
        .where((r) => r.thermodynamics != null)
        .map((r) => r.thermodynamics!.consumoAbsolutoM3)
        .toList();
    final zFactors = readings
        .where((r) => r.thermodynamics != null)
        .map((r) => r.thermodynamics!.compressibilityFactorZ)
        .toList();
    final pressures = readings.map((r) => r.vesselPressure).toList();

    if (consumos.isEmpty) return {};

    final avgConsumo = consumos.reduce((a, b) => a + b) / consumos.length;
    final maxConsumo = consumos.reduce((a, b) => a > b ? a : b);
    final variance = consumos
            .map((c) => (c - avgConsumo) * (c - avgConsumo))
            .reduce((a, b) => a + b) /
        consumos.length;
    final stdDev = _sqrt(variance);
    final avgZ = zFactors.reduce((a, b) => a + b) / zFactors.length;
    final totalConsumo = consumos.reduce((a, b) => a + b);
    final outliers = consumos.where((c) => c > 5).length;

    pressures.sort();
    final modePressure = pressures[pressures.length ~/ 2];

    return {
      'consumo_medio': avgConsumo,
      'desviacion_estandar': stdDev,
      'max_consumo': maxConsumo,
      'outliers': outliers.toDouble(),
      'presion_frecuente': modePressure,
      'factor_z_promedio': avgZ,
      'consumo_total': totalConsumo,
      'estabilidad': stdDev < 1 ? 98.2 : 75.0,
      'total_muestras': readings.length.toDouble(),
    };
  }

  static double _sqrt(double x) {
    if (x <= 0) return 0;
    double guess = x / 2;
    for (int i = 0; i < 20; i++) {
      guess = (guess + x / guess) / 2;
    }
    return guess;
  }
}
