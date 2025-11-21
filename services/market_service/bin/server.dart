import 'dart:convert';
import 'dart:io';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_router/shelf_router.dart';
import 'package:shelf_cors_headers/shelf_cors_headers.dart';
import 'package:logging/logging.dart';
import '../lib/data/price_repository.dart';
import '../lib/data/exchange_rate_repository.dart';
import 'package:fsp_shared/models.dart';

final _log = Logger('market_service');

void main(List<String> args) async {
  Logger.root.level = Level.INFO;
  Logger.root.onRecord.listen((r) => stdout.writeln('[${r.level.name}] ${r.time.toIso8601String()} ${r.loggerName} - ${r.message}'));

  final port = int.tryParse(Platform.environment['PORT'] ?? '') ?? 8081;
  // Initialize connections first so routes can use them
  _log.info('Connecting to Postgres/Redis ...');
  final pg = await PriceRepository.connectPostgres();
  final redis = await PriceRepository.connectRedis();
  final repo = PriceRepository(pg, redis);
  final fxRepo = ExchangeRateRepository(pg, redis);

  final router = Router();

  router.get('/healthz', (Request req) => Response.ok('ok'));
  router.get('/readyz', (Request req) => Response.ok('ready'));

  
  // Forex endpoint (latest exchange_rate row) via repository with Redis caching
  router.get('/v1/forex', (Request req) async {
    try {
      final pair = (req.url.queryParameters['pair'] ?? 'USDKRW').toUpperCase();
      final latest = await fxRepo.getLatest(pair);
      return Response.ok(jsonEncode(latest), headers: {'Content-Type': 'application/json'});
    } catch (e, st) {
      _log.severe('Forex fetch error: $e\n$st');
      final debug = Platform.environment['DEBUG'] == '1';
      final body = {
        'error': 'forex_fetch_failed',
        if (debug) 'details': e.toString(),
      };
      return Response.internalServerError(body: jsonEncode(body), headers: {'Content-Type': 'application/json'});
    }
  });

  // Forex history endpoint
  router.get('/v1/forex/history', (Request req) async {
    try {
      final pair = (req.url.queryParameters['pair'] ?? 'USDKRW').toUpperCase();
      final startParam = req.url.queryParameters['start'];
      final endParam = req.url.queryParameters['end'];
      if (startParam == null || endParam == null) {
        return Response(400, body: jsonEncode({'error': 'missing_params'}), headers: {'Content-Type': 'application/json'});
      }
      final start = DateTime.parse(startParam);
      final end = DateTime.parse(endParam);
      final list = await fxRepo.getHistory(pair, start, end);
      return Response.ok(jsonEncode(list), headers: {'Content-Type': 'application/json'});
    } catch (e, st) {
      _log.severe('Forex history error: $e\n$st');
      final debug = Platform.environment['DEBUG'] == '1';
      final body = {
        'error': 'forex_history_failed',
        if (debug) 'details': e.toString(),
      };
      return Response.internalServerError(body: jsonEncode(body), headers: {'Content-Type': 'application/json'});
    }
  });

  // Price endpoint with Redis/Postgres + external fallback
  router.get('/v1/price/<symbol>', (Request req, String symbol) async {
    try {
      final quote = await repo.getPrice(symbol.toUpperCase());
      return Response.ok(jsonEncode(quote.toJson()), headers: {'Content-Type': 'application/json'});
    } catch (e, st) {
      _log.severe('Price fetch error for $symbol: $e\n$st');
      final debug = Platform.environment['DEBUG'] == '1';
      final body = {
        'error': 'price_fetch_failed',
        if (debug) 'details': e.toString(),
      };
      return Response.internalServerError(body: jsonEncode(body), headers: {'Content-Type': 'application/json'});
    }
  });

  // Price history endpoint
  router.get('/v1/price/history/<symbol>', (Request req, String symbol) async {
    try {
      final startParam = req.url.queryParameters['start'];
      final endParam = req.url.queryParameters['end'];
      if (startParam == null || endParam == null) {
        return Response(400, body: jsonEncode({'error': 'missing_params'}), headers: {'Content-Type': 'application/json'});
      }
      final start = DateTime.parse(startParam);
      final end = DateTime.parse(endParam);
      final list = await repo.getPriceHistory(symbol.toUpperCase(), start, end);
      return Response.ok(jsonEncode(list), headers: {'Content-Type': 'application/json'});
    } catch (e, st) {
      _log.severe('Price history error for $symbol: $e\n$st');
      final debug = Platform.environment['DEBUG'] == '1';
      final body = {
        'error': 'price_history_failed',
        if (debug) 'details': e.toString(),
      };
      return Response.internalServerError(body: jsonEncode(body), headers: {'Content-Type': 'application/json'});
    }
  });

  final handler = const Pipeline()
      .addMiddleware(logRequests())
      .addMiddleware(corsHeaders())
      .addHandler(router);

  final server = await io.serve(handler, InternetAddress.anyIPv4, port);
  _log.info('Market service listening on port ${server.port}');
}
