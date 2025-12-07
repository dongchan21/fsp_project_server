import 'package:test/test.dart';
import 'package:fsp_server/services/insight_service.dart';

void main() {
  group('generateScoreAndAnalysis', () {
    test('calculates high score for excellent performance', () {
      final summary = {
        'annualReturn': 0.20, // 20%
        'totalReturn': 0.50,
        'mdd': -0.10, // -10%
        'sharpe': 1.6,
      };

      final result = generateScoreAndAnalysis(summary);
      final score = result['score'];

      expect(score['grade'], 'A');
      expect(score['profit'], 30); // > 15% -> 최대 점수
      expect(score['risk'], greaterThan(25)); // 낮은 MDD -> 높은 점수
      expect(score['efficiency'], 35); // Sharpe >= 1.5 -> 최대 점수
      
      expect(result['analysis']['profitability'], contains('높은 수익률'));
      expect(result['analysis']['risk'], contains('낮은 리스크'));
      expect(result['analysis']['riskEfficiency'], contains('우수한 위험 대비 수익 효율'));
    });

    test('calculates medium score for average performance', () {
      final summary = {
        'annualReturn': 0.10, // 10% (S&P와 동일)
        'totalReturn': 0.20,
        'mdd': -0.15, // -15% (S&P보다 약간 나쁨)
        'sharpe': 1.0, // 1.0 (S&P 1.2보다 약간 나쁨)
      };

      final result = generateScoreAndAnalysis(summary);
      final score = result['score'];

      // 수익성: 0.10 * 200 = 20
      expect(score['profit'], 20);
      
      // 리스크: 35 - 0.9 * 15 = 35 - 13.5 = 21.5 -> 21 또는 22
      expect(score['risk'], closeTo(21, 1));

      // 효율성: Sharpe 1.0 -> 25
      expect(score['efficiency'], 25);

      // 총점: 20 + 21.5 + 25 = 66.5 -> 스케일링 로직에 따라 등급 C 또는 B
      // 로직: totalScaled = (total / 100 * 100) = total. 
      // 잠시만요, 로직은: (total / 100 * (30 + 35 + 35)).clamp(0, 100);
      // 30+35+35 = 100. 따라서 totalScaled == total.
      // 66.5 -> 등급 C (55 <= x < 70)
      expect(score['grade'], anyOf('B', 'C')); 
    });

    test('calculates low score for poor performance', () {
      final summary = {
        'annualReturn': -0.05, // -5%
        'totalReturn': -0.10,
        'mdd': -0.40, // -40%
        'sharpe': -0.2,
      };

      final result = generateScoreAndAnalysis(summary);
      final score = result['score'];

      expect(score['profit'], 0); // 마이너스 수익률 -> 0
      expect(score['risk'], 5); // 높은 MDD -> 최소 점수 5
      expect(score['efficiency'], 5); // 낮은 Sharpe -> 최소 점수 5
      
      expect(score['grade'], 'D');
      
      expect(result['analysis']['profitability'], contains('낮은 수익률'));
      expect(result['analysis']['risk'], contains('높은 리스크'));
    });

    test('handles missing values gracefully', () {
      final summary = <String, dynamic>{}; // 빈 맵

      final result = generateScoreAndAnalysis(summary);
      final score = result['score'];

      expect(score['profit'], 0);
      expect(score['risk'], 35); // MDD 0 -> 최대 점수
      expect(score['efficiency'], 5); // Sharpe 0 -> 최소 점수
      
      expect(result['analysis'], isNotNull);
    });
  });
}
