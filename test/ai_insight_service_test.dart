import 'dart:convert';
import 'package:test/test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:fsp_server/services/ai_insight_service.dart';

void main() {
  group('generateAiInsight', () {
    final mockBody = {
      'score': {
        'profit': 25,
        'risk': 30,
        'efficiency': 30,
        'total': 85,
        'grade': 'A'
      },
      'analysis': {
        'profitability': 'Good profit',
        'risk': 'Low risk',
        'riskEfficiency': 'High efficiency'
      },
      'portfolio': {
        'symbols': ['AAPL', 'GOOGL'],
        'weights': [0.6, 0.4]
      }
    };

    test('returns valid insight when API call is successful', () async {
      final mockResponse = {
        "candidates": [
          {
            "content": {
              "parts": [
                {
                  "text": jsonEncode({
                    "summary": "Growth",
                    "evaluation": "Good portfolio",
                    "analysis": "Well balanced",
                    "suggestion": "Keep it up",
                    "investorType": "Aggressive",
                    "suggestedPortfolio": {
                      "symbols": ["AAPL", "GOOGL"],
                      "weights": [0.6, 0.4],
                      "reason": "Good balance"
                    }
                  })
                }
              ]
            }
          }
        ]
      };

      final client = MockClient((request) async {
        if (request.url.toString().contains('generativelanguage.googleapis.com')) {
          return http.Response(jsonEncode(mockResponse), 200);
        }
        return http.Response('Not Found', 404);
      });

      final result = await generateAiInsight(mockBody, client: client, apiKey: 'TEST_KEY');

      expect(result['aiInsight'], isNotNull);
      expect(result['aiInsight']['summary'], 'Growth');
      expect(result['promptUsed'], isNotNull);
    });

    test('handles API error correctly', () async {
      final client = MockClient((request) async {
        return http.Response('Internal Server Error', 500);
      });

      final result = await generateAiInsight(mockBody, client: client, apiKey: 'TEST_KEY');

      expect(result['error'], 'Gemini API 요청 실패');
      expect(result['status'], 500);
    });

    test('handles JSON parsing error from AI response', () async {
      final mockResponse = {
        "candidates": [
          {
            "content": {
              "parts": [
                {
                  "text": "This is not JSON"
                }
              ]
            }
          }
        ]
      };

      final client = MockClient((request) async {
        return http.Response(jsonEncode(mockResponse), 200);
      });

      final result = await generateAiInsight(mockBody, client: client, apiKey: 'TEST_KEY');

      expect(result['aiInsight'], isNotNull);
      expect(result['aiInsight']['rawText'], 'This is not JSON');
    });

    test('returns error when API key is missing', () async {
       // Pass empty string to simulate missing key
       final result = await generateAiInsight(mockBody, apiKey: '');
       expect(result['error'], contains('GEMINI_API_KEY가 설정되지 않았습니다'));
    });
  });
}
