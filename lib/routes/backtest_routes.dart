import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import '../services/backtest_service.dart';

class BacktestRoutes {
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
        final weights = List<double>.from(data['weights']);
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

        return Response.ok(
          jsonEncode(result),
          headers: {'Content-Type': 'application/json'},
        );
      } catch (e, st) {
        print('❌ Error: $e\n$st');
        return Response.internalServerError(
          body: jsonEncode({'error': 'Invalid request or server error'}),
          headers: {'Content-Type': 'application/json'},
        );
      }
    });

    return router;
  }
}
