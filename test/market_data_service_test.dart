import 'dart:convert';
import 'package:test/test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:fsp_server/services/market_data_service.dart';
import 'package:fsp_server/utils/date_utils.dart';

void main() {
  group('MarketDataService', () {
    group('loadPriceHistoryFromApi', () {
      test('returns price history when API call is successful', () async {
        final mockResponse = [
          {'date': '2023-01-01', 'close': 100.0},
          {'date': '2023-02-01', 'close': 110.0},
        ];

        final client = MockClient((request) async {
          if (request.url.path.contains('/v1/price/history/AAPL')) {
            return http.Response(jsonEncode(mockResponse), 200);
          }
          return http.Response('Not Found', 404);
        });

        final result = await MarketDataService.loadPriceHistoryFromApi(
          ['AAPL'],
          DateTime(2023, 1, 1),
          DateTime(2023, 2, 1),
          client: client,
        );

        expect(result['AAPL'], isNotNull);
        expect(result['AAPL']!.length, 2);
        expect(result['AAPL']![DateTime(2023, 1, 1)], 100.0);
        expect(result['AAPL']![DateTime(2023, 2, 1)], 110.0);
      });

      test('throws StateError when API call fails', () async {
        final client = MockClient((request) async {
          return http.Response('Internal Server Error', 500);
        });

        expect(
          () => MarketDataService.loadPriceHistoryFromApi(
            ['AAPL'],
            DateTime(2023, 1, 1),
            DateTime(2023, 2, 1),
            client: client,
          ),
          throwsA(isA<StateError>()),
        );
      });
    });

    group('prefetchMonthlyFirstDay', () {
      test('returns earliest date when API call is successful', () async {
        final mockResponse = [
          {'date': '2020-01-01', 'close': 50.0},
        ];

        final client = MockClient((request) async {
          if (request.url.path.contains('/v1/price/monthly_firstday/AAPL')) {
            return http.Response(jsonEncode(mockResponse), 200);
          }
          return http.Response('Not Found', 404);
        });

        final result = await MarketDataService.prefetchMonthlyFirstDay(
          ['AAPL'],
          client: client,
        );

        expect(result['AAPL'], DateTime(2020, 1, 1));
      });

      test('handles API error gracefully (logs warning and continues)', () async {
        final client = MockClient((request) async {
          return http.Response('Internal Server Error', 500);
        });

        final result = await MarketDataService.prefetchMonthlyFirstDay(
          ['AAPL'],
          client: client,
        );

        expect(result, isEmpty);
      });

      test('handles connection error gracefully', () async {
        final client = MockClient((request) async {
          throw Exception('Connection failed');
        });

        final result = await MarketDataService.prefetchMonthlyFirstDay(
          ['AAPL'],
          client: client,
        );

        expect(result, isEmpty);
      });
    });

    group('loadExchangeRatesFromApi', () {
      test('returns exchange rates when API call is successful', () async {
        final mockResponse = [
          {'date': '2023-01-01', 'rate': 1200.0},
          {'date': '2023-02-01', 'rate': 1210.0},
        ];

        final client = MockClient((request) async {
          if (request.url.path.contains('/v1/forex/history')) {
            return http.Response(jsonEncode(mockResponse), 200);
          }
          return http.Response('Not Found', 404);
        });

        final result = await MarketDataService.loadExchangeRatesFromApi(
          DateTime(2023, 1, 1),
          DateTime(2023, 2, 1),
          client: client,
        );

        expect(result.length, 2);
        expect(result[DateTime(2023, 1, 1)], 1200.0);
        expect(result[DateTime(2023, 2, 1)], 1210.0);
      });

      test('throws StateError when API call fails', () async {
        final client = MockClient((request) async {
          return http.Response('Internal Server Error', 500);
        });

        expect(
          () => MarketDataService.loadExchangeRatesFromApi(
            DateTime(2023, 1, 1),
            DateTime(2023, 2, 1),
            client: client,
          ),
          throwsA(isA<StateError>()),
        );
      });
    });
  });
}
