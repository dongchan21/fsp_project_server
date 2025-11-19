import 'dart:convert';
import 'package:http/http.dart' as http;

/// Gemini 기반 AI 인사이트 생성 서비스
Future<Map<String, dynamic>> generateAiInsight(Map<String, dynamic> body) async {
  final score = body['score'] ?? {};
  final analysis = body['analysis'] ?? {};
  final portfolio = body['portfolio'] ?? {};

  // ---------- 포트폴리오 구성 텍스트 ----------
  final symbols = (portfolio['symbols'] as List?)?.join(', ') ?? '미제공';
  final weights = (portfolio['weights'] as List?)
          ?.map((w) => '${(w * 100).toStringAsFixed(0)}%')
          .join(', ') ??
      '';

  final symbolWeightText = symbols != '미제공'
      ? List.generate(
          (portfolio['symbols'] as List).length,
          (i) =>
              "${portfolio['symbols'][i]}: ${(portfolio['weights'][i] * 100).toStringAsFixed(0)}%")
          .join(', ')
      : '포트폴리오 구성 정보 없음';

  // ---------- Gemini용 프롬프트 ----------
  final prompt = """
당신은 전문 투자 어드바이저입니다.
아래는 사용자의 포트폴리오 구성 및 성과 요약입니다.

[포트폴리오 구성]
$symbolWeightText

[성과 요약]
- 수익성 점수: ${score['profit']}/30
- 리스크 점수: ${score['risk']}/35
- 효율성 점수: ${score['efficiency']}/35
- 총점: ${score['total']} (${score['grade']} 등급)

[세부 분석]
${analysis['profitability']}
${analysis['risk']}
${analysis['riskEfficiency']}

이 데이터를 바탕으로 다음 형식(JSON)으로 작성하세요:

{
  "summary": "포트폴리오 성향 요약 (예: 성장형, 균형형 등)",
  "evaluation": "전반적 평가 (100자 내외)",
  "analysis": "성과의 원인 분석 (200자 내외)",
  "suggestion": "개선 및 보완 제안 (200자 내외)",
  "investorType": "추천 투자자 유형 (예: 위험 감수형, 안정추구형 등)"
}
""";

  // ---------- Gemini API 호출 ----------
  final apiKey = 'AIzaSyCaS0EJ_mKJzqrilCMj10wEzc_f6FG3j7Q'; // ✅ API 키 입력
  final url = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=$apiKey');

  final response = await http.post(
    url,
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({
      "contents": [
        {
          "parts": [
            {"text": prompt}
          ]
        }
      ]
    }),
  );

  if (response.statusCode != 200) {
    return {
      "error": "Gemini API 요청 실패",
      "status": response.statusCode,
      "response": response.body
    };
  }

  final result = jsonDecode(response.body);

  // Gemini는 응답이 nested 구조로 들어옵니다.
  final aiText = result['candidates']?[0]?['content']?['parts']?[0]?['text'];

  // ---------- JSON 파싱 시도 ----------
  Map<String, dynamic>? parsed;
  try {
    parsed = jsonDecode(aiText ?? '');
  } catch (e) {
    parsed = {"rawText": aiText ?? "AI 응답 없음"};
  }

  return {
    "aiInsight": parsed,
    "promptUsed": prompt,
  };
}
