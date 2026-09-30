import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../database/models.dart';
import 'formatters.dart';

class PdfInvoiceService {
  static const _defaultPaymentText = 'Bitte um Überweisung auf mein Konto';

  static String paymentTextFor(InvoiceSettings settings) {
    final text = settings.paymentText.trim();
    if (text.isNotEmpty) return text;
    if (settings.iban.isNotEmpty || settings.bic.isNotEmpty) {
      return _defaultPaymentText;
    }
    return '';
  }

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
          final vatText = invoice.vatTextSnapshot.isNotEmpty
              ? invoice.vatTextSnapshot
              : settings.vatText;
          final paymentLine = invoice.paymentTextSnapshot.isNotEmpty
              ? invoice.paymentTextSnapshot.trim()
              : paymentTextFor(settings);
          final footnoteText = invoice.footnoteTextSnapshot.isNotEmpty
              ? invoice.footnoteTextSnapshot
              : settings.footnoteText;
          final body = pw.Column(
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
                pw.Text(
                  invoice.title,
                  style: pw.TextStyle(
                    decoration: pw.TextDecoration.underline,
                  ),
                ),
                pw.SizedBox(height: 8),
              ],
              ...invoice.bulletLines.map(
                (line) => pw.Padding(
                  padding: const pw.EdgeInsets.only(left: 24, bottom: 4),
                  child: pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('- '),
                      pw.Expanded(child: pw.Text(line)),
                    ],
                  ),
                ),
              ),
              pw.SizedBox(height: 24),
              pw.Container(
                width: double.infinity,
                decoration: const pw.BoxDecoration(
                  border: pw.Border(
                    bottom: pw.BorderSide(width: 0.75),
                  ),
                ),
                padding: const pw.EdgeInsets.only(bottom: 2),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      invoice.teilbetragLabel,
                      style: pw.TextStyle(
                        decoration: pw.TextDecoration.underline,
                      ),
                    ),
                    pw.Text(
                      AppFormatters.money(invoice.amount),
                      style: pw.TextStyle(
                        decoration: pw.TextDecoration.underline,
                      ),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 24),
              if (vatText.isNotEmpty) pw.Text(vatText),
              if (paymentLine.isNotEmpty ||
                  settings.iban.isNotEmpty ||
                  settings.bic.isNotEmpty) ...[
                pw.SizedBox(height: 12),
                if (paymentLine.isNotEmpty) pw.Text(paymentLine),
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

          if (footnoteText.isEmpty) {
            return body;
          }

          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              pw.Expanded(child: body),
              pw.Container(
                width: double.infinity,
                decoration: const pw.BoxDecoration(
                  border: pw.Border(
                    top: pw.BorderSide(width: 0.5),
                  ),
                ),
                padding: const pw.EdgeInsets.only(top: 8),
                child: pw.Text(
                  footnoteText,
                  style: const pw.TextStyle(fontSize: 8),
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
