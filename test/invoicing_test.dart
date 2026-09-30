import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:timesheet/database/database_helper.dart';
import 'package:timesheet/database/models.dart';

Future<DatabaseHelper> _openTestDb() async {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  return DatabaseHelper.openForTesting(
    () => openDatabase(
      inMemoryDatabasePath,
      version: 3,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE workplaces (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            default_hourly_rate REAL NOT NULL,
            recipient_name TEXT NOT NULL DEFAULT '',
            recipient_address TEXT NOT NULL DEFAULT '',
            sort_order INTEGER NOT NULL DEFAULT 0
          )
        ''');
        await db.execute('''
          CREATE TABLE saved_invoices (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            workplace_id INTEGER NOT NULL,
            created_at TEXT NOT NULL,
            invoice_number TEXT NOT NULL,
            title TEXT NOT NULL,
            amount REAL NOT NULL,
            recipient_name TEXT NOT NULL DEFAULT '',
            recipient_address TEXT NOT NULL DEFAULT '',
            date_range_start TEXT NOT NULL,
            date_range_end TEXT NOT NULL,
            bullet_lines TEXT NOT NULL DEFAULT '',
            pdf_file_path TEXT NOT NULL,
            sender_snapshot TEXT NOT NULL DEFAULT '',
            footer_snapshot TEXT NOT NULL DEFAULT '',
            teilbetrag_label TEXT NOT NULL DEFAULT 'Betrag',
            vat_text_snapshot TEXT NOT NULL DEFAULT '',
            payment_text_snapshot TEXT NOT NULL DEFAULT '',
            footnote_text_snapshot TEXT NOT NULL DEFAULT ''
          )
        ''');
        await db.execute('''
          CREATE TABLE time_entries (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            workplace_id INTEGER NOT NULL,
            project_id INTEGER,
            date TEXT NOT NULL,
            start_time TEXT NOT NULL,
            end_time TEXT NOT NULL,
            hourly_rate REAL NOT NULL,
            notes TEXT NOT NULL DEFAULT '',
            source TEXT NOT NULL DEFAULT 'manual',
            invoiced_invoice_id INTEGER
          )
        ''');
      },
    ),
  );
}

void main() {
  test('markEntriesInvoiced marks only unbilled entries in range', () async {
    final db = await _openTestDb();
    final workplaceId = await db.insertWorkplace(
      Workplace(id: 0, name: 'Test', defaultHourlyRate: 60),
    );

    await db.insertEntry(
      TimeEntry(
        id: 0,
        workplaceId: workplaceId,
        date: DateTime(2026, 9, 1),
        startTime: DateTime(2026, 9, 1, 9),
        endTime: DateTime(2026, 9, 1, 10),
        hourlyRate: 60,
      ),
    );
    await db.insertEntry(
      TimeEntry(
        id: 0,
        workplaceId: workplaceId,
        date: DateTime(2026, 9, 15),
        startTime: DateTime(2026, 9, 15, 9),
        endTime: DateTime(2026, 9, 15, 10),
        hourlyRate: 60,
      ),
    );
    await db.insertEntry(
      TimeEntry(
        id: 0,
        workplaceId: workplaceId,
        date: DateTime(2026, 10, 1),
        startTime: DateTime(2026, 10, 1, 9),
        endTime: DateTime(2026, 10, 1, 10),
        hourlyRate: 60,
      ),
    );

    final invoiceId = await db.insertSavedInvoice(
      SavedInvoice(
        id: 0,
        workplaceId: workplaceId,
        createdAt: DateTime(2026, 9, 30),
        invoiceNumber: '01/26',
        title: 'September',
        amount: 120,
        recipientName: 'Client',
        recipientAddress: '',
        dateRangeStart: DateTime(2026, 9, 1),
        dateRangeEnd: DateTime(2026, 9, 30),
        bulletLines: const [],
        pdfFilePath: '/tmp/x.pdf',
        senderSnapshot: '',
        footerSnapshot: '',
      ),
    );

    await db.markEntriesInvoiced(
      workplaceId: workplaceId,
      start: DateTime(2026, 9, 1),
      end: DateTime(2026, 9, 30),
      invoiceId: invoiceId,
    );

    final entries = await db.getEntries(workplaceId: workplaceId);
    expect(entries.where((e) => e.invoicedInvoiceId == invoiceId).length, 2);
    expect(
      entries.singleWhere((e) => e.date.month == 10).invoicedInvoiceId,
      isNull,
    );

    await db.deleteSavedInvoice(invoiceId);
    final afterDelete = await db.getEntries(workplaceId: workplaceId);
    expect(afterDelete.every((e) => e.invoicedInvoiceId == null), isTrue);
  });

  test('getUnbilledDateSpan returns first and last unbilled dates', () async {
    final db = await _openTestDb();
    final workplaceId = await db.insertWorkplace(
      Workplace(id: 0, name: 'Test', defaultHourlyRate: 60),
    );

    await db.insertEntry(
      TimeEntry(
        id: 0,
        workplaceId: workplaceId,
        date: DateTime(2026, 8, 5),
        startTime: DateTime(2026, 8, 5, 9),
        endTime: DateTime(2026, 8, 5, 10),
        hourlyRate: 60,
      ),
    );
    await db.insertEntry(
      TimeEntry(
        id: 0,
        workplaceId: workplaceId,
        date: DateTime(2026, 8, 20),
        startTime: DateTime(2026, 8, 20, 9),
        endTime: DateTime(2026, 8, 20, 10),
        hourlyRate: 60,
      ),
    );

    final span = await db.getUnbilledDateSpan(workplaceId);
    expect(span, isNotNull);
    expect(span!.start, DateTime(2026, 8, 5));
    expect(span.end, DateTime(2026, 8, 20));
  });
}
