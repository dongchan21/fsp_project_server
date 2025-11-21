import 'dart:convert';
import 'dart:io';
import 'package:fsp_shared/models.dart';
import 'package:postgres/postgres.dart';
import 'package:redis/redis.dart';

class PriceRepository {
  final PostgreSQLConnection _pg;
  final Command _redis;
  final Duration cacheTtl;

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

    // 1. Redis cache
    final cached = await _redis.send_object(['GET', cacheKey]);
    if (cached is String) {
      final data = jsonDecode(cached) as Map<String, dynamic>;
      return PriceQuote.fromJson(data);
    }

    // 2. DB lookup (latest date)
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
      return quote;
    }

    // 3. External fetch stub
    final fetched = await _fetchExternal(symbol);

    // 4. Persist + cache
    await _pg.query(
      'INSERT INTO price(symbol, date, close) VALUES(@symbol, @date, @close)',
      substitutionValues: {
        'symbol': fetched.symbol,
        'date': fetched.date.toUtc(),
        'close': fetched.close,
      },
    );
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

  // Placeholder external API fetch (replace with real provider: Alpha Vantage, Twelve Data, etc.)
  Future<PriceQuote> _fetchExternal(String symbol) async {
    await Future.delayed(const Duration(milliseconds: 200));
    final base = 100 + symbol.codeUnitAt(0) % 50;
    return PriceQuote(symbol: symbol, date: DateTime.now().toUtc(), close: base.toDouble());
  }
}
