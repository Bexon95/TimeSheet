import '../database/models.dart';

/// Key for skipping duplicate time entries on import.
String timeEntryDedupeKey({
  required int workplaceId,
  required DateTime date,
  required DateTime startTime,
  required DateTime endTime,
}) {
  final dateKey = date.toIso8601String().split('T').first;
  return '$workplaceId|$dateKey|${startTime.toIso8601String()}|${endTime.toIso8601String()}';
}

String timeEntryDedupeKeyFromEntry(TimeEntry entry) => timeEntryDedupeKey(
      workplaceId: entry.workplaceId,
      date: entry.date,
      startTime: entry.startTime,
      endTime: entry.endTime,
    );

/// Key for skipping duplicate saved invoices on import.
String savedInvoiceDedupeKey({
  required int workplaceId,
  required String invoiceNumber,
}) {
  return '$workplaceId|$invoiceNumber';
}

String savedInvoiceDedupeKeyFromInvoice(SavedInvoice invoice) =>
    savedInvoiceDedupeKey(
      workplaceId: invoice.workplaceId,
      invoiceNumber: invoice.invoiceNumber,
    );

String pdfBasename(String path) {
  final normalized = path.replaceAll('\\', '/');
  final slash = normalized.lastIndexOf('/');
  return slash < 0 ? normalized : normalized.substring(slash + 1);
}
