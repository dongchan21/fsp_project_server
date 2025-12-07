import 'package:test/test.dart';
import 'package:fsp_server/services/backtest_service.dart';

void main() {
  group('BacktestService Logic Tests', () {
    test('Simple 1-stock portfolio with constant growth', () {
      final symbols = ['AAPL'];
      final weights = [1.0];
      final startDate = DateTime(2023, 1, 1);
      final endDate = DateTime(2023, 4, 1); // 3 months: Jan, Feb, Mar
      final initialCapital = 1000.0;
      final dcaAmount = 0.0;

      // 모의 데이터: AAPL이 매달 10%씩 성장
      // 1월 1일: 100, 2월 1일: 110, 3월 1일: 121, 4월 1일: 133.1
      final stockData = {
        'AAPL': {
          DateTime(2022, 12, 1): 100.0, // 1월 계산을 위한 전월 데이터
          DateTime(2023, 1, 1): 110.0,  // 1월 수익률: (110/100)-1 = 0.10
          DateTime(2023, 2, 1): 121.0,  // 2월 수익률: (121/110)-1 = 0.10
          DateTime(2023, 3, 1): 133.1,  // 3월 수익률: (133.1/121)-1 = 0.10
        },
        'SPY': {
          DateTime(2022, 12, 1): 100.0,
          DateTime(2023, 1, 1): 100.0,
          DateTime(2023, 2, 1): 100.0,
          DateTime(2023, 3, 1): 100.0,
        }
      };

      final result = calculateBacktestLogic(
        symbols: symbols,
        weights: weights,
        startDate: startDate,
        endDate: endDate,
        initialCapital: initialCapital,
        dcaAmount: dcaAmount,
        stockData: stockData,
      );

      // 예상 결과:
      // 1개월차 (1월): 시작 1000 -> 종료 1100 (10%)
      // 2개월차 (2월): 시작 1100 -> 종료 1210 (10%)
      // 3개월차 (3월): 시작 1210 -> 종료 1331 (10%)
      
      expect(result['totalReturn'], closeTo(0.331, 0.001)); // (1331/1000) - 1 = 0.331
      expect((result['history'] as List).last['value'], closeTo(1331.0, 0.1));
    });

    test('Portfolio with DCA', () {
      final symbols = ['AAPL'];
      final weights = [1.0];
      final startDate = DateTime(2023, 1, 1);
      final endDate = DateTime(2023, 3, 1); // 2 months: Jan, Feb
      final initialCapital = 1000.0;
      final dcaAmount = 100.0;

      // 모의 데이터: 횡보장 (0% 수익률)
      final stockData = {
        'AAPL': {
          DateTime(2022, 12, 1): 100.0,
          DateTime(2023, 1, 1): 100.0,
          DateTime(2023, 2, 1): 100.0,
        },
        'SPY': {
          DateTime(2022, 12, 1): 100.0,
          DateTime(2023, 1, 1): 100.0,
          DateTime(2023, 2, 1): 100.0,
        }
      };

      final result = calculateBacktestLogic(
        symbols: symbols,
        weights: weights,
        startDate: startDate,
        endDate: endDate,
        initialCapital: initialCapital,
        dcaAmount: dcaAmount,
        stockData: stockData,
      );

      // 로직 확인:
      // 1개월차 (1월):
      //   시작 가치: 1000
      //   DCA 추가: 1000 + 100 = 1100
      //   수익률: 0%
      //   종료 가치: 1100 * 1.0 = 1100
      // 2개월차 (2월):
      //   시작 가치: 1100
      //   DCA 추가: 1100 + 100 = 1200
      //   수익률: 0%
      //   종료 가치: 1200 * 1.0 = 1200
      
      // 총 투자금: 1000 (초기) + 100 (1월) + 100 (2월) = 1200?
      // 잠시만요, BacktestService.dart의 루프 로직을 확인해 봅시다:
      // portfolioValueKRW = (portfolioValueKRW + dcaAmount) * (1 + monthReturn);
      // investedKRW += dcaAmount;
      
      // 월별 수익률 계산 *전에* DCA를 추가합니다.
      
      expect((result['history'] as List).last['value'], closeTo(1200.0, 0.1));
      expect(result['totalReturn'], closeTo(0.0, 0.001)); // (1200 / 1200) - 1 = 0
    });

    test('Skip month if data is missing', () {
      final symbols = ['AAPL', 'GOOG'];
      final weights = [0.5, 0.5];
      final startDate = DateTime(2023, 1, 1);
      final endDate = DateTime(2023, 5, 1); // Jan, Feb, Mar, Apr
      final initialCapital = 1000.0;
      final dcaAmount = 0.0;

      final stockData = {
        'AAPL': {
          DateTime(2022, 12, 1): 100.0,
          DateTime(2023, 1, 1): 110.0,
          DateTime(2023, 2, 1): 121.0,
          DateTime(2023, 3, 1): 133.1,
          DateTime(2023, 4, 1): 146.41,
        },
        'GOOG': {
          DateTime(2022, 12, 1): 100.0,
          DateTime(2023, 1, 1): 110.0,
          // Missing Feb data
          DateTime(2023, 3, 1): 133.1,
          DateTime(2023, 4, 1): 146.41,
        },
        'SPY': {
          DateTime(2022, 12, 1): 100.0,
          DateTime(2023, 1, 1): 100.0,
          DateTime(2023, 2, 1): 100.0,
          DateTime(2023, 3, 1): 100.0,
          DateTime(2023, 4, 1): 100.0,
        }
      };

      final result = calculateBacktestLogic(
        symbols: symbols,
        weights: weights,
        startDate: startDate,
        endDate: endDate,
        initialCapital: initialCapital,
        dcaAmount: dcaAmount,
        stockData: stockData,
      );

      // Expected:
      // Jan: Both have data (Prev: Dec). Processed.
      // Feb: GOOG missing Feb. Skipped.
      // Mar: GOOG has Mar, but missing Feb (Prev). Skipped.
      // Apr: GOOG has Apr, and has Mar (Prev). Processed.
      
      final history = result['history'] as List;
      // Should have 2 entries (Jan, Apr).
      expect(history.length, 2);
      expect(history[0]['date'], '2023-01-01');
      expect(history[1]['date'], '2023-04-01');
    });
  });
}
