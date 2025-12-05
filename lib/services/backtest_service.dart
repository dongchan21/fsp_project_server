import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../utils/db_utils.dart';

class BacktestService {
  static Future<void> saveHistory({
    required int userId,
    required List<String> symbols,
    required List<double> weights,
    required DateTime startDate,
    required DateTime endDate,
    required double initialCapital,
    required double dcaAmount,
    required Map<String, dynamic> resultSummary,
  }) async {
    final conn = await DbUtils.getConnection();
    await conn.query(
      '''
      INSERT INTO backtest_history 
      (user_id, symbols, weights, start_date, end_date, initial_capital, dca_amount, result_summary)
      VALUES (@userId, @symbols, @weights, @startDate, @endDate, @initialCapital, @dcaAmount, @resultSummary)
      ''',
      substitutionValues: {
        'userId': userId,
        'symbols': jsonEncode(symbols),
        'weights': jsonEncode(weights),
        'startDate': startDate,
        'endDate': endDate,
        'initialCapital': initialCapital,
        'dcaAmount': dcaAmount,
        'resultSummary': jsonEncode(resultSummary),
      },
    );
  }

  static Future<List<Map<String, dynamic>>> getHistory(int userId) async {
    final conn = await DbUtils.getConnection();
    final results = await conn.query(
      '''
      SELECT id, symbols, weights, start_date, end_date, initial_capital, dca_amount, result_summary, created_at
      FROM backtest_history
      WHERE user_id = @userId
      ORDER BY created_at DESC
      ''',
      substitutionValues: {'userId': userId},
    );

    return results.map((row) {
      var symbols = row[1];
      if (symbols is String) symbols = jsonDecode(symbols);
      
      var weights = row[2];
      if (weights is String) weights = jsonDecode(weights);

      var resultSummary = row[7];
      if (resultSummary is String) resultSummary = jsonDecode(resultSummary);

      return {
        'id': row[0],
        'symbols': symbols,
        'weights': weights,
        'startDate': row[3].toString().substring(0, 10),
        'endDate': row[4].toString().substring(0, 10),
        'initialCapital': row[5],
        'dcaAmount': row[6],
        'resultSummary': resultSummary,
        'createdAt': row[8].toString(),
      };
    }).toList();
  }
}

Future<Map<String, dynamic>> runBacktest({
  required List<String> symbols,
  required List<double> weights,
  required DateTime startDate,
  required DateTime endDate,
  required double initialCapital,
  required double dcaAmount,
}) async {
  final url = Platform.environment['BACKTEST_SERVICE_URL'] ?? 'http://localhost:8082';
  final uri = Uri.parse('$url/v1/backtests');
  
  final body = {
    'symbols': symbols,
    'weights': weights,
    'startDate': startDate.toIso8601String(),
    'endDate': endDate.toIso8601String(),
    'initialCapital': initialCapital,
    'dcaAmount': dcaAmount,
  };

  final resp = await http.post(
    uri,
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode(body),
  );

  if (resp.statusCode != 200) {
    throw StateError('Backtest failed: ${resp.statusCode} ${resp.body}');
  }

  return jsonDecode(resp.body) as Map<String, dynamic>;
}

