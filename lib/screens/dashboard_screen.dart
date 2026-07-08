import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../config/theme.dart';
import '../providers/readings_provider.dart';
import '../providers/sync_provider.dart';
import '../widgets/kpi_card.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ReadingsProvider>(
      builder: (context, provider, _) {
        if (provider.loading) {
          return const Center(child: CircularProgressIndicator());
        }

        if (provider.filteredReadings.isEmpty) {
          return _EmptyState(onRefresh: provider.loadReadings);
        }

        return RefreshIndicator(
          onRefresh: provider.loadReadings,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _FilterChips(provider: provider),
              const SizedBox(height: 16),
              _SyncBanner(),
              const SizedBox(height: 16),
              _KpiSection(provider: provider),
              const SizedBox(height: 20),
              _VolumeChart(provider: provider),
              const SizedBox(height: 20),
              _MultiVariableChart(provider: provider),
              const SizedBox(height: 20),
              _SystemHealth(provider: provider),
              const SizedBox(height: 30),
              _Footer(),
            ],
          ),
        );
      },
    );
  }
}

class _FilterChips extends StatelessWidget {
  final ReadingsProvider provider;
  const _FilterChips({required this.provider});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final entry in {
          ViewFilter.last24h: '24h',
          ViewFilter.last7d: '7 Dias',
          ViewFilter.all: 'Todo',
        }.entries) ...[
          ChoiceChip(
            label: Text(entry.value),
            selected: provider.filter == entry.key,
            onSelected: (_) => provider.setFilter(entry.key),
            selectedColor: EaColors.primary,
            labelStyle: TextStyle(
              color: provider.filter == entry.key
                  ? Colors.white
                  : EaColors.textSecondary,
              fontSize: 13,
            ),
          ),
          const SizedBox(width: 8),
        ],
      ],
    );
  }
}

class _SyncBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<SyncProvider>(
      builder: (_, sync, __) {
        if (sync.isOnline) return const SizedBox.shrink();
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: EaColors.warning.withOpacity(0.15),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: EaColors.warning.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              const Icon(Icons.cloud_off_rounded, color: EaColors.warning, size: 18),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Modo offline - los datos se guardaran localmente',
                  style: TextStyle(fontSize: 13, color: EaColors.warning),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _KpiSection extends StatelessWidget {
  final ReadingsProvider provider;
  const _KpiSection({required this.provider});

  @override
  Widget build(BuildContext context) {
    final last = provider.lastReading!;
    final thermo = last.thermodynamics;
    final consumo = thermo?.consumoAbsolutoM3 ?? 0;
    final isAlert = consumo > 5;

    return KpiRow(
      cards: [
        KpiCard(
          title: 'Volumen M3',
          value: thermo != null
              ? thermo.volumeCubicMeters.toStringAsFixed(2)
              : '--',
          icon: Icons.science_rounded,
          color: EaColors.primary,
        ),
        KpiCard(
          title: 'Presion Absoluta',
          value: '${last.vesselPressure.toStringAsFixed(1)} PSIA',
          icon: Icons.speed_rounded,
          color: EaColors.accent,
        ),
        KpiCard(
          title: 'Factor Fv',
          value: thermo?.volumeFactorFv.toStringAsFixed(4) ?? '--',
          icon: Icons.functions_rounded,
          color: EaColors.warning,
        ),
        KpiCard(
          title: 'Consumo Neto',
          value: '${consumo.toStringAsFixed(2)} M3',
          subtitle: isAlert ? 'ALTA' : 'OK',
          icon: Icons.local_fire_department_rounded,
          color: isAlert ? EaColors.danger : EaColors.success,
          alert: isAlert,
        ),
      ],
    );
  }
}

class _VolumeChart extends StatelessWidget {
  final ReadingsProvider provider;
  const _VolumeChart({required this.provider});

  @override
  Widget build(BuildContext context) {
    final data = provider.filteredReadings.reversed.toList();
    if (data.isEmpty) return const SizedBox.shrink();

    final spots = <FlSpot>[];
    final alertSpots = <FlSpot>[];

    for (int i = 0; i < data.length; i++) {
      final vol = data[i].thermodynamics?.volumeCubicMeters ?? 0;
      spots.add(FlSpot(i.toDouble(), vol));
      if (data[i].thermodynamics?.isAlert == true) {
        alertSpots.add(FlSpot(i.toDouble(), vol));
      }
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Tendencia de Volumen',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
            const SizedBox(height: 20),
            SizedBox(
              height: 250,
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (_) => FlLine(
                      color: Colors.white10,
                      strokeWidth: 1,
                    ),
                  ),
                  titlesData: const FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: true, reservedSize: 50),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(show: false),
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: true,
                      color: EaColors.primary,
                      barWidth: 2.5,
                      dotData: FlDotData(
                        show: true,
                        getDotPainter: (spot, _, __, ___) {
                          final isAlertDot =
                              alertSpots.any((a) => a.x == spot.x);
                          return FlDotCirclePainter(
                            radius: isAlertDot ? 5 : 3,
                            color: isAlertDot ? EaColors.danger : EaColors.primary,
                            strokeWidth: 0,
                          );
                        },
                      ),
                      belowBarData: BarAreaData(
                        show: true,
                        color: EaColors.primary.withOpacity(0.1),
                      ),
                    ),
                  ],
                  lineTouchData: LineTouchData(
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipItems: (touchedSpots) {
                        return touchedSpots.map((spot) {
                          final idx = spot.x.toInt();
                          if (idx >= data.length) return null;
                          final r = data[idx];
                          return LineTooltipItem(
                            '${r.temperaturaCelsius.toStringAsFixed(1)}C | '
                            '${r.presionPsi.toStringAsFixed(1)} PSI\n'
                            'Vol: ${spot.y.toStringAsFixed(4)} M3',
                            const TextStyle(fontSize: 12, color: Colors.white),
                          );
                        }).toList();
                      },
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MultiVariableChart extends StatelessWidget {
  final ReadingsProvider provider;
  const _MultiVariableChart({required this.provider});

  @override
  Widget build(BuildContext context) {
    final data = provider.filteredReadings.reversed.toList();
    if (data.isEmpty) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Correlacion Multi-Variable',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              children: [
                _LegendDot(color: EaColors.danger, label: 'Presion PSI'),
                _LegendDot(color: EaColors.primary, label: 'Volumen M3'),
                _LegendDot(color: EaColors.warning, label: 'Temp F'),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 250,
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(show: true, drawVerticalLine: false,
                    getDrawingHorizontalLine: (_) => FlLine(color: Colors.white10, strokeWidth: 1)),
                  titlesData: const FlTitlesData(
                    leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 50)),
                    bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(show: false),
                  lineBarsData: [
                    LineChartBarData(
                      spots: List.generate(data.length,
                          (i) => FlSpot(i.toDouble(), data[i].presionPsi)),
                      isCurved: true,
                      color: EaColors.danger,
                      barWidth: 2,
                      dotData: const FlDotData(show: false),
                    ),
                    LineChartBarData(
                      spots: List.generate(
                          data.length,
                          (i) => FlSpot(i.toDouble(),
                              data[i].thermodynamics?.volumeCubicMeters ?? 0)),
                      isCurved: true,
                      color: EaColors.primary,
                      barWidth: 2,
                      dotData: const FlDotData(show: false),
                    ),
                    LineChartBarData(
                      spots: List.generate(data.length,
                          (i) => FlSpot(i.toDouble(), data[i].temperaturaFahrenheit)),
                      isCurved: true,
                      color: EaColors.warning,
                      barWidth: 2,
                      dotData: const FlDotData(show: false),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 10, height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 11, color: EaColors.textSecondary)),
      ],
    );
  }
}

class _SystemHealth extends StatelessWidget {
  final ReadingsProvider provider;
  const _SystemHealth({required this.provider});

  @override
  Widget build(BuildContext context) {
    final diag = provider.diagnostics;
    if (diag.isEmpty) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.health_and_safety_rounded,
                    color: EaColors.success, size: 20),
                const SizedBox(width: 8),
                const Text('Salud del Sistema',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
              ],
            ),
            const SizedBox(height: 16),
            _HealthRow('Z Promedio', diag['factor_z_promedio']?.toStringAsFixed(6) ?? '--'),
            _HealthRow('Consumo Total', '${diag['consumo_total']?.toStringAsFixed(2) ?? '--'} M3'),
            _HealthRow('Estabilidad', '${diag['estabilidad']?.toStringAsFixed(1) ?? '--'}%'),
            _HealthRow('Alertas detectadas', '${diag['outliers']?.toInt() ?? 0}'),
            _HealthRow('Total muestras', '${diag['total_muestras']?.toInt() ?? 0}'),
          ],
        ),
      ),
    );
  }
}

class _HealthRow extends StatelessWidget {
  final String label;
  final String value;
  const _HealthRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: EaColors.textSecondary, fontSize: 13)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
        ],
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        children: [
          const Divider(),
          const SizedBox(height: 8),
          Text('Helium Recovery System v1.4',
              style: TextStyle(color: EaColors.textSecondary, fontSize: 12)),
          const SizedBox(height: 4),
          const Text('Developed by Master Engineer Erik Armenta',
              style: TextStyle(fontSize: 12)),
          const SizedBox(height: 4),
          Text('"Accuracy is our signature, and innovation is our nature."',
              style: TextStyle(
                  color: EaColors.primary,
                  fontSize: 11,
                  fontStyle: FontStyle.italic)),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onRefresh;
  const _EmptyState({required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.science_outlined, size: 80, color: EaColors.primary.withOpacity(0.3)),
            const SizedBox(height: 24),
            const Text('Sin lecturas registradas',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text('Agrega una lectura manual, escanea con OCR\no conecta un sensor ESP32.',
                textAlign: TextAlign.center,
                style: TextStyle(color: EaColors.textSecondary)),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onRefresh,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Recargar'),
            ),
          ],
        ),
      ),
    );
  }
}
