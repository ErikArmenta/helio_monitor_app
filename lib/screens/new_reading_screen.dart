import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/theme.dart';
import '../models/reading.dart';
import '../providers/readings_provider.dart';
import '../services/thermodynamics_service.dart';

class NewReadingScreen extends StatefulWidget {
  const NewReadingScreen({super.key});

  @override
  State<NewReadingScreen> createState() => _NewReadingScreenState();
}

class _NewReadingScreenState extends State<NewReadingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _technicianController = TextEditingController(text: 'Erik Armenta');
  final _tempController = TextEditingController();
  final _pressureController = TextEditingController();
  String _turno = 'Manana';
  DateTime _fecha = DateTime.now();
  bool _submitting = false;

  // Live preview
  ThermodynamicResult? _preview;

  void _updatePreview() {
    final temp = double.tryParse(_tempController.text);
    final pres = double.tryParse(_pressureController.text);
    if (temp != null && pres != null) {
      setState(() {
        _preview = ThermodynamicsService.compute(temp, pres);
      });
    } else {
      setState(() => _preview = null);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _submitting = true);

    final reading = Reading(
      technicianName: _technicianController.text.trim(),
      turno: _turno,
      temperaturaCelsius: double.parse(_tempController.text),
      presionPsi: double.parse(_pressureController.text),
      fecha: _fecha,
      source: 'manual',
    );

    await context.read<ReadingsProvider>().addReading(reading);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Lectura registrada exitosamente'),
          backgroundColor: EaColors.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      _tempController.clear();
      _pressureController.clear();
      setState(() {
        _submitting = false;
        _preview = null;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _tempController.addListener(_updatePreview);
    _pressureController.addListener(_updatePreview);
  }

  @override
  void dispose() {
    _technicianController.dispose();
    _tempController.dispose();
    _pressureController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isWide = width > 700;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: EaColors.primary.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.edit_note_rounded,
                                  color: EaColors.primary),
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Nueva Lectura',
                                      style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w600)),
                                  Text('Registro manual de datos',
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: EaColors.textSecondary)),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        TextFormField(
                          controller: _technicianController,
                          decoration: const InputDecoration(
                            labelText: 'Nombre del tecnico',
                            prefixIcon: Icon(Icons.person_rounded),
                          ),
                          validator: (v) =>
                              v == null || v.trim().isEmpty ? 'Requerido' : null,
                        ),
                        const SizedBox(height: 16),
                        if (isWide)
                          Row(
                            children: [
                              Expanded(child: _buildDatePicker()),
                              const SizedBox(width: 16),
                              Expanded(child: _buildTurnoDropdown()),
                            ],
                          )
                        else ...[
                          _buildDatePicker(),
                          const SizedBox(height: 16),
                          _buildTurnoDropdown(),
                        ],
                        const SizedBox(height: 16),
                        if (isWide)
                          Row(
                            children: [
                              Expanded(child: _buildTempField()),
                              const SizedBox(width: 16),
                              Expanded(child: _buildPressureField()),
                            ],
                          )
                        else ...[
                          _buildTempField(),
                          const SizedBox(height: 16),
                          _buildPressureField(),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                if (_preview != null) _PreviewCard(preview: _preview!),
                if (_preview != null) const SizedBox(height: 16),
                SizedBox(
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: _submitting ? null : _submit,
                    icon: _submitting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.save_rounded),
                    label: Text(_submitting ? 'Guardando...' : 'Registrar Lectura'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDatePicker() {
    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: _fecha,
          firstDate: DateTime(2020),
          lastDate: DateTime.now().add(const Duration(days: 1)),
        );
        if (picked != null) setState(() => _fecha = picked);
      },
      child: InputDecorator(
        decoration: const InputDecoration(
          labelText: 'Fecha',
          prefixIcon: Icon(Icons.calendar_today_rounded),
        ),
        child: Text(
          '${_fecha.day}/${_fecha.month}/${_fecha.year}',
          style: const TextStyle(fontSize: 15),
        ),
      ),
    );
  }

  Widget _buildTurnoDropdown() {
    return DropdownButtonFormField<String>(
      value: _turno,
      decoration: const InputDecoration(
        labelText: 'Turno',
        prefixIcon: Icon(Icons.schedule_rounded),
      ),
      items: ['Manana', 'Tarde', 'Noche']
          .map((t) => DropdownMenuItem(value: t, child: Text(t)))
          .toList(),
      onChanged: (v) => setState(() => _turno = v!),
    );
  }

  Widget _buildTempField() {
    return TextFormField(
      controller: _tempController,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: const InputDecoration(
        labelText: 'Temperatura (C)',
        prefixIcon: Icon(Icons.thermostat_rounded),
        suffixText: 'C',
      ),
      validator: (v) {
        if (v == null || v.isEmpty) return 'Requerido';
        if (double.tryParse(v) == null) return 'Numero invalido';
        return null;
      },
    );
  }

  Widget _buildPressureField() {
    return TextFormField(
      controller: _pressureController,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: const InputDecoration(
        labelText: 'Presion (PSI)',
        prefixIcon: Icon(Icons.speed_rounded),
        suffixText: 'PSI',
      ),
      validator: (v) {
        if (v == null || v.isEmpty) return 'Requerido';
        if (double.tryParse(v) == null) return 'Numero invalido';
        return null;
      },
    );
  }
}

class _PreviewCard extends StatelessWidget {
  final ThermodynamicResult preview;
  const _PreviewCard({required this.preview});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: EaColors.primary.withOpacity(0.08),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.preview_rounded, color: EaColors.primary, size: 18),
                const SizedBox(width: 8),
                const Text('Vista previa termodinamica',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 24,
              runSpacing: 8,
              children: [
                _PreviewItem('Factor Z', preview.compressibilityFactorZ.toStringAsFixed(6)),
                _PreviewItem('Factor Fv', preview.volumeFactorFv.toStringAsFixed(4)),
                _PreviewItem('Volumen', '${preview.volumeCubicMeters.toStringAsFixed(4)} M3'),
                _PreviewItem('Vol ft3', preview.volumeHeliumFt3.toStringAsFixed(2)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PreviewItem extends StatelessWidget {
  final String label;
  final String value;
  const _PreviewItem(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: EaColors.textSecondary)),
        Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
      ],
    );
  }
}
