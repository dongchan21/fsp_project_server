import 'dart:io';

// ────────────── 주가 데이터 로드 ──────────────
Future<Map<String, Map<DateTime, double>>> loadStockData(List<String> tickers) async {
  final data = <String, Map<DateTime, double>>{};

  for (final ticker in tickers) {
    final file = File('data/stocks/$ticker.csv');
    if (!await file.exists()) {
      print('⚠️ Missing file: $ticker.csv');
      continue;
    }

    final lines = await file.readAsLines();
    final prices = <DateTime, double>{};

    for (var i = 1; i < lines.length; i++) {
      var line = lines[i].trim();
      if (line.isEmpty) continue;

      // ✅ 따옴표와 쉼표 문제 해결
      line = line.replaceAll('"', '');
      final parts = line.split(',');

      // ✅ 두 컬럼(date, close)만 사용
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

    data[ticker] = prices;
  }

  return data;
}


// ────────────── 환율 데이터 로드 ──────────────
Future<Map<DateTime, double>> loadUsdKrwRates() async {
  final file = File('data/currency/usdkrw.csv');
  final lines = await file.readAsLines();
  final rates = <DateTime, double>{};

  for (var i = 1; i < lines.length; i++) {
    var line = lines[i].trim();
    if (line.isEmpty) continue;

    // ✅ 따옴표 제거
    line = line.replaceAll('"', '');

    // ✅ 쉼표 문제 해결: 구분자(,)가 여러 개 있을 수 있으므로 split 제한
    // "2006-03-01,971.6" → [2006-03-01, 971.6]
    // "2005-12-01,1,007.50" → [2005-12-01, 1,007.50] → 뒤에서 join
    final parts = line.split(',');
    if (parts.length < 2) continue;

    // ✅ 날짜 부분은 첫 번째 요소
    final dateString = parts.first.trim();

    // ✅ 나머지 숫자 부분을 합쳐서 쉼표 제거
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

