import 'package:test/test.dart';
import 'package:fsp_server/services/math_utils.dart';
import 'dart:math';

void main() {
  group('MathUtils Tests', () {
    test('calculateMDD should return correct max drawdown', () {
      // 고점 100 -> 90 (-10%), 고점 110 -> 55 (-50%)
      final prices = [100.0, 90.0, 110.0, 80.0, 55.0, 70.0];
      final mdd = calculateMDD(prices);
      // 고점은 110, 고점 이후 최저점은 55. (55-110)/110 = -0.5
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
      // 단순 케이스: 일정한 수익률 -> 표준편차 0 -> 변동성 0
      final returns = [0.01, 0.01, 0.01];
      expect(calculateVolatility(returns), 0.0);

      // 분산이 있는 케이스
      final returns2 = [0.1, -0.1]; // 평균 0. 분산: ((0.1-0)^2 + (-0.1-0)^2) / 1 = 0.02. 표준편차 = sqrt(0.02) ~= 0.1414
      // 연율화 = 0.1414 * sqrt(12) ~= 0.1414 * 3.464 ~= 0.489
      final vol = calculateVolatility(returns2);
      expect(vol, closeTo(0.489, 0.01));
    });

    test('calculateSharpe should return correct sharpe ratio', () {
      // 평균 0.01, 표준편차 0.0. 표준편차가 0이면 샤프 지수는 0이어야 함 (코드에서 처리됨)
      final returns = [0.01, 0.01];
      expect(calculateSharpe(returns), 0.0);
      
      // 평균 0.02 (연 24%), 무위험 이자율 0.03. 초과 수익 = 0.21.
      // 표준편차는 0이 아니어야 함.
      final returns2 = [0.03, 0.01]; // 평균 0.02. 분산 ((0.01)^2 + (-0.01)^2)/1 = 0.0002. 표준편차 0.01414
      // 연율화 표준편차 = 0.01414 * 3.464 = 0.0489
      // 초과 수익 = (0.02 * 12) - 0.03 = 0.24 - 0.03 = 0.21
      // 샤프 지수 = 0.21 / 0.0489 ~= 4.29
      final sharpe = calculateSharpe(returns2, riskFreeRate: 0.03);
      expect(sharpe, greaterThan(0.0));
    });
  });
}
