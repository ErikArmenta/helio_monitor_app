import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/theme.dart';
import '../models/reading.dart';
import '../providers/readings_provider.dart';
import '../services/ocr_service.dart';

class OcrScreen extends StatefulWidget {
  const OcrScreen({super.key});

  @override
  State<OcrScreen> createState() => _OcrScreenState();
}

class _OcrScreenState extends State<OcrScreen> {
  final _ocrService = OcrService();
  OcrResult? _lastResult;
  bool _scanning = false;
  bool _saved = false;

  final _techController = TextEditingController(text: 'Erik Armenta');
  String _turno = 'Manana';

  Future<void> _scan(bool fromCamera) async {
    setState(() {
      _scanning = true;
      _saved = false;
      _lastResult = null;
    });

    try {
      final result = fromCamera
          ? await _ocrService.scanFromCamera()
          : await _ocrService.scanFromGallery();
      setState(() => _lastResult = result);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error OCR: $e'),
              backgroundColor: EaColors.danger),
        );
      }
    }

    setState(() => _scanning = false);
  }

  Future<void> _saveAsReading() async {
    if (_lastResult == null || !_lastResult!.isComplete) return;

    final reading = Reading(
      technicianName: _techController.text.trim(),
      turno: _turno,
      temperaturaCelsius: _lastResult!.temperature!,
      presionPsi: _lastResult!.pressure!,
      source: 'ocr',
    );

    await context.read<ReadingsProvider>().addReading(reading);
    setState(() => _saved = true);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Lectura OCR guardada'),
          backgroundColor: EaColors.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  @override
  void dispose() {
    _ocrService.dispose();
    _techController.dispose();
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
                              color: EaColors.warning.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.document_scanner_rounded,
                                color: EaColors.warning),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Escaneo OCR',
                                    style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w600)),
                                Text(
                                    'Extrae temperatura y presion de una imagen',
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: EaColors.textSecondary)),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      if (isWide)
                        Row(
                          children: [
                            Expanded(
                              child: _ScanButton(
                                icon: Icons.camera_alt_rounded,
                                label: 'Escanear con Camara',
                                color: EaColors.primary,
                                loading: _scanning,
                                onTap: () => _scan(true),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _ScanButton(
                                icon: Icons.photo_library_rounded,
                                label: 'Seleccionar Imagen',
                                color: EaColors.accent,
                                loading: _scanning,
                                onTap: () => _scan(false),
                              ),
                            ),
                          ],
                        )
                      else ...[
                        _ScanButton(
                          icon: Icons.camera_alt_rounded,
                          label: 'Escanear con Camara',
                          color: EaColors.primary,
                          loading: _scanning,
                          onTap: () => _scan(true),
                        ),
                        const SizedBox(height: 12),
                        _ScanButton(
                          icon: Icons.photo_library_rounded,
                          label: 'Seleccionar Imagen',
                          color: EaColors.accent,
                          loading: _scanning,
                          onTap: () => _scan(false),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              if (_scanning) ...[
                const SizedBox(height: 16),
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Column(
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('Procesando imagen...'),
                      ],
                    ),
                  ),
                ),
              ],
              if (_lastResult != null) ...[
                const SizedBox(height: 16),
                _ResultCard(result: _lastResult!),
                if (_lastResult!.isComplete && !_saved) ...[
                  const SizedBox(height: 16),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Guardar como lectura',
                              style: TextStyle(
                                  fontWeight: FontWeight.w600, fontSize: 15)),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _techController,
                            decoration: const InputDecoration(
                              labelText: 'Tecnico',
                              prefixIcon: Icon(Icons.person_rounded),
                              isDense: true,
                            ),
                          ),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<String>(
                            value: _turno,
                            decoration: const InputDecoration(
                              labelText: 'Turno',
                              prefixIcon: Icon(Icons.schedule_rounded),
                              isDense: true,
                            ),
                            items: ['Manana', 'Tarde', 'Noche']
                                .map((t) => DropdownMenuItem(
                                    value: t, child: Text(t)))
                                .toList(),
                            onChanged: (v) => setState(() => _turno = v!),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _saveAsReading,
                              icon: const Icon(Icons.save_rounded),
                              label: const Text('Guardar Lectura'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                if (_saved)
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Card(
                      color: EaColors.success.withOpacity(0.1),
                      child: const Padding(
                        padding: EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Icon(Icons.check_circle_rounded,
                                color: EaColors.success),
                            SizedBox(width: 12),
                            Text('Lectura OCR guardada exitosamente',
                                style: TextStyle(color: EaColors.success)),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ScanButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool loading;
  final VoidCallback onTap;

  const _ScanButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.loading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: loading ? null : onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(label,
                style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w600,
                    fontSize: 13)),
          ],
        ),
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  final OcrResult result;
  const _ResultCard({required this.result});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('Resultado OCR',
                    style:
                        TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: result.confidence >= 0.7
                        ? EaColors.success.withOpacity(0.15)
                        : EaColors.warning.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Confianza: ${result.confidenceLabel} (${(result.confidence * 100).toStringAsFixed(0)}%)',
                    style: TextStyle(
                      fontSize: 11,
                      color: result.confidence >= 0.7
                          ? EaColors.success
                          : EaColors.warning,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (result.imagePath != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.file(
                  File(result.imagePath!),
                  height: 150,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _ValueBox(
                    label: 'Temperatura',
                    value: result.temperature != null
                        ? '${result.temperature!.toStringAsFixed(2)} C'
                        : 'No detectada',
                    detected: result.temperature != null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _ValueBox(
                    label: 'Presion',
                    value: result.pressure != null
                        ? '${result.pressure!.toStringAsFixed(2)} PSI'
                        : 'No detectada',
                    detected: result.pressure != null,
                  ),
                ),
              ],
            ),
            if (result.rawText.isNotEmpty) ...[
              const SizedBox(height: 16),
              ExpansionTile(
                title: const Text('Texto extraido',
                    style: TextStyle(fontSize: 13)),
                tilePadding: EdgeInsets.zero,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.black26,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: SelectableText(
                      result.rawText,
                      style: const TextStyle(
                          fontSize: 12, fontFamily: 'monospace'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ValueBox extends StatelessWidget {
  final String label;
  final String value;
  final bool detected;

  const _ValueBox({
    required this.label,
    required this.value,
    required this.detected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: detected
            ? EaColors.success.withOpacity(0.08)
            : EaColors.danger.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: detected
              ? EaColors.success.withOpacity(0.2)
              : EaColors.danger.withOpacity(0.2),
        ),
      ),
      child: Column(
        children: [
          Icon(
            detected ? Icons.check_circle_rounded : Icons.error_outline_rounded,
            color: detected ? EaColors.success : EaColors.danger,
            size: 20,
          ),
          const SizedBox(height: 6),
          Text(label,
              style: const TextStyle(
                  fontSize: 11, color: EaColors.textSecondary)),
          const SizedBox(height: 2),
          Text(value,
              style: const TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
