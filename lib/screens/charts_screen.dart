import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../config/theme.dart';
import '../providers/readings_provider.dart';

class ChartsScreen extends StatefulWidget {
  const ChartsScreen({super.key});

  @override
  State<ChartsScreen> createState() => _ChartsScreenState();
}

class _ChartsScreenState extends State<ChartsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ReadingsProvider>(
      builder: (context, provider, _) {
        final readings = provider.filteredReadings.reversed.toList();

        return Column(
          children: [
            Material(
              color: EaColors.surface,
              child: TabBar(
                controller: _tabController,
                indicatorColor: EaColors.primary,
                labelColor: EaColors.primary,
                unselectedLabelColor: EaColors.textSecondary,
                tabs: const [
                  Tab(icon: Icon(Icons.scatter_plot_rounded), text: 'Dispersion'),
                  Tab(icon: Icon(Icons.bar_chart_rounded), text: 'Presion'),
                  Tab(icon: Icon(Icons.compare_arrows_rounded), text: 'Consumo'),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _ScatterTab(readings: readings, provider: provider),
                  _PressureHistogramTab(readings: readings, provider: provider),
                  _ConsumptionTab(readings: readings, provider: provider),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ScatterTab extends StatelessWidget {
  final List readings;
  final ReadingsProvider provider;
  const _ScatterTab({required this.readings, required this.provider});

  @override
  Widget build(BuildContext context) {
    final all = provider.readings;
    if (all.isEmpty) return const Center(child: Text('Sin datos'));

    final consumos = all
        .where((r) => r.thermodynamics != null)
        .map((r) => r.thermodynamics!.consumoAbsolutoM3)
        .toList();

    if (consumos.isEmpty) return const Center(child: Text('Sin datos'));

    consumos.sort();
    final q1 = consumos[(consumos.length * 0.25).floor()];
    final median = consumos[(consumos.length * 0.5).floor()];
    final q3 = consumos[(consumos.length * 0.75).floor()];
    final max = consumos.last;
    final min = consumos.first;
    final iqr = q3 - q1;
    final outlierThreshold = q3 + 1.5 * iqr;
    final outliers = consumos.where((c) => c > outlierThreshold).length;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Dispersion de Consumo',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                  const SizedBox(height: 8),
                  Text('Analisis estadistico de ${consumos.length} muestras',
                      style: const TextStyle(
                          fontSize: 12, color: EaColors.textSecondary)),
                  const SizedBox(height: 20),
                  _StatRow('Minimo', '${min.toStringAsFixed(4)} M3'),
                  _StatRow('Q1 (25%)', '${q1.toStringAsFixed(4)} M3'),
                  _StatRow('Mediana', '${median.toStringAsFixed(4)} M3'),
                  _StatRow('Q3 (75%)', '${q3.toStringAsFixed(4)} M3'),
                  _StatRow('Maximo', '${max.toStringAsFixed(4)} M3'),
                  const Divider(height: 24),
                  _StatRow('IQR', '${iqr.toStringAsFixed(4)} M3'),
                  _StatRow('Umbral outlier', '${outlierThreshold.toStringAsFixed(4)} M3'),
                  _StatRow('Outliers detectados', '$outliers'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Los puntos fuera del umbral representan consumos atipicos que requieren revision.',
            style: TextStyle(fontSize: 12, color: EaColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _PressureHistogramTab extends StatelessWidget {
  final List readings;
  final ReadingsProvider provider;
  const _PressureHistogramTab(
      {required this.readings, required this.provider});

  @override
  Widget build(BuildContext context) {
    final all = provider.readings;
    if (all.isEmpty) return const Center(child: Text('Sin datos'));

    final pressures = all.map((r) => r.vesselPressure).toList();
    pressures.sort();

    final minP = pressures.first;
    final maxP = pressures.last;
    final range = maxP - minP;
    final binCount = 15;
    final binWidth = range / binCount;

    final bins = List.filled(binCount, 0);
    for (final p in pressures) {
      int idx = ((p - minP) / binWidth).floor();
      if (idx >= binCount) idx = binCount - 1;
      bins[idx]++;
    }

    final maxBin = bins.reduce((a, b) => a > b ? a : b);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Distribucion de Presion',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
              const SizedBox(height: 8),
              Text('Frecuencia operativa en ${pressures.length} lecturas',
                  style: const TextStyle(
                      fontSize: 12, color: EaColors.textSecondary)),
              const SizedBox(height: 20),
              SizedBox(
                height: 300,
                child: BarChart(
                  BarChartData(
                    alignment: BarChartAlignment.spaceAround,
                    maxY: maxBin.toDouble() * 1.1,
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      getDrawingHorizontalLine: (_) =>
                          FlLine(color: Colors.white10, strokeWidth: 1),
                    ),
                    titlesData: FlTitlesData(
                      leftTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: true, reservedSize: 40),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 30,
                          getTitlesWidget: (value, meta) {
                            final idx = value.toInt();
                            if (idx % 3 != 0 || idx >= binCount) {
                              return const SizedBox.shrink();
                            }
                            final label = (minP + idx * binWidth).toStringAsFixed(0);
                            return Text(label,
                                style: const TextStyle(fontSize: 9));
                          },
                        ),
                      ),
                      topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false)),
                      rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false)),
                    ),
                    borderData: FlBorderData(show: false),
                    barGroups: List.generate(binCount, (i) {
                      return BarChartGroupData(
                        x: i,
                        barRods: [
                          BarChartRodData(
                            toY: bins[i].toDouble(),
                            color: EaColors.primary,
                            width: 14,
                            borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(4)),
                          ),
                        ],
                      );
                    }),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ConsumptionTab extends StatelessWidget {
  final List readings;
  final ReadingsProvider provider;
  const _ConsumptionTab({required this.readings, required this.provider});

  @override
  Widget build(BuildContext context) {
    final data = provider.filteredReadings.reversed.toList();
    if (data.isEmpty) return const Center(child: Text('Sin datos'));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Consumo Absoluto',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
              const SizedBox(height: 20),
              SizedBox(
                height: 300,
                child: BarChart(
                  BarChartData(
                    alignment: BarChartAlignment.spaceAround,
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      getDrawingHorizontalLine: (_) =>
                          FlLine(color: Colors.white10, strokeWidth: 1),
                    ),
                    titlesData: const FlTitlesData(
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(showTitles: true, reservedSize: 40),
                      ),
                      bottomTitles: AxisTitles(
                          sideTitles: SideTitles(showTitles: false)),
                      topTitles: AxisTitles(
                          sideTitles: SideTitles(showTitles: false)),
                      rightTitles: AxisTitles(
                          sideTitles: SideTitles(showTitles: false)),
                    ),
                    borderData: FlBorderData(show: false),
                    barGroups: List.generate(data.length, (i) {
                      final consumo =
                          data[i].thermodynamics?.consumoAbsolutoM3 ?? 0;
                      final isAlert = consumo > 5;
                      return BarChartGroupData(
                        x: i,
                        barRods: [
                          BarChartRodData(
                            toY: consumo,
                            color: isAlert ? EaColors.danger : EaColors.accent,
                            width: data.length > 50 ? 4 : 10,
                            borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(3)),
                          ),
                        ],
                      );
                    }),
                    barTouchData: BarTouchData(
                      touchTooltipData: BarTouchTooltipData(
                        getTooltipItem: (group, groupIndex, rod, rodIndex) {
                          final r = data[group.x.toInt()];
                          return BarTooltipItem(
                            '${r.temperaturaCelsius.toStringAsFixed(1)}C\n'
                            '${rod.toY.toStringAsFixed(4)} M3',
                            const TextStyle(
                                fontSize: 11, color: Colors.white),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Container(width: 12, height: 12,
                      decoration: BoxDecoration(
                          color: EaColors.accent, borderRadius: BorderRadius.circular(3))),
                  const SizedBox(width: 6),
                  const Text('Normal', style: TextStyle(fontSize: 11)),
                  const SizedBox(width: 16),
                  Container(width: 12, height: 12,
                      decoration: BoxDecoration(
                          color: EaColors.danger, borderRadius: BorderRadius.circular(3))),
                  const SizedBox(width: 6),
                  const Text('Alerta (> 5 M3)', style: TextStyle(fontSize: 11)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  final String label;
  final String value;
  const _StatRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 13, color: EaColors.textSecondary)),
          Text(value,
              style: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
