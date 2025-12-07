import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../utils/date_utils.dart';

class MarketDataService {
  static String get _marketBaseUrl => Platform.environment['MARKET_SERVICE_URL'] ?? 'http://localhost:8081';

  static Future<Map<String, Map<DateTime, double>>> loadPriceHistoryFromApi(
    List<String> symbols,
    DateTime startDate,
    DateTime endDate, {
    http.Client? client,
  }) async {
    final data = <String, Map<DateTime, double>>{};
    final base = _marketBaseUrl;
    final start = firstOfMonth(startDate);
    final end = firstOfMonth(endDate);
    final httpClient = client ?? http.Client();

    try {
      for (final symbol in symbols) {
        final uri = Uri.parse('$base/v1/price/history/${symbol.toUpperCase()}')
            .replace(queryParameters: {
          'start': ymd(start),
          'end': ymd(end),
        });
        final resp = await httpClient.get(uri);
        if (resp.statusCode != 200) {
          throw StateError('price_history_fetch_failed(${symbol}): ${resp.statusCode} ${resp.body}');
        }
        final list = (jsonDecode(resp.body) as List).cast<Map<String, dynamic>>();
        final m = <DateTime, double>{};
        for (final item in list) {
          final dt = DateTime.parse(item['date'] as String);
          final norm = firstOfMonth(dt);
          final close = (item['close'] as num).toDouble();
          m[norm] = close;
        }
        data[symbol] = m;
      }
    } finally {
      if (client == null) {
        httpClient.close();
      }
    }
    return data;
  }

  // 상장일부터 현재 월까지의 월별 첫 거래일 데이터를 미리 가져와서, 심볼별 가장 빠른 날짜를 반환합니다.
  static Future<Map<String, DateTime>> prefetchMonthlyFirstDay(List<String> symbols, {http.Client? client}) async {
    final base = _marketBaseUrl;
    // 항상 먼 과거 날짜부터 백필합니다; yfinance는 첫 상장일부터 반환합니다.
    final start = '2000-01-01';
    final now = DateTime.now();
    final end = ymd(firstOfMonth(DateTime(now.year, now.month)));
    final result = <String, DateTime>{};
    final httpClient = client ?? http.Client();

    try {
      for (final symbol in symbols) {
        final uri = Uri.parse('$base/v1/price/monthly_firstday/${symbol.toUpperCase()}')
            .replace(queryParameters: {'start': start, 'end': end});
        http.Response resp;
        try {
          resp = await httpClient.get(uri);
        } catch (e) {
          stderr.writeln('WARN monthly_firstday_prefetch_conn_failed symbol=$symbol error=$e');
          continue;
        }
        if (resp.statusCode != 200) {
          // 로그를 남기지만 전체 백테스트를 실패 처리하지는 않습니다; 어쨌든 히스토리 데이터로 대체합니다.
          stderr.writeln('WARN monthly_firstday_prefetch_failed symbol=$symbol status=${resp.statusCode} body=${resp.body}');
          continue;
        }
        stderr.writeln('INFO monthly_firstday_prefetch_ok symbol=$symbol');
        try {
          final points = (jsonDecode(resp.body) as List).cast<Map<String, dynamic>>();
          if (points.isNotEmpty) {
            final first = points.first;
            final dt = DateTime.parse(first['date'] as String);
            result[symbol.toUpperCase()] = firstOfMonth(dt);
          }
        } catch (_) {
          // 파싱 오류는 무시하고, 나중에 히스토리 가져오기에 의존합니다.
        }
      }
    } finally {
      if (client == null) {
        httpClient.close();
      }
    }
    return result;
  }

  static Future<Map<DateTime, double>> loadExchangeRatesFromApi(
    DateTime start,
    DateTime end,
    {String pair = 'USDKRW', http.Client? client}
  ) async {
    final base = _marketBaseUrl;
    final s = ymd(firstOfMonth(start));
    final e = ymd(firstOfMonth(end));
    final uri = Uri.parse('$base/v1/forex/history')
        .replace(queryParameters: {'pair': pair.toUpperCase(), 'start': s, 'end': e});
    
    final httpClient = client ?? http.Client();
    http.Response resp;
    try {
      resp = await httpClient.get(uri);
    } finally {
      if (client == null) {
        httpClient.close();
      }
    }

    if (resp.statusCode != 200) {
      throw StateError('forex_history_fetch_failed: ${resp.statusCode} ${resp.body}');
    }
    final list = (jsonDecode(resp.body) as List).cast<Map<String, dynamic>>();
    final m = <DateTime, double>{};
    for (final item in list) {
      final dt = DateTime.parse(item['date'] as String);
      final norm = firstOfMonth(dt);
      final rate = (item['rate'] as num).toDouble();
      m[norm] = rate;
    }
    return m;
  }
}
