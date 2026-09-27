import 'package:flutter_test/flutter_test.dart';
import 'package:timesheet/database/models.dart';
import 'package:timesheet/services/backup_dedupe.dart';

void main() {
  test('timeEntryDedupeKey matches same entry fields', () {
    final date = DateTime(2025, 3, 1);
    final start = DateTime(2025, 3, 1, 9, 0);
    final end = DateTime(2025, 3, 1, 12, 0);
    final entry = TimeEntry(
      id: 1,
      workplaceId: 2,
      date: date,
      startTime: start,
      endTime: end,
      hourlyRate: 50,
    );
    expect(
      timeEntryDedupeKeyFromEntry(entry),
      timeEntryDedupeKey(
        workplaceId: 2,
        date: date,
        startTime: start,
        endTime: end,
      ),
    );
  });

  test('savedInvoiceDedupeKey uses workplace and number', () {
    expect(
      savedInvoiceDedupeKey(workplaceId: 1, invoiceNumber: '03/25'),
      '1|03/25',
    );
  });

  test('pdfBasename normalizes paths', () {
    expect(pdfBasename(r'C:\docs\invoices\inv.pdf'), 'inv.pdf');
    expect(pdfBasename('invoices/foo.pdf'), 'foo.pdf');
  });
}
