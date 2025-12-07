import 'dart:io';

class CsvLoader {
  // ────────────── 주가 데이터 로드 ──────────────
  static Future<Map<String, Map<DateTime, double>>> loadStockData(List<String> tickers) async {
    final data = <String, Map<DateTime, double>>{};

    for (final ticker in tickers) {
      final file = File('data/stocks/$ticker.csv');
      if (!await file.exists()) {
        print('⚠️ Missing file: $ticker.csv');
        continue;
      }

      final lines = await file.readAsLines();
      data[ticker] = parseStockCsv(lines, ticker);
    }

    return data;
  }

  // 테스트 가능한 순수 함수로 분리
  static Map<DateTime, double> parseStockCsv(List<String> lines, String ticker) {
    final prices = <DateTime, double>{};

    for (var i = 1; i < lines.length; i++) {
      var line = lines[i].trim();
      if (line.isEmpty) continue;

      // 따옴표와 쉼표 문제 해결
      line = line.replaceAll('"', '');
      final parts = line.split(',');

      // 두 컬럼(date, close)만 사용
      if (parts.length < 2) continue;

      final dateString = parts[0].trim();
      final closeString = parts[1].replaceAll(',', '').trim();

      try {
        // 날짜 정규화 (YYYY-MM-DD → YYYY-MM-01 형태로 저장)
        final parsed = DateTime.parse(dateString);
        final normalized = DateTime(parsed.year, parsed.month, 1);

        final close = double.parse(closeString);
        prices[normalized] = close;
      } catch (e) {
        print('⚠️ Parse error in $ticker line $i: $line');
      }
    }
    return prices;
  }

  // ────────────── 환율 데이터 로드 ──────────────
  static Future<Map<DateTime, double>> loadUsdKrwRates() async {
    final file = File('data/currency/usdkrw.csv');
    if (!await file.exists()) return {};
    
    final lines = await file.readAsLines();
    return parseCurrencyCsv(lines);
  }

  // 테스트 가능한 순수 함수로 분리
  static Map<DateTime, double> parseCurrencyCsv(List<String> lines) {
    final rates = <DateTime, double>{};

    for (var i = 1; i < lines.length; i++) {
      var line = lines[i].trim();
      if (line.isEmpty) continue;

      // 따옴표 제거
      line = line.replaceAll('"', '');

      // 쉼표 문제 해결: 구분자(,)가 여러 개 있을 수 있으므로 split 제한
      final parts = line.split(',');
      if (parts.length < 2) continue;

      // 날짜 부분은 첫 번째 요소
      final dateString = parts.first.trim();

      // 나머지 숫자 부분을 합쳐서 쉼표 제거
      final numberString =
          parts.sublist(1).join('').replaceAll(',', '').trim();

      try {
        final date = DateTime.parse(dateString);
        final value = double.parse(numberString);
        rates[DateTime(date.year, date.month, 1)] = value;
      } catch (e) {
        print('⚠️ CSV parse error on line $i: $line');
      }
    }
    return rates;
  }
}

