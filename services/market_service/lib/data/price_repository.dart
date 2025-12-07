import 'dart:convert';
import 'dart:io';
import 'package:fsp_shared/models.dart';
import 'package:postgres/postgres.dart';
import 'package:redis/redis.dart';
import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';

class PriceRepository {
  final PostgreSQLConnection _pg;
  final Command _redis;
  final Duration cacheTtl;
  static final Logger _log = Logger('PriceRepository');

  PriceRepository(this._pg, this._redis, {this.cacheTtl = const Duration(minutes: 5)});

  static Future<PostgreSQLConnection> connectPostgres() async {
    final host = Platform.environment['POSTGRES_HOST'] ?? 'localhost';
    final user = Platform.environment['POSTGRES_USER'] ?? 'fsp';
    final password = Platform.environment['POSTGRES_PASSWORD'] ?? 'fsp';
    final db = Platform.environment['POSTGRES_DB'] ?? 'fsp';
    final port = int.tryParse(Platform.environment['POSTGRES_PORT'] ?? '5432') ?? 5432;
    final conn = PostgreSQLConnection(host, port, db, username: user, password: password);
    await conn.open();
    return conn;
  }

  static Future<Command> connectRedis() async {
    final host = Platform.environment['REDIS_HOST'] ?? 'localhost';
    final port = int.tryParse(Platform.environment['REDIS_PORT'] ?? '6379') ?? 6379;
    final redis = RedisConnection();
    return redis.connect(host, port);
  }

  Future<PriceQuote> getPrice(String symbol) async {
    final cacheKey = 'price:$symbol';
    _log.info('price_fetch_start symbol=${symbol.toUpperCase()}');

    // 1. Redis 캐시
    final cached = await _redis.send_object(['GET', cacheKey]);
    if (cached is String) {
      final data = jsonDecode(cached) as Map<String, dynamic>;
      final quote = PriceQuote.fromJson(data);
      _log.info('price_source=cache symbol=${quote.symbol} date=${quote.date.toIso8601String()} close=${quote.close}');
      return quote;
    }

    // 2. DB 조회 (최신 날짜)
    final rows = await _pg.mappedResultsQuery(
      'SELECT id, symbol, date, close FROM price WHERE symbol = @symbol ORDER BY date DESC LIMIT 1',
      substitutionValues: {'symbol': symbol},
    );
    if (rows.isNotEmpty) {
      final r = rows.first.values.first;
      final rawClose = r['close'];
      double closeValue;
      if (rawClose is num) {
        closeValue = rawClose.toDouble();
      } else if (rawClose is String) {
        closeValue = double.tryParse(rawClose) ?? double.nan;
      } else {
        throw StateError('Unsupported close value type: ${rawClose.runtimeType}');
      }
      if (closeValue.isNaN) {
        throw StateError('Could not parse close value for symbol $symbol');
      }
      final dateRaw = r['date'];
      final dateValue = dateRaw is DateTime
          ? dateRaw
          : DateTime.tryParse(dateRaw.toString()) ?? DateTime.now().toUtc();
      final quote = PriceQuote(
        id: r['id'] as int?,
        symbol: r['symbol'] as String,
        date: dateValue,
        close: closeValue,
      );
      await _cacheQuote(cacheKey, quote);
      _log.info('price_source=db symbol=${quote.symbol} date=${quote.date.toIso8601String()} close=${quote.close}');
      return quote;
    }

    // 3. 외부 데이터 가져오기 (fetcher가 이미 ON CONFLICT로 DB에 upsert함)
    final fetched = await _fetchExternal(symbol);
    _log.info('price_source=external symbol=${fetched.symbol} date=${fetched.date.toIso8601String()} close=${fetched.close}');

    // 4. 캐시만 수행 (중복 삽입 / 잠재적 고유 제약 조건 충돌 방지)
    await _cacheQuote(cacheKey, fetched);
    return fetched;
  }

  Future<void> _cacheQuote(String key, PriceQuote quote) async {
    final payload = jsonEncode(quote.toJson());
    await _redis.send_object(['SET', key, payload, 'EX', cacheTtl.inSeconds.toString()]);
  }

  Future<List<Map<String, dynamic>>> getPriceHistory(String symbol, DateTime start, DateTime end) async {
    final s = start.toUtc().toIso8601String().split('T').first;
    final e = end.toUtc().toIso8601String().split('T').first;
    final cacheKey = 'pricehist:$symbol:$s:$e';

    // 1) Try cache
    final cached = await _redis.send_object(['GET', cacheKey]);
    if (cached is String) {
      final list = (jsonDecode(cached) as List).cast<Map<String, dynamic>>();
      return list;
    }

    // 2) Query DB
    final rows = await _pg.mappedResultsQuery(
      'SELECT date, close FROM price WHERE symbol = @symbol AND date >= @start AND date <= @end ORDER BY date ASC',
      substitutionValues: {
        'symbol': symbol,
        'start': start.toUtc(),
        'end': end.toUtc(),
      },
    );
    final result = <Map<String, dynamic>>[];
    for (final row in rows) {
      final r = row.values.first;
      final dateRaw = r['date'];
      final dateValue = dateRaw is DateTime ? dateRaw : DateTime.tryParse(dateRaw.toString()) ?? DateTime.now().toUtc();
      final rawClose = r['close'];
      double closeValue;
      if (rawClose is num) {
        closeValue = rawClose.toDouble();
      } else if (rawClose is String) {
        closeValue = double.tryParse(rawClose) ?? double.nan;
      } else {
        throw StateError('Unsupported close value type: ${rawClose.runtimeType}');
      }
      if (closeValue.isNaN) {
        throw StateError('Could not parse close value for symbol $symbol');
      }
      result.add({
        'date': dateValue.toUtc().toIso8601String(),
        'close': closeValue,
      });
    }

    // 3) Cache result
    await _redis.send_object(['SET', cacheKey, jsonEncode(result), 'EX', cacheTtl.inSeconds.toString()]);
    return result;
  }

  // Monthly first trading day history (backfill via external fetcher if any month missing)
  Future<List<Map<String, dynamic>>> getMonthlyFirstDayHistory(String symbol, DateTime start, DateTime end) async {
    final sSym = symbol.toUpperCase();
    // Normalize to first day of month for start/end range
    final normStart = DateTime.utc(start.year, start.month, 1);
    final normEnd = DateTime.utc(end.year, end.month, 1);
    final cacheKey = 'price:firstday:$sSym:${normStart.toIso8601String().split('T').first}:${normEnd.toIso8601String().split('T').first}';

    final cached = await _redis.send_object(['GET', cacheKey]);
    if (cached is String) {
      return (jsonDecode(cached) as List).cast<Map<String, dynamic>>();
    }

    // Pull all rows in range
    final rows = await _pg.mappedResultsQuery(
      'SELECT date, close FROM price WHERE symbol = @symbol AND date >= @start AND date <= @end ORDER BY date ASC',
      substitutionValues: {
        'symbol': sSym,
        'start': normStart,
        'end': normEnd.add(const Duration(days: 35)), // include entire last month window
      },
    );

    Map<String, Map<String, dynamic>> byMonth = {};
    for (final row in rows) {
      final r = row.values.first;
      final dateRaw = r['date'];
      final dateValue = dateRaw is DateTime ? dateRaw : DateTime.tryParse(dateRaw.toString()) ?? DateTime.now().toUtc();
      final ym = '${dateValue.year}-${dateValue.month.toString().padLeft(2, '0')}';
      if (!byMonth.containsKey(ym) || dateValue.isBefore(DateTime.parse(byMonth[ym]!['date'] as String))) {
        final rawClose = r['close'];
        double closeValue;
        if (rawClose is num) {
          closeValue = rawClose.toDouble();
        } else if (rawClose is String) {
          closeValue = double.tryParse(rawClose) ?? double.nan;
        } else {
          throw StateError('Unsupported close value type: ${rawClose.runtimeType}');
        }
        if (closeValue.isNaN) continue;
        byMonth[ym] = {
          'date': dateValue.toUtc().toIso8601String(),
          'close': closeValue,
        };
      }
    }

    // Determine missing months
    final missing = <DateTime>[];
    DateTime cursor = normStart;
    while (!cursor.isAfter(normEnd)) {
      final ym = '${cursor.year}-${cursor.month.toString().padLeft(2, '0')}';
      if (!byMonth.containsKey(ym)) {
        missing.add(cursor);
      }
      cursor = DateTime.utc(cursor.year, cursor.month + 1, 1);
    }

    if (missing.isNotEmpty) {
      _log.info('monthly_firstday_backfill symbol=$sSym missing_months=${missing.length} range=${normStart.toIso8601String()}..${normEnd.toIso8601String()}');
      // Call external fetcher to backfill entire range (simplify) instead of per-missing month
      try {
        final baseUrl = Platform.environment['PRICE_FETCHER_URL'] ?? 'http://localhost:8090';
        final uri = Uri.parse('$baseUrl/prices/history_firstday/$sSym?start=${normStart.toIso8601String().split('T').first}&end=${normEnd.toIso8601String().split('T').first}');
        final resp = await http.get(uri);
        if (resp.statusCode != 200) {
          _log.warning('external_monthly_fetch_failed status=${resp.statusCode} body=${resp.body}');
        } else {
          final data = jsonDecode(resp.body) as Map<String, dynamic>;
          final points = (data['points'] as List).cast<Map<String, dynamic>>();
          for (final p in points) {
            final dt = DateTime.parse(p['date']);
            final ym = '${dt.year}-${dt.month.toString().padLeft(2, '0')}';
            byMonth.putIfAbsent(ym, () => {
                  'date': dt.toUtc().toIso8601String(),
                  'close': (p['close'] as num).toDouble(),
                });
          }
        }
      } catch (e) {
        _log.severe('monthly_firstday_external_error symbol=$sSym error=$e');
      }
    }

    final result = byMonth.values.toList()
      ..sort((a, b) => (a['date'] as String).compareTo(b['date'] as String));
    await _redis.send_object(['SET', cacheKey, jsonEncode(result), 'EX', (cacheTtl.inSeconds * 6).toString()]);
    return result;
  }

  // External fetch via Python FastAPI price fetcher (PRICE_FETCHER_URL)
  Future<PriceQuote> _fetchExternal(String symbol) async {
    final baseUrl = Platform.environment['PRICE_FETCHER_URL'] ?? 'http://localhost:8090';
    final uri = Uri.parse('$baseUrl/prices/latest/${symbol.toUpperCase()}');
    final resp = await http.get(uri);
    if (resp.statusCode != 200) {
      throw StateError('external_fetch_failed ${resp.statusCode}: ${resp.body}');
    }
    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    final closeRaw = data['close'];
    final close = closeRaw is num ? closeRaw.toDouble() : double.parse(closeRaw.toString());
    final dateStr = data['date'].toString();
    final dt = DateTime.tryParse(dateStr) ?? DateTime.now().toUtc();
    return PriceQuote(symbol: symbol.toUpperCase(), date: dt.toUtc(), close: close);
  }
}
