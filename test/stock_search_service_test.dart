import 'dart:convert';
import 'package:test/test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:fsp_server/services/stock_search_service.dart';

void main() {
  group('StockSearchService Tests', () {
    test('searchStocks returns list of stocks on 200 OK', () async {
      final mockResponse = {
        'quotes': [
          {
            'symbol': 'AAPL',
            'shortname': 'Apple Inc.',
            'exchange': 'NASDAQ',
            'quoteType': 'EQUITY'
          },
          {
            'symbol': 'TSLA',
            'shortname': 'Tesla Inc.',
            'exchange': 'NASDAQ',
            'quoteType': 'EQUITY'
          }
        ]
      };

      final client = MockClient((request) async {
        return http.Response(jsonEncode(mockResponse), 200);
      });

      final service = StockSearchService(client: client);
      final results = await service.searchStocks('apple');

      expect(results.length, 2);
      expect(results[0]['symbol'], 'AAPL');
      expect(results[0]['name'], 'Apple Inc.');
      expect(results[1]['symbol'], 'TSLA');
    });

    test('searchStocks returns empty list on empty query', () async {
      final service = StockSearchService();
      final results = await service.searchStocks('   ');
      expect(results, isEmpty);
    });

    test('searchStocks returns empty list on API error', () async {
      final client = MockClient((request) async {
        return http.Response('Not Found', 404);
      });

      final service = StockSearchService(client: client);
      final results = await service.searchStocks('fail');

      expect(results, isEmpty);
    });

    test('searchStocks handles malformed JSON gracefully', () async {
      final client = MockClient((request) async {
        return http.Response('{ invalid json }', 200);
      });

      final service = StockSearchService(client: client);
      final results = await service.searchStocks('error');

      expect(results, isEmpty);
    });
  });
}
