import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:dotenv/dotenv.dart';

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
  "investorType": "추천 투자자 유형 (예: 위험 감수형, 안정추구형 등)",
  "suggestedPortfolio": {
    "symbols": ["(종목1)", "(종목2)", "(종목3)"],
    "weights": [0.5, 0.3, 0.2],
    "reason": "제안 이유 (100자 내외)"
  }
}

제안 포트폴리오 작성 시 주의사항:
1. 위 JSON 예시의 종목은 형식일 뿐입니다. 절대 그대로 베끼지 마세요.
2. 반드시 사용자의 현재 포트폴리오($symbolWeightText)를 바탕으로, 분석 결과에 따라 비중을 조절하거나 필요한 자산(채권, 금, 배당주 등)을 추가하여 재구성하세요.
3. weights의 합은 반드시 1.0이 되어야 합니다.
4. symbols는 실제 미국 주식 티커(대문자)로 작성하세요.
5. **중요**: 현재 포트폴리오의 성과가 이미 안정적이고 우수하다면(예: 샤프지수 1.0 이상, MDD -25% 이내 등), 굳이 억지로 변경을 제안하지 말고 `suggestedPortfolio` 필드를 아예 생략(null)하세요. "이미 훌륭한 포트폴리오입니다"라고 평가하는 것이 더 좋습니다.
""";

  // ---------- Gemini API 호출 ----------
  // 환경 변수에서 API 키를 가져오거나, 없으면 에러 반환
  final env = DotEnv(includePlatformEnvironment: true)..load();
  final apiKey = env['GEMINI_API_KEY'];

  if (apiKey == null || apiKey.isEmpty) {
    return {
      "error": "서버 설정 오류: GEMINI_API_KEY가 설정되지 않았습니다.",
      "status": 500,
    };
  }

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
  // 마크다운 코드 블록 제거 (```json ... ```)
  String cleanText = (aiText ?? '').replaceAll(RegExp(r'^```json\s*|\s*```$'), '').trim();
  // 혹시 ``` 만 있는 경우도 처리
  cleanText = cleanText.replaceAll(RegExp(r'^```\s*|\s*```$'), '').trim();

  Map<String, dynamic>? parsed;
  try {
    parsed = jsonDecode(cleanText);
  } catch (e) {
    print('JSON parsing error: $e');
    parsed = {"rawText": aiText ?? "AI 응답 없음"};
  }

  return {
    "aiInsight": parsed,
    "promptUsed": prompt,
  };
}
