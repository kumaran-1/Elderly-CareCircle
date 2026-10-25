import 'package:carecircle_mobile/api_client.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('reportPdfFileName', () {
    test('builds a weekly filename with a date stamp', () {
      expect(reportPdfFileName('weekly', DateTime(2026, 10, 6)), 'carecircle-report-weekly-20261006.pdf');
    });

    test('builds a monthly filename', () {
      expect(reportPdfFileName('monthly', DateTime(2026, 1, 9)), 'carecircle-report-monthly-20260109.pdf');
    });

    test('falls back to weekly for unexpected periods', () {
      expect(reportPdfFileName('yearly', DateTime(2026, 10, 6)), 'carecircle-report-weekly-20261006.pdf');
      expect(reportPdfFileName('', DateTime(2026, 10, 6)), 'carecircle-report-weekly-20261006.pdf');
    });
  });
}
