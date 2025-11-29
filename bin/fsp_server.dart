import 'dart:io';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_router/shelf_router.dart';
import 'package:shelf_cors_headers/shelf_cors_headers.dart';
import 'package:dotenv/dotenv.dart'; // dotenv 패키지

import 'package:fsp_server/routes/backtest_routes.dart';
import 'package:fsp_server/routes/insight_routes.dart';
import 'package:http/http.dart' as http;

void main() async {
  // .env 파일 로드
  final env = DotEnv(includePlatformEnvironment: true)..load();

  // 라우터 생성 및 백테스트 경로 등록
  final router = Router()..mount('/api/backtest/', BacktestRoutes().router);
  router.mount('/api/insight/', insightRoutes());

  // 미들웨어 설정
  final handler = const Pipeline()
      .addMiddleware(logRequests()) // 요청 로그 출력
      .addMiddleware(corsHeaders()) // CORS 허용
      .addHandler(router);

  // 서버 실행
  final server = await io.serve(handler, InternetAddress.anyIPv4, 8080);
  print('✅ Server running on http://${server.address.host}:${server.port}');

  // 서버 시작 후 캐시 웜업 (SPY 데이터 미리 로드)
  _warmUpCache();
}

Future<void> _warmUpCache() async {
  final env = DotEnv(includePlatformEnvironment: true)..load();
  final marketUrl = env['MARKET_SERVICE_URL'] ?? 'http://localhost:8081';
  final symbol = 'SPY';
  // 충분히 긴 기간으로 요청하여 캐시에 적재
  final start = '2000-01-01';
  final end = DateTime.now().toIso8601String().substring(0, 10);
  
  print('⏳ Warming up cache for $symbol...');
  try {
    final uri = Uri.parse('$marketUrl/v1/price/history/$symbol?start=$start&end=$end');
    final response = await http.get(uri);
    if (response.statusCode == 200) {
      print('✅ Cache warmed up: $symbol data loaded.');
    } else {
      print('⚠️ Cache warm-up failed: ${response.statusCode}');
    }
  } catch (e) {
    print('⚠️ Cache warm-up error: $e');
  }
}