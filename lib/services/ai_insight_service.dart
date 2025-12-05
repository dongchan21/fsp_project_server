import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

/// Gemini 기반 AI 인사이트 생성 서비스 (Microservice Proxy)
Future<Map<String, dynamic>> generateAiInsight(Map<String, dynamic> body, {http.Client? client, String? apiKey}) async {
  final url = Platform.environment['AI_SERVICE_URL'] ?? 'http://localhost:8083';
  final uri = Uri.parse('$url/v1/insight/ai');

  final clientToUse = client ?? http.Client();
  try {
    final response = await clientToUse.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );

    if (response.statusCode != 200) {
      return {
        "error": "AI Service 요청 실패",
        "status": response.statusCode,
        "response": response.body
      };
    }

    return jsonDecode(response.body) as Map<String, dynamic>;
  } catch (e) {
    return {
      "error": "AI Service 연결 오류",
      "details": e.toString(),
    };
  } finally {
    if (client == null) {
      clientToUse.close();
    }
  }
}
