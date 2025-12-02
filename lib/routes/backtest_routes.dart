import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import '../services/backtest_service.dart';

class BacktestRoutes {
  static const String _secretKey = 'my_secret_key'; // Should be in env

  Router get router {
    final router = Router();

    // POST /api/backtest/run
    router.post('/run', (Request request) async {
      try {
        final body = await request.readAsString();
        final data = jsonDecode(body);

         // ✅ 요청 로그 출력 (클라이언트가 보낸 JSON 그대로)
      print("────────────── 📩 백테스트 요청 수신 ──────────────");
      print(JsonEncoder.withIndent('  ').convert(data));
      print("──────────────────────────────────────────────");

        final symbols = List<String>.from(data['symbols']);
        final weights = (data['weights'] as List)
            .map((w) => (w as num).toDouble())
            .toList();
        final startDate = DateTime.parse(data['startDate']);
        final endDate = DateTime.parse(data['endDate']);
        final initialCapital = (data['initialCapital'] as num).toDouble();
        final dcaAmount = (data['dcaAmount'] as num).toDouble();

        final result = await runBacktest(
          symbols: symbols,
          weights: weights,
          startDate: startDate,
          endDate: endDate,
          initialCapital: initialCapital,
          dcaAmount: dcaAmount,
        );

        // 로그인한 사용자라면 히스토리 저장
        final authHeader = request.headers['Authorization'];
        if (authHeader != null && authHeader.startsWith('Bearer ')) {
          try {
            final token = authHeader.substring(7);
            final jwt = JWT.verify(token, SecretKey(_secretKey));
            final userId = jwt.payload['id'];

            // 요약 정보만 추출하여 저장
            final summary = {
              'totalReturn': result['totalReturn'],
              'annualizedReturn': result['annualizedReturn'],
              'volatility': result['volatility'],
              'sharpeRatio': result['sharpeRatio'],
              'maxDrawdown': result['maxDrawdown'],
            };

            await BacktestService.saveHistory(
              userId: userId,
              symbols: symbols,
              weights: weights,
              startDate: startDate,
              endDate: endDate,
              initialCapital: initialCapital,
              dcaAmount: dcaAmount,
              resultSummary: summary,
            );
            print('✅ Backtest history saved for user $userId');
          } catch (e) {
            print('⚠️ Failed to save history: $e');
            // 히스토리 저장 실패가 백테스트 결과 반환을 막으면 안 됨
          }
        }

        return Response.ok(
          jsonEncode(result),
          headers: {'Content-Type': 'application/json'},
        );
      } catch (e, st) {
        final debug = const bool.fromEnvironment('dart.vm.product') ? false : true;
        print('❌ Backtest Error: $e\n$st');
        return Response.internalServerError(
          body: jsonEncode({
            'error': 'backtest_failed',
            if (debug) 'details': e.toString(),
          }),
          headers: {'Content-Type': 'application/json'},
        );
      }
    });

    // GET /api/backtest/history
    router.get('/history', (Request request) async {
      final authHeader = request.headers['Authorization'];
      if (authHeader == null || !authHeader.startsWith('Bearer ')) {
        return Response.forbidden(jsonEncode({'error': 'Missing or invalid token'}));
      }

      try {
        final token = authHeader.substring(7);
        final jwt = JWT.verify(token, SecretKey(_secretKey));
        final userId = jwt.payload['id'];

        final history = await BacktestService.getHistory(userId);
        return Response.ok(
          jsonEncode(history),
          headers: {'Content-Type': 'application/json'},
        );
      } catch (e) {
        return Response.forbidden(jsonEncode({'error': 'Invalid token or server error: $e'}));
      }
    });

    return router;
  }
}
