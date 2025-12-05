import 'package:test/test.dart';
import 'package:fsp_server/utils/date_utils.dart';

void main() {
  group('DateUtils Tests', () {
    test('ymd should format DateTime correctly', () {
      final date = DateTime(2023, 5, 9);
      expect(ymd(date), '2023-05-09');
      
      final date2 = DateTime(2023, 12, 25);
      expect(ymd(date2), '2023-12-25');
    });

    test('firstOfMonth should return the first day of the month', () {
      final date = DateTime(2023, 5, 20, 15, 30);
      final first = firstOfMonth(date);
      
      expect(first.year, 2023);
      expect(first.month, 5);
      expect(first.day, 1);
      expect(first.hour, 0);
      expect(first.minute, 0);
    });
  });
}
