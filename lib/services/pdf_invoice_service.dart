import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../database/models.dart';
import 'formatters.dart';

class PdfInvoiceService {
  Future<File> generateAndSave({
    required SavedInvoice invoice,
    required InvoiceSettings settings,
  }) async {
    final pdf = await buildPdf(invoice: invoice, settings: settings);
    final dir = await getApplicationDocumentsDirectory();
    final invoicesDir = Directory('${dir.path}/invoices');
    if (!await invoicesDir.exists()) {
      await invoicesDir.create(recursive: true);
    }
    final file = File(
      '${invoicesDir.path}/invoice_${invoice.invoiceNumber.replaceAll('/', '-')}_${invoice.createdAt.millisecondsSinceEpoch}.pdf',
    );
    await file.writeAsBytes(await pdf.save());
    return file;
  }

  Future<pw.Document> buildPdf({
    required SavedInvoice invoice,
    required InvoiceSettings settings,
  }) async {
    final doc = pw.Document();
    final senderLines = invoice.senderSnapshot.isNotEmpty
        ? invoice.senderSnapshot.split('\n')
        : [
            settings.senderName,
            settings.senderAddress,
            if (settings.senderSsn.isNotEmpty) 'SVNr. ${settings.senderSsn}',
          ].where((line) => line.isNotEmpty).toList();

    final footerLines = invoice.footerSnapshot.isNotEmpty
        ? invoice.footerSnapshot.split('\n')
        : [
            settings.vatText,
            settings.paymentText,
            if (settings.iban.isNotEmpty) settings.iban,
            if (settings.bic.isNotEmpty) 'BIC ${settings.bic}.',
          ].where((line) => line.isNotEmpty).toList();

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(48),
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: senderLines
                          .map((line) => pw.Text(line))
                          .toList(),
                    ),
                  ),
                  pw.Text(AppFormatters.date(invoice.createdAt)),
                ],
              ),
              pw.SizedBox(height: 36),
              pw.Align(
                alignment: pw.Alignment.centerRight,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('An'),
                    pw.SizedBox(height: 8),
                    pw.Text(invoice.recipientName),
                    ...invoice.recipientAddress
                        .split('\n')
                        .where((line) => line.isNotEmpty)
                        .map((line) => pw.Text(line)),
                  ],
                ),
              ),
              pw.SizedBox(height: 36),
              pw.Text(
                'HONORARNOTE  ${invoice.invoiceNumber}',
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 24),
              if (invoice.title.isNotEmpty) ...[
                pw.Text(invoice.title),
                pw.SizedBox(height: 16),
              ],
              ...invoice.bulletLines.map(
                (line) => pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 4),
                  child: pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('• '),
                      pw.Expanded(child: pw.Text(line)),
                    ],
                  ),
                ),
              ),
              pw.SizedBox(height: 24),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(invoice.teilbetragLabel),
                  pw.Text(AppFormatters.money(invoice.amount)),
                ],
              ),
              pw.SizedBox(height: 24),
              ...footerLines.map(
                (line) => pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 4),
                  child: pw.Text(line),
                ),
              ),
            ],
          );
        },
      ),
    );
    return doc;
  }
}
