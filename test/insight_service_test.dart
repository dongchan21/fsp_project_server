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
      expect(score['profit'], 30); // > 15% -> max score
      expect(score['risk'], greaterThan(25)); // Low MDD -> high score
      expect(score['efficiency'], 35); // Sharpe >= 1.5 -> max score
      
      expect(result['analysis']['profitability'], contains('높은 수익률'));
      expect(result['analysis']['risk'], contains('낮은 리스크'));
      expect(result['analysis']['riskEfficiency'], contains('우수한 위험 대비 수익 효율'));
    });

    test('calculates medium score for average performance', () {
      final summary = {
        'annualReturn': 0.10, // 10% (Same as S&P)
        'totalReturn': 0.20,
        'mdd': -0.15, // -15% (Slightly worse than S&P)
        'sharpe': 1.0, // 1.0 (Slightly worse than S&P 1.2)
      };

      final result = generateScoreAndAnalysis(summary);
      final score = result['score'];

      // Profit: 0.10 * 200 = 20
      expect(score['profit'], 20);
      
      // Risk: 35 - 0.9 * 15 = 35 - 13.5 = 21.5 -> 21 or 22
      expect(score['risk'], closeTo(21, 1));

      // Efficiency: Sharpe 1.0 -> 25
      expect(score['efficiency'], 25);

      // Total: 20 + 21.5 + 25 = 66.5 -> Grade C or B depending on scaling logic
      // Logic: totalScaled = (total / 100 * 100) = total. 
      // Wait, logic is: (total / 100 * (30 + 35 + 35)).clamp(0, 100);
      // 30+35+35 = 100. So totalScaled == total.
      // 66.5 -> Grade C (55 <= x < 70)
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

      expect(score['profit'], 0); // Negative return -> 0
      expect(score['risk'], 5); // High MDD -> min score 5
      expect(score['efficiency'], 5); // Low Sharpe -> min score 5
      
      expect(score['grade'], 'D');
      
      expect(result['analysis']['profitability'], contains('낮은 수익률'));
      expect(result['analysis']['risk'], contains('높은 리스크'));
    });

    test('handles missing values gracefully', () {
      final summary = <String, dynamic>{}; // Empty map

      final result = generateScoreAndAnalysis(summary);
      final score = result['score'];

      expect(score['profit'], 0);
      expect(score['risk'], 35); // MDD 0 -> max score
      expect(score['efficiency'], 5); // Sharpe 0 -> min score
      
      expect(result['analysis'], isNotNull);
    });
  });
}
