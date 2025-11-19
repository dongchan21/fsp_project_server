import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

/// 인사이트 분석 요청 함수
Future<Map<String, dynamic>> runInsightAnalyze({
  required String baseUrl,
  required Map<String, dynamic> summary,
}) async {
  final response = await http.post(
    Uri.parse('$baseUrl/insight/analyze'),
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({"summary": summary}),
  );

  if (response.statusCode != 200) {
    throw Exception(
        "인사이트 분석 요청 실패 (${response.statusCode}): ${response.body}");
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
  print("=== 📊 인사이트 분석 클라이언트 ===\n");

  final baseUrl = ask("서버 주소 입력", defaultValue: "http://localhost:8080/api");

  final totalReturn = double.parse(ask("총 수익률 (예: 0.25 → 25%)", defaultValue: "0.25"));
  final annualReturn = double.parse(ask("연평균 수익률 (예: 0.10 → 10%)", defaultValue: "0.10"));
  final mdd = double.parse(ask("MDD (음수로 입력, 예: -0.15 → -15%)", defaultValue: "-0.15"));
  final sharpe = double.parse(ask("샤프 비율 (예: 0.8)", defaultValue: "0.8"));

  final summary = {
    "totalReturn": totalReturn,
    "annualReturn": annualReturn,
    "mdd": mdd,
    "sharpe": sharpe,
  };

  print("\n📤 인사이트 분석 요청 중...\n");

  try {
    final raw = await runInsightAnalyze(baseUrl: baseUrl, summary: summary);

    print("✅ [서버 Raw 응답 결과]\n");
    print(const JsonEncoder.withIndent('  ').convert(raw));
  } catch (e) {
    print("❌ 오류 발생: $e");
  }
}
