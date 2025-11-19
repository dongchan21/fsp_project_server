import 'dart:math';

// ────────────── 최대 낙폭 (MDD) 계산 ──────────────
// prices: 시드(혹은 평가금액)의 시계열 리스트
double calculateMDD(List<double> prices) {
  if (prices.isEmpty) return 0.0;

  double peak = prices.first;
  double maxDrawdown = 0.0;

  for (final price in prices) {
    if (price > peak) peak = price;
    final drawdown = (price - peak) / peak;
    if (drawdown < maxDrawdown) {
      maxDrawdown = drawdown;
    }
  }
  return maxDrawdown; // 음수값 (-0.23 = -23%)
}

// ────────────── 샤프 지수 (Sharpe Ratio) 계산 ──────────────
// monthlyReturns: 월별 수익률 리스트 (ex. [0.01, -0.02, 0.03])
// riskFreeRate: 연 무위험 이자율 (예: 0.03 = 3%)
double calculateSharpe(List<double> monthlyReturns, {double riskFreeRate = 0.03}) {
  if (monthlyReturns.isEmpty) return 0.0;

  // 월 단위 → 연 환산 (단순히 평균 × 12, 표준편차 × √12)
  final avgReturn = monthlyReturns.reduce((a, b) => a + b) / monthlyReturns.length;
  final stdDev = _stdDev(monthlyReturns);

  if (stdDev == 0) return 0.0;

  final excessReturn = (avgReturn * 12) - riskFreeRate;
  return excessReturn / (stdDev * sqrt(12));
}

// ────────────── 변동성 (Volatility) 계산 ──────────────
// monthlyReturns: 월별 수익률 리스트
// 연율화된 변동성 반환 (월간 표준편차 × √12)
double calculateVolatility(List<double> monthlyReturns) {
  if (monthlyReturns.isEmpty) return 0.0;
  final stdDev = _stdDev(monthlyReturns);
  return stdDev * sqrt(12); // 연율화
}

// ────────────── 표준편차 유틸 ──────────────
double _stdDev(List<double> data) {
  if (data.length < 2) return 0.0;
  final mean = data.reduce((a, b) => a + b) / data.length;
  final variance = data.map((x) => pow(x - mean, 2)).reduce((a, b) => a + b) / (data.length - 1);
  return sqrt(variance);
}
