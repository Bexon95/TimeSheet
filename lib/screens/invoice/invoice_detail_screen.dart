import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../database/models.dart';
import '../../providers/providers.dart';
import '../../services/formatters.dart';

class InvoiceDetailScreen extends ConsumerWidget {
  const InvoiceDetailScreen({super.key, required this.invoice});

  final SavedInvoice invoice;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: Text('Honorarnote ${invoice.invoiceNumber}')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Erstellt: ${AppFormatters.dateTime(invoice.createdAt)}'),
          Text(
            'Zeitraum: ${AppFormatters.dateRange(invoice.dateRangeStart, invoice.dateRangeEnd)}',
          ),
          const SizedBox(height: 12),
          Text('Empfänger: ${invoice.recipientName}'),
          if (invoice.recipientAddress.isNotEmpty)
            Text(invoice.recipientAddress),
          const SizedBox(height: 12),
          if (invoice.title.isNotEmpty) ...[
            Text(invoice.title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
          ],
          ...invoice.bulletLines.map((line) => Text('• $line')),
          const SizedBox(height: 12),
          Text(
            AppFormatters.money(invoice.amount),
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () async {
              final file = File(invoice.pdfFilePath);
              if (!await file.exists()) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('PDF-Datei nicht gefunden.')),
                );
                return;
              }
              await SharePlus.instance.share(
                ShareParams(
                  files: [XFile(file.path)],
                  subject: 'Honorarnote ${invoice.invoiceNumber}',
                ),
              );
            },
            icon: const Icon(Icons.share),
            label: const Text('Erneut teilen'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Rechnung löschen?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Abbrechen'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Löschen'),
                    ),
                  ],
                ),
              );
              if (confirmed != true) return;

              final file = File(invoice.pdfFilePath);
              if (await file.exists()) {
                await file.delete();
              }
              await ref.read(databaseProvider).deleteSavedInvoice(invoice.id);
              bumpRefresh(ref);
              if (context.mounted) Navigator.pop(context);
            },
            icon: const Icon(Icons.delete_outline),
            label: const Text('Löschen'),
          ),
        ],
      ),
    );
  }
}
