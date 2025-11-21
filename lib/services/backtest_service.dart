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

// Prefetch monthly first trading day data to ensure DB is populated before standard history fetch.
Future<void> _prefetchMonthlyFirstDay(List<String> symbols, DateTime startDate, DateTime endDate) async {
  final base = _marketBaseUrl();
  final start = _ymd(_firstOfMonth(startDate));
  final end = _ymd(_firstOfMonth(endDate));
  for (final symbol in symbols) {
    final uri = Uri.parse('$base/v1/price/monthly_firstday/${symbol.toUpperCase()}')
        .replace(queryParameters: {'start': start, 'end': end});
    final resp = await http.get(uri);
    if (resp.statusCode != 200) {
      // Log but do not fail the entire backtest; fallback to history anyway.
      stderr.writeln('WARN monthly_firstday_prefetch_failed symbol=$symbol status=${resp.statusCode} body=${resp.body}');
    } else {
      stderr.writeln('INFO monthly_firstday_prefetch_ok symbol=$symbol');
    }
  }
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
  final months = <DateTime>[];
  for (var d = DateTime(startDate.year, startDate.month);
      d.isBefore(endDate);
      d = DateTime(d.year, d.month + 1)) {
    months.add(d);
  }

  final monthlyReturns = <double>[];
  final pricesKRW = <double>[];
  // Prefetch monthly first trading day rows (backfill missing months)
  await _prefetchMonthlyFirstDay(symbols, startDate, endDate);
  final stockData = await _loadPriceHistoryFromApi(symbols, startDate, endDate);
  final usdkrw = await _loadExchangeRatesFromApi(startDate, endDate); // currently unused; placeholder for FX conversion

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

  // ✅ 클라이언트가 예상하는 형식으로 반환 (DB 기반)
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
