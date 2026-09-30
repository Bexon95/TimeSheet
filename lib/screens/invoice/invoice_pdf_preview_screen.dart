import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';

typedef InvoicePdfLayout = Future<Uint8List> Function(PdfPageFormat format);

class InvoicePdfPreviewScreen extends StatelessWidget {
  const InvoicePdfPreviewScreen({
    super.key,
    required this.onLayout,
    required this.suggestedFileName,
  });

  final InvoicePdfLayout onLayout;
  final String suggestedFileName;

  static Future<void> openSavedFile(
    BuildContext context, {
    required String pdfFilePath,
    required String invoiceNumber,
  }) async {
    final file = File(pdfFilePath);
    if (!await file.exists()) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('PDF-Datei nicht gefunden.')),
        );
      }
      return;
    }
    final fileName =
        'Honorarnote_${invoiceNumber.replaceAll('/', '-')}${p.extension(file.path).isEmpty ? '.pdf' : p.extension(file.path)}';
    if (!context.mounted) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (context) => InvoicePdfPreviewScreen(
          suggestedFileName: fileName,
          onLayout: (_) => file.readAsBytes(),
        ),
      ),
    );
  }

  static Future<void> savePdfBytes({
    required InvoicePdfLayout onLayout,
    required String suggestedFileName,
  }) async {
    final bytes = await onLayout(PdfPageFormat.a4);
    await FilePicker.saveFile(
      dialogTitle: 'Als PDF speichern',
      fileName: suggestedFileName,
      bytes: bytes,
      mimeType: 'application/pdf',
      type: FileType.custom,
      allowedExtensions: const ['pdf'],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Vorschau'),
        actions: [
          IconButton(
            tooltip: 'Als PDF speichern',
            icon: const Icon(Icons.download),
            onPressed: () => savePdfBytes(
              onLayout: onLayout,
              suggestedFileName: suggestedFileName,
            ),
          ),
        ],
      ),
      body: PdfPreview(
        build: onLayout,
        pdfFileName: suggestedFileName,
        allowPrinting: false,
        allowSharing: true,
        canChangePageFormat: false,
        canChangeOrientation: false,
        canDebug: false,
        actions: [
          PdfPreviewAction(
            icon: const Icon(Icons.download),
            onPressed: (context, build, pageFormat) async {
              final bytes = await build(pageFormat);
              await FilePicker.saveFile(
                dialogTitle: 'Als PDF speichern',
                fileName: suggestedFileName,
                bytes: bytes,
                mimeType: 'application/pdf',
                type: FileType.custom,
                allowedExtensions: const ['pdf'],
              );
            },
          ),
        ],
      ),
    );
  }
}
