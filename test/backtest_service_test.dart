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

      // Mock Data: AAPL grows 10% every month
      // Jan 1: 100, Feb 1: 110, Mar 1: 121, Apr 1: 133.1
      final stockData = {
        'AAPL': {
          DateTime(2022, 12, 1): 100.0, // Prev month for Jan calculation
          DateTime(2023, 1, 1): 110.0,  // Jan return: (110/100)-1 = 0.10
          DateTime(2023, 2, 1): 121.0,  // Feb return: (121/110)-1 = 0.10
          DateTime(2023, 3, 1): 133.1,  // Mar return: (133.1/121)-1 = 0.10
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

      // Expected:
      // Month 1 (Jan): Start 1000 -> End 1100 (10%)
      // Month 2 (Feb): Start 1100 -> End 1210 (10%)
      // Month 3 (Mar): Start 1210 -> End 1331 (10%)
      
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

      // Mock Data: Flat market (0% return)
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

      // Logic Check:
      // Month 1 (Jan):
      //   Start Value: 1000
      //   Add DCA: 1000 + 100 = 1100
      //   Return: 0%
      //   End Value: 1100 * 1.0 = 1100
      // Month 2 (Feb):
      //   Start Value: 1100
      //   Add DCA: 1100 + 100 = 1200
      //   Return: 0%
      //   End Value: 1200 * 1.0 = 1200
      
      // Total Invested: 1000 (Initial) + 100 (Jan) + 100 (Feb) = 1200?
      // Wait, let's check the loop logic in BacktestService.dart:
      // portfolioValueKRW = (portfolioValueKRW + dcaAmount) * (1 + monthReturn);
      // investedKRW += dcaAmount;
      
      // It adds DCA *before* the monthly return calculation.
      
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
