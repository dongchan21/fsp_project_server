import 'dart:math';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'math_utils.dart';

// Data now sourced via Market Service HTTP APIs which apply Redis->DB fallback internally.

String _marketBaseUrl() => Platform.environment['MARKET_SERVICE_URL'] ?? 'http://localhost:8081';

String _ymd(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}'.toString();

DateTime _firstOfMonth(DateTime d) => DateTime(d.year, d.month, 1);

Future<Map<String, Map<DateTime, double>>> _loadPriceHistoryFromApi(
  List<String> symbols,
  DateTime startDate,
  DateTime endDate,
) async {
  final data = <String, Map<DateTime, double>>{};
  final base = _marketBaseUrl();
  final start = _firstOfMonth(startDate);
  final end = _firstOfMonth(endDate);
  for (final symbol in symbols) {
    final uri = Uri.parse('$base/v1/price/history/${symbol.toUpperCase()}')
        .replace(queryParameters: {
      'start': _ymd(start),
      'end': _ymd(end),
    });
    final resp = await http.get(uri);
    if (resp.statusCode != 200) {
      throw StateError('price_history_fetch_failed(${symbol}): ${resp.statusCode} ${resp.body}');
    }
    final list = (jsonDecode(resp.body) as List).cast<Map<String, dynamic>>();
    final m = <DateTime, double>{};
    for (final item in list) {
      final dt = DateTime.parse(item['date'] as String);
      final norm = _firstOfMonth(dt);
      final close = (item['close'] as num).toDouble();
      m[norm] = close;
    }
    data[symbol] = m;
  }
  return data;
}

// Prefetch monthly first trading day data from listing to current month, and return earliest date per symbol.
Future<Map<String, DateTime>> _prefetchMonthlyFirstDay(List<String> symbols) async {
  final base = _marketBaseUrl();
  // Always backfill from a far past date; yfinance returns from the first listing date.
  final start = '2000-01-01';
  final now = DateTime.now();
  final end = _ymd(_firstOfMonth(DateTime(now.year, now.month)));
  final result = <String, DateTime>{};
  for (final symbol in symbols) {
    final uri = Uri.parse('$base/v1/price/monthly_firstday/${symbol.toUpperCase()}')
        .replace(queryParameters: {'start': start, 'end': end});
    http.Response resp;
    try {
      resp = await http.get(uri);
    } catch (e) {
      stderr.writeln('WARN monthly_firstday_prefetch_conn_failed symbol=$symbol error=$e');
      continue;
    }
    if (resp.statusCode != 200) {
      // Log but do not fail the entire backtest; fallback to history anyway.
      stderr.writeln('WARN monthly_firstday_prefetch_failed symbol=$symbol status=${resp.statusCode} body=${resp.body}');
      continue;
    }
    stderr.writeln('INFO monthly_firstday_prefetch_ok symbol=$symbol');
    try {
      final points = (jsonDecode(resp.body) as List).cast<Map<String, dynamic>>();
      if (points.isNotEmpty) {
        final first = points.first;
        final dt = DateTime.parse(first['date'] as String);
        result[symbol.toUpperCase()] = _firstOfMonth(dt);
      }
    } catch (_) {
      // ignore parse errors, rely on history fetch later
    }
  }
  return result;
}

Future<Map<DateTime, double>> _loadExchangeRatesFromApi(
  DateTime start,
  DateTime end,
  {String pair = 'USDKRW'}
) async {
  final base = _marketBaseUrl();
  final s = _ymd(_firstOfMonth(start));
  final e = _ymd(_firstOfMonth(end));
  final uri = Uri.parse('$base/v1/forex/history')
      .replace(queryParameters: {'pair': pair.toUpperCase(), 'start': s, 'end': e});
  final resp = await http.get(uri);
  if (resp.statusCode != 200) {
    throw StateError('forex_history_fetch_failed: ${resp.statusCode} ${resp.body}');
  }
  final list = (jsonDecode(resp.body) as List).cast<Map<String, dynamic>>();
  final m = <DateTime, double>{};
  for (final item in list) {
    final dt = DateTime.parse(item['date'] as String);
    final norm = _firstOfMonth(dt);
    final rate = (item['rate'] as num).toDouble();
    m[norm] = rate;
  }
  return m;
}

// Legacy direct-DB loader functions removed after integration with market_service APIs.

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
  final earliestMap = await _prefetchMonthlyFirstDay(symbols);
  DateTime adjustedStart = _firstOfMonth(startDate);
  if (earliestMap.isNotEmpty) {
    DateTime latestEarliest = earliestMap.values.first;
    for (final dt in earliestMap.values) {
      if (dt.isAfter(latestEarliest)) latestEarliest = dt;
    }
    if (latestEarliest.isAfter(adjustedStart)) {
      adjustedStart = latestEarliest;
    }
  }
  final stockData = await _loadPriceHistoryFromApi({...symbols, 'SPY'}.toList(), adjustedStart, endDate);
  final usdkrw = await _loadExchangeRatesFromApi(adjustedStart, endDate); // currently unused; placeholder for FX conversion

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
      adjustedStart = _firstOfMonth(latestEarliestFromData);
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
      stderr.writeln('INFO skip_month_missing_data date=${_ymd(date)}');
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
    if (spyPrices != null && spyPrices[date] != null && spyPrices[prevDate] != null) {
      final spyChange = (spyPrices[date]! / spyPrices[prevDate]!) - 1;
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
  }

  // ────────────── 요약 통계 ──────────────
  final totalReturn = (portfolioValueKRW / investedKRW) - 1;
  final years = max(months.length / 12, 1);
  final annualReturn = pow(1 + totalReturn, 1 / years) - 1;

  final mdd = calculateMDD(pricesKRW);
  final sharpe = calculateSharpe(monthlyReturns);

  final benchmarkTotalReturn = (benchmarkValueKRW / investedKRW) - 1;

  // ✅ 클라이언트가 예상하는 형식으로 반환 (DB 기반)
  return {
    'totalReturn': totalReturn,
    'annualizedReturn': annualReturn,
    'volatility': calculateVolatility(monthlyReturns),
    'sharpeRatio': sharpe,
    'maxDrawdown': mdd,
    'effectiveStartDate': _ymd(adjustedStart),
    'initialCapital': initialCapital,
    'dcaAmount': dcaAmount,
    'startDate': _ymd(startDate),
    'endDate': _ymd(endDate),
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
