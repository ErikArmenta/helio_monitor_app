import 'dart:io';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';

class OcrService {
  final _textRecognizer = TextRecognizer();
  final _picker = ImagePicker();

  Future<OcrResult> scanFromCamera() async {
    final image = await _picker.pickImage(
      source: ImageSource.camera,
      maxWidth: 1920,
      maxHeight: 1080,
      imageQuality: 90,
    );
    if (image == null) return OcrResult.empty();
    return _processImage(File(image.path));
  }

  Future<OcrResult> scanFromGallery() async {
    final image = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1920,
      maxHeight: 1080,
    );
    if (image == null) return OcrResult.empty();
    return _processImage(File(image.path));
  }

  Future<OcrResult> _processImage(File imageFile) async {
    final inputImage = InputImage.fromFile(imageFile);
    final recognized = await _textRecognizer.processImage(inputImage);

    final rawText = recognized.text;
    double? temperature;
    double? pressure;
    double confidence = 0;

    final numbers = <double>[];
    final numberPattern = RegExp(r'-?\d+\.?\d*');

    for (final block in recognized.blocks) {
      for (final line in block.lines) {
        final text = line.text.toLowerCase();
        final matches = numberPattern.allMatches(text);

        for (final match in matches) {
          final value = double.tryParse(match.group(0) ?? '');
          if (value != null) numbers.add(value);
        }

        if (text.contains('temp') || text.contains('°c') || text.contains('celsius')) {
          for (final match in matches) {
            final value = double.tryParse(match.group(0) ?? '');
            if (value != null && value >= -50 && value <= 200) {
              temperature = value;
              confidence += 0.3;
            }
          }
        }

        if (text.contains('psi') || text.contains('presion') || text.contains('pressure')) {
          for (final match in matches) {
            final value = double.tryParse(match.group(0) ?? '');
            if (value != null && value >= 0 && value <= 5000) {
              pressure = value;
              confidence += 0.3;
            }
          }
        }
      }
    }

    // Heuristic: if no labels found, try to identify by range
    if (temperature == null || pressure == null) {
      for (final num in numbers) {
        if (temperature == null && num >= -50 && num <= 200) {
          temperature = num;
          confidence += 0.1;
        } else if (pressure == null && num >= 10 && num <= 5000) {
          pressure = num;
          confidence += 0.1;
        }
      }
    }

    confidence = confidence.clamp(0.0, 1.0);

    return OcrResult(
      rawText: rawText,
      temperature: temperature,
      pressure: pressure,
      confidence: confidence,
      imagePath: imageFile.path,
    );
  }

  void dispose() {
    _textRecognizer.close();
  }
}

class OcrResult {
  final String rawText;
  final double? temperature;
  final double? pressure;
  final double confidence;
  final String? imagePath;

  const OcrResult({
    required this.rawText,
    this.temperature,
    this.pressure,
    required this.confidence,
    this.imagePath,
  });

  factory OcrResult.empty() => const OcrResult(
        rawText: '',
        confidence: 0,
      );

  bool get hasData => temperature != null || pressure != null;
  bool get isComplete => temperature != null && pressure != null;

  String get confidenceLabel {
    if (confidence >= 0.7) return 'Alta';
    if (confidence >= 0.4) return 'Media';
    return 'Baja';
  }
}
