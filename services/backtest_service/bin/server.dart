import 'dart:convert';
import 'dart:io';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_router/shelf_router.dart';
import 'package:shelf_cors_headers/shelf_cors_headers.dart';
import 'package:logging/logging.dart';
import 'package:fsp_shared/models.dart';

final _log = Logger('backtest_service');

void main(List<String> args) async {
  Logger.root.level = Level.INFO;
  Logger.root.onRecord.listen((r) => stdout.writeln('[${r.level.name}] ${r.time.toIso8601String()} ${r.loggerName} - ${r.message}'));

  final port = int.tryParse(Platform.environment['PORT'] ?? '') ?? 8082;
  final router = Router();

  // Health endpoints
  router.get('/healthz', (Request req) => Response.ok('ok'));
  router.get('/readyz', (Request req) => Response.ok('ready'));

  // Create backtest job
  router.post('/v1/backtests', (Request req) async {
    try {
      final body = await req.readAsString();
      final data = jsonDecode(body) as Map<String, dynamic>;
      final btReq = BacktestRequest.fromJson(data);
      // TODO: enqueue job in Redis / persist to Postgres
      final jobId = DateTime.now().millisecondsSinceEpoch.toString();
      _log.info('Queued backtest job $jobId for ${btReq.symbols}');
      final status = BacktestJobStatus(jobId: jobId, status: 'queued');
      return Response(202, body: jsonEncode(status.toJson()), headers: {'Content-Type': 'application/json'});
    } catch (e, st) {
      _log.severe('Failed to queue backtest: $e\n$st');
      return Response.internalServerError(body: jsonEncode({'error': 'invalid_request'}), headers: {'Content-Type': 'application/json'});
    }
  });

  // Get backtest status placeholder
  router.get('/v1/backtests/<jobId>', (Request req, String jobId) async {
    // TODO: lookup job status from Redis/Postgres
    final status = BacktestJobStatus(jobId: jobId, status: 'queued');
    return Response.ok(jsonEncode(status.toJson()), headers: {'Content-Type': 'application/json'});
  });

  final handler = const Pipeline()
      .addMiddleware(logRequests())
      .addMiddleware(corsHeaders())
      .addHandler(router);

  final server = await io.serve(handler, InternetAddress.anyIPv4, port);
  _log.info('Backtest service listening on port ${server.port}');
}
