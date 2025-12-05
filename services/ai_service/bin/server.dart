import 'dart:convert';
import 'dart:io';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_router/shelf_router.dart';
import 'package:shelf_cors_headers/shelf_cors_headers.dart';
import 'package:logging/logging.dart';
import 'package:ai_service/ai_insight_service.dart';

final _log = Logger('ai_service');

void main(List<String> args) async {
  Logger.root.level = Level.INFO;
  Logger.root.onRecord.listen((r) => stdout.writeln('[${r.level.name}] ${r.time.toIso8601String()} ${r.loggerName} - ${r.message}'));

  final port = int.tryParse(Platform.environment['PORT'] ?? '') ?? 8083;
  final router = Router();

  router.get('/healthz', (Request req) => Response.ok('ok'));
  router.get('/readyz', (Request req) => Response.ok('ready'));

  router.post('/v1/insight/ai', (Request req) async {
    try {
      final body = await req.readAsString();
      final data = jsonDecode(body) as Map<String, dynamic>;
      
      if (!(data.containsKey('score') && data.containsKey('analysis') && data.containsKey('portfolio'))) {
        return Response(400, body: jsonEncode({'error': 'missing_fields'}), headers: {'Content-Type': 'application/json'});
      }

      _log.info('Generating AI insight...');
      final result = await generateAiInsight(data);
      
      if (result.containsKey('error')) {
        return Response.internalServerError(body: jsonEncode(result), headers: {'Content-Type': 'application/json'});
      }

      return Response.ok(jsonEncode(result), headers: {'Content-Type': 'application/json'});
    } catch (e, st) {
      _log.severe('AI endpoint error: $e\n$st');
      return Response.internalServerError(body: jsonEncode({'error': 'server_error', 'details': e.toString()}), headers: {'Content-Type': 'application/json'});
    }
  });

  final handler = const Pipeline()
      .addMiddleware(logRequests())
      .addMiddleware(corsHeaders())
      .addHandler(router);

  final server = await io.serve(handler, InternetAddress.anyIPv4, port);
  _log.info('AI service listening on port ${server.port}');
}
