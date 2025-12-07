import 'dart:convert';
import 'dart:io';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_router/shelf_router.dart';
import 'package:shelf_cors_headers/shelf_cors_headers.dart';
import 'package:logging/logging.dart';
import 'package:fsp_shared/models.dart';
import 'package:backtest_service/backtest_engine.dart';

final _log = Logger('backtest_service');

void main(List<String> args) async {
  Logger.root.level = Level.INFO;
  Logger.root.onRecord.listen((r) => stdout.writeln('[${r.level.name}] ${r.time.toIso8601String()} ${r.loggerName} - ${r.message}'));

  final port = int.tryParse(Platform.environment['PORT'] ?? '') ?? 8082;
  final router = Router();

  // 헬스 체크 엔드포인트
  router.get('/healthz', (Request req) => Response.ok('ok'));
  router.get('/readyz', (Request req) => Response.ok('ready'));

  // 동기적으로 백테스트 실행
  router.post('/v1/backtests', (Request req) async {
    try {
      final body = await req.readAsString();
      final data = jsonDecode(body) as Map<String, dynamic>;
      
      // 타입을 보장하기 위해 파라미터를 수동으로 추출
      final symbols = List<String>.from(data['symbols']);
      final weights = (data['weights'] as List).map((w) => (w as num).toDouble()).toList();
      final startDate = DateTime.parse(data['startDate']);
      final endDate = DateTime.parse(data['endDate']);
      final initialCapital = (data['initialCapital'] as num).toDouble();
      final dcaAmount = (data['dcaAmount'] as num).toDouble();

      _log.info('Running backtest for $symbols from $startDate to $endDate');

      final result = await runBacktest(
        symbols: symbols,
        weights: weights,
        startDate: startDate,
        endDate: endDate,
        initialCapital: initialCapital,
        dcaAmount: dcaAmount,
      );

      return Response.ok(jsonEncode(result), headers: {'Content-Type': 'application/json'});
    } catch (e, st) {
      _log.severe('Failed to run backtest: $e\n$st');
      return Response.internalServerError(body: jsonEncode({'error': 'backtest_failed', 'details': e.toString()}), headers: {'Content-Type': 'application/json'});
    }
  });

  final handler = const Pipeline()
      .addMiddleware(logRequests())
      .addMiddleware(corsHeaders())
      .addHandler(router);

  final server = await io.serve(handler, InternetAddress.anyIPv4, port);
  _log.info('Backtest service listening on port ${server.port}');
}
