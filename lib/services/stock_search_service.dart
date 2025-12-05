import 'dart:convert';
import 'package:http/http.dart' as http;

class StockSearchService {
  static const String _baseUrl = "https://query2.finance.yahoo.com/v1/finance/search";
  final http.Client _client;

  StockSearchService({http.Client? client}) : _client = client ?? http.Client();

  Future<List<Map<String, String>>> searchStocks(String query) async {
    if (query.trim().isEmpty) return [];

    final requestUrl = '$_baseUrl?q=$query&quotesCount=20&newsCount=0';
    final url = Uri.parse(requestUrl);

    try {
      final response = await _client.get(url, headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36'
      });

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['quotes'] == null) return [];

        final quotes = data['quotes'] as List<dynamic>;

        return quotes.map<Map<String, String>>((item) {
          return {
            'symbol': item['symbol']?.toString() ?? '',
            'name': item['shortname']?.toString() ?? item['longname']?.toString() ?? 'Unknown',
            'exchange': item['exchange']?.toString() ?? '',
            'type': item['quoteType']?.toString() ?? '',
          };
        }).where((item) => item['symbol']!.isNotEmpty).toList();
      } else {
        print('Yahoo API Error: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('Error searching stocks on server: $e');
      return [];
    }
  }
}
