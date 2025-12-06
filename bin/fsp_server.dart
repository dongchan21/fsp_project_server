import 'dart:io';
import 'dart:isolate';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_router/shelf_router.dart';
import 'package:shelf_cors_headers/shelf_cors_headers.dart';
import 'package:dotenv/dotenv.dart'; // dotenv 패키지

import 'package:fsp_server/routes/backtest_routes.dart';
import 'package:fsp_server/routes/insight_routes.dart';
import 'package:fsp_server/routes/stock_routes.dart';
import 'package:fsp_server/routes/auth_routes.dart';
import 'package:fsp_server/routes/board_routes.dart';
import 'package:fsp_server/utils/db_utils.dart';
import 'package:http/http.dart' as http;

void main() async {
  // .env 파일 로드 (메인 아이솔레이트)
  final env = DotEnv(includePlatformEnvironment: true)..load();

  // DB 초기화 (메인 아이솔레이트에서 한 번만 실행)
  try {
    await DbUtils.initTables();
    print('✅ Database initialized');
  } catch (e) {
    print('❌ Database initialization failed: $e');
  }

  // CPU 코어 수 확인
  final int workers = Platform.numberOfProcessors;
  print('🚀 Starting server with $workers threads (Isolates)...');

  // 워커 아이솔레이트 생성 (메인 아이솔레이트 제외하고 나머지 코어 수만큼 생성)
  for (var i = 0; i < workers - 1; i++) {
    Isolate.spawn(_startServer, i + 1);
  }

  // 메인 아이솔레이트에서도 서버 실행 (ID: 0)
  _startServer(0);
}

// 각 아이솔레이트에서 실행될 서버 로직
void _startServer(int id) async {
  // 각 아이솔레이트마다 환경변수 로드 필요
  final env = DotEnv(includePlatformEnvironment: true)..load();

  // 라우터 생성 및 백테스트 경로 등록
  final router = Router()..mount('/api/backtest/', BacktestRoutes().router);
  router.mount('/api/insight/', insightRoutes());
  router.mount('/api/stocks/', StockRoutes().router);
  router.mount('/api/auth/', AuthRoutes().router);
  router.mount('/api/board/', BoardRoutes().router);

  // 미들웨어 설정
  final handler = const Pipeline()
      .addMiddleware(logRequests()) // 요청 로그 출력
      .addMiddleware(corsHeaders(
        headers: {
          'Access-Control-Allow-Origin': '*',
          'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
          'Access-Control-Allow-Headers': 'Origin, Content-Type, Authorization, ngrok-skip-browser-warning',
        },
      )) // CORS 허용
      .addHandler(router);

  // 서버 실행 (shared: true 옵션으로 포트 공유)
  final server = await io.serve(handler, InternetAddress.anyIPv4, 8080, shared: true);
  print('✅ Worker $id running on http://${server.address.host}:${server.port}');

  // 서버 시작 후 캐시 웜업 (각 아이솔레이트 별로 수행)
  _warmUpCache(id);
}

Future<void> _warmUpCache(int id) async {
  final env = DotEnv(includePlatformEnvironment: true)..load();
  final marketUrl = env['MARKET_SERVICE_URL'] ?? 'http://localhost:8081';
  final symbol = 'SPY';
  // 충분히 긴 기간으로 요청하여 캐시에 적재
  final start = '2000-01-01';
  final end = DateTime.now().toIso8601String().substring(0, 10);
  
  print('⏳ [Worker $id] Warming up cache for $symbol...');
  try {
    final uri = Uri.parse('$marketUrl/v1/price/history/$symbol?start=$start&end=$end');
    final response = await http.get(uri);
    if (response.statusCode == 200) {
      print('✅ [Worker $id] Cache warmed up: $symbol data loaded.');
    } else {
      print('⚠️ [Worker $id] Cache warm-up failed: ${response.statusCode}');
    }
  } catch (e) {
    print('⚠️ [Worker $id] Cache warm-up error: $e');
  }
}