import 'dart:convert';
import 'package:http/http.dart' as http;

class AiService {
  String _baseUrl;
  String _model;

  AiService({
    String baseUrl = 'http://localhost:11434',
    String model = 'qwen2.5:7b',
  })  : _baseUrl = baseUrl,
        _model = model;

  void configure({String? baseUrl, String? model}) {
    if (baseUrl != null) _baseUrl = baseUrl;
    if (model != null) _model = model;
  }

  String get currentModel => _model;
  String get currentUrl => _baseUrl;

  static const String systemPrompt = '''
IDENTIDAD:
Eres Jarvis, Master Agent del Helium Recovery System de EA Innovation.
Master Engineer: Erik Armenta.
Lema: "Accuracy is our signature, and innovation is our nature."
Lenguaje: espanol, tecnico, directo.

REGLAS:
- PROHIBIDO inventar numeros. Solo usa datos del SNAPSHOT proporcionado.
- Si no tienes datos, di: "No cuento con esa informacion en el snapshot actual."
- Responde de forma concisa y tecnica.
- Para calculos termodinamicos usa las formulas de EA Innovation:
  Z = 1 + (0.000102297 - 0.000000192998*T_term + 0.00000000011836*T_term^2)*P_vessel - 0.0000000002217*P_vessel^2
  Fv = f_temp * f_pres * f_comp * f_exp_metal * f_pres_efect
  Volumen M3 = (450 * Fv) / 35.315

COLUMNAS DEL SISTEMA:
- Temperatura Celsius, Presion PSI, Vessel Pressure PSIA
- Factor Z, Factor Fv, Volumen M3, Consumo Absoluto M3
''';

  Future<String> chat(
    String userMessage, {
    String? dataSnapshot,
    List<Map<String, String>>? history,
  }) async {
    final messages = <Map<String, String>>[
      {'role': 'system', 'content': systemPrompt},
    ];

    if (history != null) {
      messages.addAll(history.take(6));
    }

    String content = userMessage;
    if (dataSnapshot != null) {
      content = '$dataSnapshot\n\nSOLICITUD: $userMessage';
    }
    messages.add({'role': 'user', 'content': content});

    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl/api/chat'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'model': _model,
              'messages': messages,
              'stream': false,
              'options': {'temperature': 0},
            }),
          )
          .timeout(const Duration(seconds: 60));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['message']['content'] ?? 'Sin respuesta del modelo.';
      }
      return 'Error ${response.statusCode}: No se pudo conectar al modelo.';
    } catch (e) {
      return 'No se pudo conectar al servidor de IA ($_baseUrl). '
          'Verifica que Ollama este ejecutandose con: ollama serve';
    }
  }

  Stream<String> chatStream(
    String userMessage, {
    String? dataSnapshot,
    List<Map<String, String>>? history,
  }) async* {
    final messages = <Map<String, String>>[
      {'role': 'system', 'content': systemPrompt},
    ];

    if (history != null) {
      messages.addAll(history.take(6));
    }

    String content = userMessage;
    if (dataSnapshot != null) {
      content = '$dataSnapshot\n\nSOLICITUD: $userMessage';
    }
    messages.add({'role': 'user', 'content': content});

    try {
      final request = http.Request(
        'POST',
        Uri.parse('$_baseUrl/api/chat'),
      );
      request.headers['Content-Type'] = 'application/json';
      request.body = jsonEncode({
        'model': _model,
        'messages': messages,
        'stream': true,
        'options': {'temperature': 0},
      });

      final streamedResponse =
          await http.Client().send(request).timeout(const Duration(seconds: 60));

      await for (final chunk in streamedResponse.stream.transform(utf8.decoder)) {
        for (final line in chunk.split('\n')) {
          if (line.trim().isEmpty) continue;
          try {
            final data = jsonDecode(line);
            final token = data['message']?['content'] ?? '';
            if (token.isNotEmpty) yield token;
          } catch (_) {}
        }
      }
    } catch (e) {
      yield 'Error de conexion: $e';
    }
  }

  Future<bool> testConnection() async {
    try {
      final response = await http
          .get(Uri.parse('$_baseUrl/api/tags'))
          .timeout(const Duration(seconds: 5));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<List<String>> listModels() async {
    try {
      final response = await http
          .get(Uri.parse('$_baseUrl/api/tags'))
          .timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final models = data['models'] as List;
        return models.map<String>((m) => m['name'] as String).toList();
      }
    } catch (_) {}
    return [];
  }
}
