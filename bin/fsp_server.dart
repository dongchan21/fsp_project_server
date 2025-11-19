import 'dart:io';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_router/shelf_router.dart';
import 'package:shelf_cors_headers/shelf_cors_headers.dart';

import 'package:fsp_server/routes/backtest_routes.dart';
import 'package:fsp_server/routes/insight_routes.dart';

void main() async {
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
}
