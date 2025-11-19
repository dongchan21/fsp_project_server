import 'csv_loader.dart';
import 'dart:math';
import 'math_utils.dart';

Future<Map<String, dynamic>> runBacktest({
  required List<String> symbols,
  required List<double> weights,
  required DateTime startDate,
  required DateTime endDate,
  required double initialCapital,
  required double dcaAmount,
}) async {
  final months = <DateTime>[];
  for (var d = DateTime(startDate.year, startDate.month);
      d.isBefore(endDate);
      d = DateTime(d.year, d.month + 1)) {
    months.add(d);
  }

  final monthlyReturns = <double>[];
  final pricesKRW = <double>[];
  final stockData = await loadStockData(symbols);
  final usdkrw = await loadUsdKrwRates();

  double portfolioValueKRW = initialCapital;
  double investedKRW = initialCapital;
  final portfolioGrowth = <Map<String, dynamic>>[];

  for (var date in months) {
    double monthReturn = 0.0;

    for (int i = 0; i < symbols.length; i++) {
      final ticker = symbols[i];
      final weight = weights[i];
      final prices = stockData[ticker];
      if (prices == null || prices[date] == null) continue;

      final prevDate = DateTime(date.year, date.month - 1, 1);
      if (prices[prevDate] == null) continue;

      final change = (prices[date]! / prices[prevDate]!) - 1;
      monthReturn += change * weight;
    }

    // 복리 적용 + DCA
    portfolioValueKRW = (portfolioValueKRW + dcaAmount) * (1 + monthReturn);
    investedKRW += dcaAmount;
    final totalReturnRate = (portfolioValueKRW / investedKRW) - 1;

    portfolioGrowth.add({
      'date': '${date.year}-${date.month.toString().padLeft(2, '0')}-01',
      'totalSeedKRW': portfolioValueKRW,
      'investedKRW': investedKRW,
      'totalReturnRate': totalReturnRate
    });

    // ✅ 리스트 추가 (Sharpe, MDD 계산용)
    monthlyReturns.add(monthReturn);
    pricesKRW.add(portfolioValueKRW);
  }

  // ────────────── 요약 통계 ──────────────
  final totalReturn = (portfolioValueKRW / investedKRW) - 1;
  final years = max(months.length / 12, 1);
  final annualReturn = pow(1 + totalReturn, 1 / years) - 1;

  final mdd = calculateMDD(pricesKRW);
  final sharpe = calculateSharpe(monthlyReturns);

  // ✅ 클라이언트가 예상하는 형식으로 반환
  return {
    'totalReturn': totalReturn,
    'annualizedReturn': annualReturn,
    'volatility': calculateVolatility(monthlyReturns),
    'sharpeRatio': sharpe,
    'maxDrawdown': mdd,
    'history': portfolioGrowth.map((item) => {
      'date': item['date'],
      'value': item['totalSeedKRW'],
    }).toList(),
  };
}
