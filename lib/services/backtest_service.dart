import 'dart:math';
import 'dart:io';
import 'math_utils.dart';
import 'market_data_service.dart';
import '../utils/date_utils.dart';

Future<Map<String, dynamic>> runBacktest({
  required List<String> symbols,
  required List<double> weights,
  required DateTime startDate,
  required DateTime endDate,
  required double initialCapital,
  required double dcaAmount,
}) async {
  final monthlyReturns = <double>[];
  final pricesKRW = <double>[];
  // Prefetch monthly first trading day rows from listing to current month, and compute adjusted start
  final earliestMap = await MarketDataService.prefetchMonthlyFirstDay(symbols);
  DateTime adjustedStart = firstOfMonth(startDate);
  if (earliestMap.isNotEmpty) {
    DateTime latestEarliest = earliestMap.values.first;
    for (final dt in earliestMap.values) {
      if (dt.isAfter(latestEarliest)) latestEarliest = dt;
    }
    if (latestEarliest.isAfter(adjustedStart)) {
      adjustedStart = latestEarliest;
    }
  }
  final stockData = await MarketDataService.loadPriceHistoryFromApi({...symbols, 'SPY'}.toList(), adjustedStart, endDate);
  // final usdkrw = await MarketDataService.loadExchangeRatesFromApi(adjustedStart, endDate); // currently unused; placeholder for FX conversion

  // Fallback: if prefetch did not yield earliest dates (e.g., service down),
  // adjust start based on actual earliest data in loaded history.
  if (earliestMap.isEmpty) {
    DateTime? latestEarliestFromData;
    for (final sym in symbols) {
      final m = stockData[sym];
      if (m == null || m.isEmpty) continue;
      final earliest = m.keys.reduce((a, b) => a.isBefore(b) ? a : b);
      latestEarliestFromData = latestEarliestFromData == null
          ? earliest
          : (earliest.isAfter(latestEarliestFromData!) ? earliest : latestEarliestFromData);
    }
    if (latestEarliestFromData != null && latestEarliestFromData.isAfter(adjustedStart)) {
      stderr.writeln('WARN adjusted_start_fallback used=${latestEarliestFromData.toIso8601String()}');
      adjustedStart = firstOfMonth(latestEarliestFromData);
    }
  }

  final months = <DateTime>[];
  for (var d = DateTime(adjustedStart.year, adjustedStart.month);
      d.isBefore(endDate);
      d = DateTime(d.year, d.month + 1)) {
    months.add(d);
  }

  double portfolioValueKRW = initialCapital;
  double investedKRW = initialCapital;
  final portfolioGrowth = <Map<String, dynamic>>[];

  // Benchmark (SPY) variables
  double benchmarkValueKRW = initialCapital;
  final benchmarkGrowth = <Map<String, dynamic>>[];

  // Annual Returns Tracking
  final portfolioAnnualReturns = <int, double>{};
  final benchmarkAnnualReturns = <int, double>{};

  for (var date in months) {
    // 모든 심볼이 해당 월과 이전 월 데이터를 모두 갖고 있어야 계산 수행
    final prevDate = DateTime(date.year, date.month - 1, 1);
    bool hasAll = true;
    for (int i = 0; i < symbols.length; i++) {
      final ticker = symbols[i];
      final prices = stockData[ticker];
      if (prices == null || prices[date] == null || prices[prevDate] == null) {
        hasAll = false;
        break;
      }
    }
    if (!hasAll) {
      stderr.writeln('INFO skip_month_missing_data date=${ymd(date)}');
      continue;
    }

    double monthReturn = 0.0;
    for (int i = 0; i < symbols.length; i++) {
      final ticker = symbols[i];
      final weight = weights[i];
      final prices = stockData[ticker]!;
      final change = (prices[date]! / prices[prevDate]!) - 1;
      monthReturn += change * weight;
    }

    // 복리 적용 + DCA (모든 심볼 데이터가 있을 때만)
    portfolioValueKRW = (portfolioValueKRW + dcaAmount) * (1 + monthReturn);
    investedKRW += dcaAmount;
    final totalReturnRate = (portfolioValueKRW / investedKRW) - 1;

    portfolioGrowth.add({
      'date': '${date.year}-${date.month.toString().padLeft(2, '0')}-01',
      'totalSeedKRW': portfolioValueKRW,
      'investedKRW': investedKRW,
      'totalReturnRate': totalReturnRate
    });

    // Benchmark (SPY) Calculation
    final spyPrices = stockData['SPY'];
    double spyChange = 0.0;
    if (spyPrices != null && spyPrices[date] != null && spyPrices[prevDate] != null) {
      spyChange = (spyPrices[date]! / spyPrices[prevDate]!) - 1;
      benchmarkValueKRW = (benchmarkValueKRW + dcaAmount) * (1 + spyChange);
    } else {
      // SPY 데이터가 없으면 현금 보유로 가정 (DCA만 추가)
      benchmarkValueKRW += dcaAmount;
    }
    
    final benchmarkReturnRate = (benchmarkValueKRW / investedKRW) - 1;
    benchmarkGrowth.add({
      'date': '${date.year}-${date.month.toString().padLeft(2, '0')}-01',
      'value': benchmarkValueKRW,
      'totalReturnRate': benchmarkReturnRate
    });

    // ✅ 리스트 추가 (Sharpe, MDD 계산용)
    monthlyReturns.add(monthReturn);
    pricesKRW.add(portfolioValueKRW);

    // ✅ 연도별 수익률 누적 (기하평균)
    final year = date.year;
    portfolioAnnualReturns[year] = (portfolioAnnualReturns[year] ?? 0.0) == 0.0
        ? (1 + monthReturn)
        : portfolioAnnualReturns[year]! * (1 + monthReturn);
    
    benchmarkAnnualReturns[year] = (benchmarkAnnualReturns[year] ?? 0.0) == 0.0
        ? (1 + spyChange)
        : benchmarkAnnualReturns[year]! * (1 + spyChange);
  }

  // ────────────── 요약 통계 ──────────────
  final totalReturn = (portfolioValueKRW / investedKRW) - 1;
  final years = max(months.length / 12, 1);
  final annualReturn = pow(1 + totalReturn, 1 / years) - 1;

  final mdd = calculateMDD(pricesKRW);
  final sharpe = calculateSharpe(monthlyReturns);

  final benchmarkTotalReturn = (benchmarkValueKRW / investedKRW) - 1;

  // 연도별 수익률 리스트 변환
  final annualReturnsList = portfolioAnnualReturns.keys.map((year) {
    return {
      'year': year,
      'portfolio': (portfolioAnnualReturns[year]! - 1),
      'benchmark': (benchmarkAnnualReturns[year]! - 1),
    };
  }).toList()
    ..sort((a, b) => (a['year'] as int).compareTo(b['year'] as int));

  // ✅ 클라이언트가 예상하는 형식으로 반환 (DB 기반)
  return {
    'totalReturn': totalReturn,
    'annualizedReturn': annualReturn,
    'volatility': calculateVolatility(monthlyReturns),
    'sharpeRatio': sharpe,
    'maxDrawdown': mdd,
    'effectiveStartDate': ymd(adjustedStart),
    'initialCapital': initialCapital,
    'dcaAmount': dcaAmount,
    'startDate': ymd(startDate),
    'endDate': ymd(endDate),
    'annualReturns': annualReturnsList,
    'history': portfolioGrowth.map((item) => {
      'date': item['date'],
      'value': item['totalSeedKRW'],
    }).toList(),
    'benchmark': {
      'symbol': 'SPY',
      'totalReturn': benchmarkTotalReturn,
      'finalValue': benchmarkValueKRW,
      'history': benchmarkGrowth,
    }
  };
}