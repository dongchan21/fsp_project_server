import 'dart:convert';
import 'dart:io';
import 'package:postgres/postgres.dart';
import 'package:redis/redis.dart';

class ExchangeRateRepository {
  final PostgreSQLConnection _pg;
  final Command _redis;
  final Duration cacheTtl;

  ExchangeRateRepository(this._pg, this._redis, {this.cacheTtl = const Duration(minutes: 5)});

  Future<Map<String, dynamic>> getLatest(String pair) async {
    final cacheKey = 'fx:latest:${pair.toUpperCase()}';
    final cached = await _redis.send_object(['GET', cacheKey]);
    if (cached is String) {
      return jsonDecode(cached) as Map<String, dynamic>;
    }

    final rows = await _pg.mappedResultsQuery(
      'SELECT id, date, rate FROM exchange_rate ORDER BY date DESC LIMIT 1',
    );
    if (rows.isEmpty) {
      throw StateError('no_rate');
    }
    final r = rows.first.values.first;
    final dateRaw = r['date'];
    final dateValue = dateRaw is DateTime ? dateRaw : DateTime.tryParse(dateRaw.toString()) ?? DateTime.now().toUtc();
    final rawRate = r['rate'];
    double rateValue;
    if (rawRate is num) {
      rateValue = rawRate.toDouble();
    } else if (rawRate is String) {
      rateValue = double.tryParse(rawRate) ?? double.nan;
    } else {
      throw StateError('Unsupported rate value type: ${rawRate.runtimeType}');
    }
    if (rateValue.isNaN) {
      throw StateError('Could not parse rate value');
    }
    final payload = {
      'id': r['id'] as int?,
      'date': dateValue.toUtc().toIso8601String(),
      'rate': rateValue,
    };
    await _redis.send_object(['SET', cacheKey, jsonEncode(payload), 'EX', cacheTtl.inSeconds.toString()]);
    return payload;
  }

  Future<List<Map<String, dynamic>>> getHistory(String pair, DateTime start, DateTime end) async {
    final s = start.toUtc().toIso8601String().split('T').first;
    final e = end.toUtc().toIso8601String().split('T').first;
    final cacheKey = 'fxhist:${pair.toUpperCase()}:$s:$e';

    final cached = await _redis.send_object(['GET', cacheKey]);
    if (cached is String) {
      return (jsonDecode(cached) as List).cast<Map<String, dynamic>>();
    }

    final rows = await _pg.mappedResultsQuery(
      'SELECT date, rate FROM exchange_rate WHERE date >= @start AND date <= @end ORDER BY date ASC',
      substitutionValues: {
        'start': start.toUtc(),
        'end': end.toUtc(),
      },
    );
    final result = <Map<String, dynamic>>[];
    for (final row in rows) {
      final r = row.values.first;
      final dateRaw = r['date'];
      final dateValue = dateRaw is DateTime ? dateRaw : DateTime.tryParse(dateRaw.toString()) ?? DateTime.now().toUtc();
      final rawRate = r['rate'];
      double rateValue;
      if (rawRate is num) {
        rateValue = rawRate.toDouble();
      } else if (rawRate is String) {
        rateValue = double.tryParse(rawRate) ?? double.nan;
      } else {
        throw StateError('Unsupported rate value type: ${rawRate.runtimeType}');
      }
      if (rateValue.isNaN) {
        throw StateError('Could not parse rate value');
      }
      result.add({
        'date': dateValue.toUtc().toIso8601String(),
        'rate': rateValue,
      });
    }

    await _redis.send_object(['SET', cacheKey, jsonEncode(result), 'EX', cacheTtl.inSeconds.toString()]);
    return result;
  }
}
