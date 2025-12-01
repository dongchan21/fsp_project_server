import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import '../services/stock_search_service.dart';

class StockRoutes {
  final StockSearchService _service = StockSearchService();

  Router get router {
    final router = Router();

    router.get('/search', (Request request) async {
      final query = request.url.queryParameters['query'];
      
      if (query == null || query.isEmpty) {
        return Response.ok(
          jsonEncode({'results': []}),
          headers: {'Content-Type': 'application/json'},
        );
      }

      final results = await _service.searchStocks(query);

      return Response.ok(
        jsonEncode({'results': results}),
        headers: {'Content-Type': 'application/json'},
      );
    });

    return router;
  }
}
