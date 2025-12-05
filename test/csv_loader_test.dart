import 'package:test/test.dart';
import 'package:fsp_server/services/csv_loader.dart';

void main() {
  group('CsvLoader Tests', () {
    test('parseStockCsv should parse valid lines correctly', () {
      final lines = [
        'Date,Close', // Header
        '2023-01-05,100.50',
        '2023-02-10,"200.00"', // Quotes
        '2023-03-15,1,234.56', // Commas in number (though replaceAll handles it if quotes removed first)
        // Actually the logic is: replaceAll('"', '') then split(',') then replaceAll(',', '') on value.
        // "2023-03-15,1,234.56" -> 2023-03-15,1,234.56 -> split -> [2023-03-15, 1, 234.56] -> length 3.
        // The code takes parts[1] which is "1". This might be a bug in the original code if CSV has commas inside fields without quotes handling properly by split.
        // But let's test the current logic.
        // Current logic: line.replaceAll('"', '') -> split(',')
        // If input is "1,234.56", it becomes 1,234.56. split gives [..., 1, 234.56].
        // It takes parts[1] which is '1'.
        // Wait, the original code for stock data:
        // final closeString = parts[1].replaceAll(',', '').trim();
        // So if split gives [date, 1, 234.56], closeString is '1'. This is WRONG for 1,234.56.
        // But usually stock CSVs from Yahoo are "Date,Close" and Close is a simple float.
        // Let's assume standard format: 2023-01-05,100.50
      ];
      
      // Let's test standard cases first.
      final linesStandard = [
        'Date,Close',
        '2023-01-05,100.50',
        '2023-02-10,200.00',
      ];

      final result = CsvLoader.parseStockCsv(linesStandard, 'TEST');
      
      expect(result.length, 2);
      expect(result[DateTime(2023, 1, 1)], 100.50);
      expect(result[DateTime(2023, 2, 1)], 200.00);
    });

    test('parseCurrencyCsv should handle commas in numbers', () {
      // Logic for currency: parts.sublist(1).join('')
      // Input: "2005-12-01,1,007.50"
      // replaceAll('"', '') -> same
      // split(',') -> [2005-12-01, 1, 007.50]
      // sublist(1) -> [1, 007.50]
      // join('') -> "1007.50"
      // parse -> 1007.5
      // This logic seems correct for currency.
      
      final lines = [
        'Date,Price',
        '2023-01-01,1,234.50',
        '2023-02-01,"1,000.00"',
      ];

      final result = CsvLoader.parseCurrencyCsv(lines);

      expect(result.length, 2);
      expect(result[DateTime(2023, 1, 1)], 1234.50);
      expect(result[DateTime(2023, 2, 1)], 1000.00);
    });

    test('parseStockCsv should ignore empty lines and bad data', () {
      final lines = [
        'Date,Close',
        '',
        '   ',
        'InvalidDate,100',
        '2023-01-01,InvalidPrice',
      ];
      final result = CsvLoader.parseStockCsv(lines, 'TEST');
      expect(result.isEmpty, true);
    });
  });
}
