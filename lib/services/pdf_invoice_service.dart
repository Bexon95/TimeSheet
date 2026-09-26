import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../database/models.dart';
import 'formatters.dart';

class PdfInvoiceService {
  static List<String> senderLinesFrom({
    required String snapshot,
    required InvoiceSettings settings,
  }) {
    if (snapshot.isNotEmpty) {
      return snapshot.split('\n').where((line) => line.isNotEmpty).toList();
    }
    return [
      if (settings.senderName.isNotEmpty) settings.senderName,
      ...settings.senderAddress
          .split('\n')
          .map((line) => line.trim())
          .where((line) => line.isNotEmpty),
      if (settings.senderSsn.isNotEmpty) 'SVNr. ${settings.senderSsn}',
    ];
  }

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
    final senderLines = senderLinesFrom(
      snapshot: invoice.senderSnapshot,
      settings: settings,
    );

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(48),
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: senderLines.map((line) => pw.Text(line)).toList(),
              ),
              pw.SizedBox(height: 24),
              pw.Align(
                alignment: pw.Alignment.centerRight,
                child: pw.Text(AppFormatters.date(invoice.createdAt)),
              ),
              pw.SizedBox(height: 24),
              pw.Column(
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
              pw.SizedBox(height: 36),
              pw.Center(
                child: pw.Text(
                  'HONORARNOTE  ${invoice.invoiceNumber}',
                  style: const pw.TextStyle(
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
              pw.SizedBox(height: 24),
              if (invoice.title.isNotEmpty) ...[
                pw.Text(invoice.title),
                pw.SizedBox(height: 8),
              ],
              ...invoice.bulletLines.map(
                (line) => pw.Padding(
                  padding: const pw.EdgeInsets.only(left: 24, bottom: 4),
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
              if (settings.vatText.isNotEmpty) pw.Text(settings.vatText),
              if (settings.paymentText.isNotEmpty ||
                  settings.iban.isNotEmpty ||
                  settings.bic.isNotEmpty) ...[
                pw.SizedBox(height: 12),
                if (settings.paymentText.isNotEmpty)
                  pw.Text(settings.paymentText),
                if (settings.iban.isNotEmpty)
                  pw.Padding(
                    padding: const pw.EdgeInsets.only(left: 24, top: 4),
                    child: pw.Text(settings.iban),
                  ),
                if (settings.bic.isNotEmpty)
                  pw.Padding(
                    padding: const pw.EdgeInsets.only(left: 24, top: 4),
                    child: pw.Text('BIC ${settings.bic}'),
                  ),
              ],
            ],
          );
        },
      ),
    );
    return doc;
  }
}
