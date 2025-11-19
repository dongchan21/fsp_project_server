import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import '../services/insight_service.dart';
import '../services/ai_insight_service.dart';

Router insightRoutes() {
  final router = Router();

  // ✅ /api/insight/analyze
  router.post('/analyze', (Request request) async {
    try {
      final body = await request.readAsString();
      final data = jsonDecode(body);

      print("────────────── 📩 인사이트 분석 요청 수신 ──────────────");
      print(JsonEncoder.withIndent('  ').convert(data));
      print("──────────────────────────────────────────────");

      if (data['summary'] == null) {
        return Response(
          400,
          body: jsonEncode({'error': 'Missing summary field'}),
          headers: {'Content-Type': 'application/json'},
        );
      }

      final result = generateScoreAndAnalysis(data['summary']);
      return Response.ok(
        jsonEncode(result),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e, st) {
      print('❌ Insight Analyze Error: $e\n$st');
      return Response.internalServerError(
        body: jsonEncode({'error': 'Server error', 'details': e.toString()}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  });

  // ✅ /api/insight/ai
  router.post('/ai', (Request request) async {
    try {
      final body = await request.readAsString();
      final data = jsonDecode(body);

      print("────────────── 📩 인사이트(AI) 분석 요청 수신 ──────────────");
      print(JsonEncoder.withIndent('  ').convert(data));
      print("──────────────────────────────────────────────");

      if (data['score'] == null ||
          data['analysis'] == null ||
          data['portfolio'] == null) {
        return Response(
          400,
          body: jsonEncode({
            'error': 'Missing required fields: score, analysis, or portfolio'
          }),
          headers: {'Content-Type': 'application/json'},
        );
      }

      final result = await generateAiInsight(data);
      return Response.ok(
        jsonEncode(result),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e, st) {
      print('❌ AI Insight Error: $e\n$st');
      return Response.internalServerError(
        body: jsonEncode({'error': 'Server error', 'details': e.toString()}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  });

  return router;
}
