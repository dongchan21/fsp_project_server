import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

/// 백테스트 요청 함수 (raw 데이터만 반환)
Future<Map<String, dynamic>> runBacktest({
  required String baseUrl,
  required List<String> symbols,
  required List<double> weights,
  required String startDate,
  required String endDate,
  required double initialCapital,
  required double dcaAmount,
}) async {
  final response = await http.post(
    Uri.parse('$baseUrl/backtest/run'),
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({
      "symbols": symbols,
      "weights": weights,
      "startDate": startDate,
      "endDate": endDate,
      "initialCapital": initialCapital,
      "dcaAmount": dcaAmount,
    }),
  );

  if (response.statusCode != 200) {
    throw Exception(
        "백테스트 요청 실패 (${response.statusCode}): ${response.body}");
  }

  return jsonDecode(response.body);
}

/// 콘솔 입력 유틸 함수
String ask(String question, {String? defaultValue}) {
  stdout.write("$question${defaultValue != null ? " (기본값: $defaultValue)" : ""}: ");
  final input = stdin.readLineSync();
  return (input == null || input.isEmpty) ? (defaultValue ?? "") : input;
}

void main() async {
  print("=== 📈 백테스트 클라이언트 ===\n");

  final baseUrl = ask("서버 주소 입력", defaultValue: "http://localhost:8080/api");

  final symbolsInput = ask("종목(symbol) 입력 (쉼표로 구분)", defaultValue: "AAPL,TSLA,MSFT");
  final weightsInput = ask("비중 입력 (쉼표로 구분, 예: 0.4,0.3,0.3)", defaultValue: "0.4,0.3,0.3");

  final symbols = symbolsInput.split(",").map((s) => s.trim()).toList();
  final weights = weightsInput.split(",").map((s) => double.parse(s.trim())).toList();

  final startDate = ask("시작 날짜 (YYYY-MM-DD)", defaultValue: "2025-01-01");
  final endDate = ask("종료 날짜 (YYYY-MM-DD)", defaultValue: "2025-10-01");

  final initialCapital =
      double.parse(ask("초기 투자금 (원화)", defaultValue: "10000000"));
  final dcaAmount = double.parse(ask("월별 추가 투자금 (0 입력 시 DCA 비활성화)", defaultValue: "1000000"));

  print("\n📤 백테스트 요청 중...\n");

  try {
    final raw = await runBacktest(
      baseUrl: baseUrl,
      symbols: symbols,
      weights: weights,
      startDate: startDate,
      endDate: endDate,
      initialCapital: initialCapital,
      dcaAmount: dcaAmount,
    );

    print("✅ [서버 Raw 응답 결과]\n");
    print(const JsonEncoder.withIndent('  ').convert(raw));
  } catch (e) {
    print("❌ 오류 발생: $e");
  }
}
