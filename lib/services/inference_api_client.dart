import 'dart:convert';

import 'package:http/http.dart' as http;

class InferenceApiClient {
  const InferenceApiClient({required this.baseUri, http.Client? client})
    : _client = client;

  final Uri baseUri;
  final http.Client? _client;

  Future<Map<String, dynamic>> predictVector(List<double> vector) async {
    final client = _client ?? http.Client();
    final closeClient = _client == null;

    try {
      final response = await client.post(
        baseUri.resolve('/predict'),
        headers: const {'Content-Type': 'application/json'},
        body: jsonEncode({'vector': vector, 'explain': true}),
      );

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw InferenceApiException(
          'Inference API returned ${response.statusCode}: ${response.body}',
        );
      }

      return jsonDecode(response.body) as Map<String, dynamic>;
    } finally {
      if (closeClient) {
        client.close();
      }
    }
  }
}

class InferenceApiException implements Exception {
  const InferenceApiException(this.message);

  final String message;

  @override
  String toString() => message;
}
