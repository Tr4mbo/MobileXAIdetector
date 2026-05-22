import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/detector_models.dart';

class OllamaService {
  const OllamaService({
    this.baseUrl = const String.fromEnvironment(
      'OLLAMA_BASE_URL',
      defaultValue: 'http://127.0.0.1:11434',
    ),
    this.timeout = const Duration(seconds: 90),
    http.Client? client,
  }) : _client = client;

  static const reportModel = 'mxai-xai-report';
  static const chatModel = 'mxai-cyber-chat';

  final String baseUrl;
  final Duration timeout;
  final http.Client? _client;

  Future<String> generateAnalysisReport(ScanResult result) {
    return _generate(model: reportModel, prompt: _reportPrompt(result));
  }

  Future<String> askCyberChat({required String question, ScanResult? result}) {
    return _generate(
      model: chatModel,
      prompt: _chatPrompt(question: question, result: result),
    );
  }

  Future<String> _generate({
    required String model,
    required String prompt,
  }) async {
    final client = _client ?? http.Client();
    final closeClient = _client == null;

    try {
      final response = await client
          .post(
            Uri.parse('$baseUrl/api/generate'),
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode({
              'model': model,
              'prompt': prompt,
              'stream': false,
            }),
          )
          .timeout(timeout);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw OllamaException(
          'Ollama respondio ${response.statusCode}: ${response.body}',
        );
      }

      return _readOllamaResponse(response.body);
    } finally {
      if (closeClient) {
        client.close();
      }
    }
  }

  String _readOllamaResponse(String body) {
    String text;
    try {
      final payload = jsonDecode(body) as Map<String, dynamic>;
      text = payload['response'] as String? ?? '';
    } catch (_) {
      text = body.split('\n').where((line) => line.trim().isNotEmpty).map((
        line,
      ) {
        try {
          final payload = jsonDecode(line) as Map<String, dynamic>;
          return payload['response'] as String? ?? '';
        } catch (_) {
          return '';
        }
      }).join();
    }

    final cleaned = _cleanGeneratedText(text);
    if (_isNotUseful(cleaned)) {
      throw const OllamaException(
        'Ollama respondio sin texto util. Ejecuta scripts\\create_ollama_models.ps1 para recrear mxai-xai-report y mxai-cyber-chat.',
      );
    }

    return cleaned;
  }

  String _cleanGeneratedText(String value) {
    return value
        .replaceAll(RegExp(r'^\s*(A:|Respuesta:|Assistant:)\s*'), '')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trim();
  }

  bool _isNotUseful(String value) {
    if (value.length < 8) {
      return true;
    }

    final compact = value.toLowerCase().replaceAll(RegExp(r'\s+'), '');
    final repeatedFragments = RegExp(
      r'(ll){8,}|(ass){5,}|(\|){6,}|(`l){5,}',
    ).hasMatch(compact);
    return repeatedFragments;
  }

  String _reportPrompt(ScanResult result) {
    final factors = result.localFactors
        .map(
          (factor) =>
              '- ${factor.feature}: impacto ${factor.impact.toStringAsFixed(4)}, evidencia ${factor.evidence}',
        )
        .join('\n');

    return '''
Genera el reporte XAI usando solo estos datos.

Prediccion: ${result.label.displayName}
Probabilidad Malware: ${(result.malwareProbability * 100).toStringAsFixed(1)}%
Probabilidad Benign: ${(result.benignProbability * 100).toStringAsFixed(1)}%
Confianza: ${(result.confidence * 100).toStringAsFixed(1)}%
Fuente: ${result.target.sourceLabel}
Muestra: ${result.target.name}
Detalle: ${result.target.packageName ?? result.target.path ?? 'sin detalle adicional'}
Modo prototipo: ${result.isPrototype}

Factores locales:
$factors
''';
  }

  String _chatPrompt({required String question, required ScanResult? result}) {
    final context = result == null
        ? 'No hay decision del modelo disponible todavia.'
        : '''
Decision actual: ${result.label.displayName}
Probabilidad Malware: ${(result.malwareProbability * 100).toStringAsFixed(1)}%
Probabilidad Benign: ${(result.benignProbability * 100).toStringAsFixed(1)}%
Fuente: ${result.target.sourceLabel}
''';

    return '''
Contexto de MXAI:
$context

Pregunta del usuario:
$question
''';
  }
}

class OllamaException implements Exception {
  const OllamaException(this.message);

  final String message;

  @override
  String toString() => message;
}
