import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../config/theme.dart';
import '../providers/readings_provider.dart';
import '../models/reading.dart';

class ReadingsListScreen extends StatelessWidget {
  const ReadingsListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ReadingsProvider>(
      builder: (context, provider, _) {
        if (provider.loading) {
          return const Center(child: CircularProgressIndicator());
        }

        final readings = provider.filteredReadings;

        if (readings.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.table_chart_outlined,
                    size: 64, color: EaColors.textSecondary.withOpacity(0.3)),
                const SizedBox(height: 16),
                const Text('Sin datos en este rango'),
              ],
            ),
          );
        }

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  Text('${readings.length} registros',
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 16)),
                  const Spacer(),
                  _FilterChips(provider: provider),
                ],
              ),
            ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  if (constraints.maxWidth > 800) {
                    return _WideTable(readings: readings);
                  }
                  return _CompactList(readings: readings);
                },
              ),
            ),
          ],
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
    return SegmentedButton<ViewFilter>(
      segments: const [
        ButtonSegment(value: ViewFilter.last24h, label: Text('24h')),
        ButtonSegment(value: ViewFilter.last7d, label: Text('7d')),
        ButtonSegment(value: ViewFilter.all, label: Text('Todo')),
      ],
      selected: {provider.filter},
      onSelectionChanged: (s) => provider.setFilter(s.first),
      style: ButtonStyle(
        visualDensity: VisualDensity.compact,
        textStyle: WidgetStatePropertyAll(
            TextStyle(fontSize: 12)),
      ),
    );
  }
}

class _WideTable extends StatelessWidget {
  final List<Reading> readings;
  const _WideTable({required this.readings});

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('dd MMM HH:mm');
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Card(
        child: DataTable(
          columnSpacing: 20,
          headingRowColor: WidgetStateProperty.all(
              EaColors.primary.withOpacity(0.08)),
          columns: const [
            DataColumn(label: Text('Tiempo')),
            DataColumn(label: Text('Tecnico')),
            DataColumn(label: Text('Turno')),
            DataColumn(label: Text('Temp C'), numeric: true),
            DataColumn(label: Text('PSI'), numeric: true),
            DataColumn(label: Text('Vol M3'), numeric: true),
            DataColumn(label: Text('Consumo'), numeric: true),
            DataColumn(label: Text('Fuente')),
          ],
          rows: readings.map((r) {
            final isAlert = r.thermodynamics?.isAlert == true;
            return DataRow(
              color: isAlert
                  ? WidgetStateProperty.all(
                      EaColors.danger.withOpacity(0.08))
                  : null,
              cells: [
                DataCell(Text(fmt.format(r.marcaTemporal),
                    style: const TextStyle(fontSize: 12))),
                DataCell(Text(r.technicianName,
                    style: const TextStyle(fontSize: 12))),
                DataCell(Text(r.turno, style: const TextStyle(fontSize: 12))),
                DataCell(Text(r.temperaturaCelsius.toStringAsFixed(2),
                    style: const TextStyle(fontSize: 12))),
                DataCell(Text(r.presionPsi.toStringAsFixed(2),
                    style: const TextStyle(fontSize: 12))),
                DataCell(Text(
                    r.thermodynamics?.volumeCubicMeters.toStringAsFixed(4) ??
                        '--',
                    style: const TextStyle(fontSize: 12))),
                DataCell(Text(
                    r.thermodynamics?.consumoAbsolutoM3.toStringAsFixed(4) ??
                        '--',
                    style: TextStyle(
                      fontSize: 12,
                      color: isAlert ? EaColors.danger : null,
                      fontWeight: isAlert ? FontWeight.w700 : null,
                    ))),
                DataCell(_SourceChip(source: r.source)),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _CompactList extends StatelessWidget {
  final List<Reading> readings;
  const _CompactList({required this.readings});

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('dd MMM HH:mm');
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      itemCount: readings.length,
      itemBuilder: (context, index) {
        final r = readings[index];
        final isAlert = r.thermodynamics?.isAlert == true;
        return Card(
          color: isAlert ? EaColors.danger.withOpacity(0.1) : null,
          margin: const EdgeInsets.symmetric(vertical: 4),
          child: ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: (isAlert ? EaColors.danger : EaColors.primary)
                    .withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                isAlert ? Icons.warning_rounded : Icons.science_rounded,
                color: isAlert ? EaColors.danger : EaColors.primary,
                size: 20,
              ),
            ),
            title: Text(
              '${r.temperaturaCelsius.toStringAsFixed(1)}C | ${r.presionPsi.toStringAsFixed(1)} PSI',
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
            subtitle: Text(
              '${fmt.format(r.marcaTemporal)} | ${r.technicianName} | Vol: ${r.thermodynamics?.volumeCubicMeters.toStringAsFixed(3) ?? '--'} M3',
              style:
                  const TextStyle(fontSize: 11, color: EaColors.textSecondary),
            ),
            trailing: _SourceChip(source: r.source),
          ),
        );
      },
    );
  }
}

class _SourceChip extends StatelessWidget {
  final String source;
  const _SourceChip({required this.source});

  @override
  Widget build(BuildContext context) {
    final config = {
      'manual': (Icons.edit_rounded, EaColors.primary, 'Manual'),
      'esp32': (Icons.sensors_rounded, EaColors.accent, 'ESP32'),
      'ocr': (Icons.document_scanner_rounded, EaColors.warning, 'OCR'),
      'form': (Icons.description_rounded, EaColors.textSecondary, 'Form'),
    };
    final (icon, color, label) = config[source] ?? config['manual']!;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
