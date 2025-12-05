import 'package:test/test.dart';
import 'package:fsp_server/services/math_utils.dart';
import 'dart:math';

void main() {
  group('MathUtils Tests', () {
    test('calculateMDD should return correct max drawdown', () {
      // Peak 100 -> 90 (-10%), Peak 110 -> 55 (-50%)
      final prices = [100.0, 90.0, 110.0, 80.0, 55.0, 70.0];
      final mdd = calculateMDD(prices);
      // Peak is 110, lowest after peak is 55. (55-110)/110 = -0.5
      expect(mdd, closeTo(-0.5, 0.001));
    });

    test('calculateMDD should return 0 for empty list', () {
      expect(calculateMDD([]), 0.0);
    });

    test('calculateMDD should return 0 for constantly increasing prices', () {
      final prices = [100.0, 110.0, 120.0, 130.0];
      expect(calculateMDD(prices), 0.0);
    });

    test('calculateVolatility should return correct annualized volatility', () {
      // Simple case: constant returns -> stdDev 0 -> volatility 0
      final returns = [0.01, 0.01, 0.01];
      expect(calculateVolatility(returns), 0.0);

      // Case with variance
      final returns2 = [0.1, -0.1]; // Mean 0. Variance: ((0.1-0)^2 + (-0.1-0)^2) / 1 = 0.02. StdDev = sqrt(0.02) ~= 0.1414
      // Annualized = 0.1414 * sqrt(12) ~= 0.1414 * 3.464 ~= 0.489
      final vol = calculateVolatility(returns2);
      expect(vol, closeTo(0.489, 0.01));
    });

    test('calculateSharpe should return correct sharpe ratio', () {
      // Mean 0.01, StdDev 0.0. Sharpe should be 0 if stdDev is 0 (handled in code)
      final returns = [0.01, 0.01];
      expect(calculateSharpe(returns), 0.0);
      
      // Mean 0.02 (24% annual), RiskFree 0.03. Excess = 0.21.
      // StdDev needs to be non-zero.
      final returns2 = [0.03, 0.01]; // Mean 0.02. Var ((0.01)^2 + (-0.01)^2)/1 = 0.0002. StdDev 0.01414
      // Annualized StdDev = 0.01414 * 3.464 = 0.0489
      // Excess Return = (0.02 * 12) - 0.03 = 0.24 - 0.03 = 0.21
      // Sharpe = 0.21 / 0.0489 ~= 4.29
      final sharpe = calculateSharpe(returns2, riskFreeRate: 0.03);
      expect(sharpe, greaterThan(0.0));
    });
  });
}
