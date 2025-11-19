import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

/// AI 인사이트 요청 함수
Future<Map<String, dynamic>> runAIInsight({
  required String baseUrl,
  required Map<String, dynamic> score,
  required Map<String, dynamic> analysis,
  required Map<String, dynamic> portfolio,
}) async {
  final response = await http.post(
    Uri.parse('$baseUrl/insight/ai'),
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({
      "score": score,
      "analysis": analysis,
      "portfolio": portfolio,
    }),
  );

  if (response.statusCode != 200) {
    throw Exception(
        "AI 인사이트 요청 실패 (${response.statusCode}): ${response.body}");
  }

  return jsonDecode(response.body);
}

/// 콘솔 입력 함수
String ask(String question, {String? defaultValue}) {
  stdout.write("$question${defaultValue != null ? " (기본값: $defaultValue)" : ""}: ");
  final input = stdin.readLineSync();
  return (input == null || input.isEmpty) ? (defaultValue ?? "") : input;
}

void main() async {
  print("=== 🤖 AI 인사이트 클라이언트 ===\n");

  final baseUrl = ask("서버 주소 입력", defaultValue: "http://localhost:8080/api");

  // ---------------- 점수 입력 ----------------
  final total = int.parse(ask("총점", defaultValue: "78"));
  final grade = ask("등급", defaultValue: "B");
  final profit = int.parse(ask("수익성 점수", defaultValue: "25"));
  final risk = int.parse(ask("리스크 관리 점수", defaultValue: "19"));
  final efficiency = int.parse(ask("효율성 점수", defaultValue: "34"));

  final score = {
    "total": total,
    "grade": grade,
    "profit": profit,
    "risk": risk,
    "efficiency": efficiency
  };

  // ---------------- 분석 입력 ----------------
  final profitability = ask("수익성 분석 문장",
      defaultValue: "연평균 수익률 12.4%로 S&P500 대비 2.4% 높은 수익률입니다.");
  final riskText =
      ask("리스크 분석 문장", defaultValue: "최대 낙폭 18.2%로 S&P500 대비 안정적입니다.");
  final efficiencyText =
      ask("효율성 분석 문장", defaultValue: "샤프 비율 1.34로 효율적입니다.");

  final analysis = {
    "profitability": profitability,
    "risk": riskText,
    "riskEfficiency": efficiencyText
  };

  // ---------------- 포트폴리오 입력 ----------------
  final symbolsInput = ask("종목 입력 (쉼표로 구분)", defaultValue: "AAPL,MSFT,TSLA,KO");
  final weightsInput = ask("비중 입력 (쉼표로 구분)", defaultValue: "0.4,0.3,0.2,0.1");

  final symbols = symbolsInput.split(",").map((s) => s.trim()).toList();
  final weights = weightsInput.split(",").map((s) => double.parse(s.trim())).toList();

  final portfolio = {"symbols": symbols, "weights": weights};

  print("\n📤 AI 인사이트 요청 중...\n");

  try {
    final raw = await runAIInsight(
      baseUrl: baseUrl,
      score: score,
      analysis: analysis,
      portfolio: portfolio,
    );

    print("✅ [서버 Raw 응답 결과]\n");
    print(const JsonEncoder.withIndent('  ').convert(raw));
  } catch (e) {
    print("❌ 오류 발생: $e");
  }
}
