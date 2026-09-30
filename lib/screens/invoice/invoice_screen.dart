import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../database/models.dart';
import '../../providers/providers.dart';
import '../../services/formatters.dart';
import '../../widgets/date_range_selector.dart';
import 'invoice_builder_screen.dart';
import 'invoice_detail_screen.dart';
import 'invoice_settings_screen.dart';

class InvoiceScreen extends ConsumerWidget {
  const InvoiceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workplaceId = ref.watch(appStateProvider).selectedWorkplaceId;
    final workplace = ref.watch(appStateProvider).workplaces
        .where((w) => w.id == workplaceId)
        .firstOrNull;

    if (workplace == null) {
      return const Center(child: Text('Bitte einen Arbeitgeber auswählen.'));
    }

    final invoicesAsync = ref.watch(savedInvoicesProvider(workplace.id));

    return invoicesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Fehler: $e')),
      data: (invoices) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const DateRangeSelector(),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            InvoiceBuilderScreen(workplace: workplace),
                      ),
                    ).then((_) => bumpRefresh(ref));
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('Neue Honorarnote'),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                tooltip: 'Einstellungen',
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const InvoiceSettingsScreen(),
                    ),
                  );
                },
                icon: const Icon(Icons.settings),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            'Bisherige Rechnungen',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          if (invoices.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('Noch keine Rechnungen für diesen Arbeitgeber.'),
              ),
            )
          else
            ...invoices.map(
              (invoice) => Card(
                child: ListTile(
                  title: Text('Honorarnote ${invoice.invoiceNumber}'),
                  subtitle: Text(AppFormatters.date(invoice.createdAt)),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(AppFormatters.money(invoice.amount)),
                      PopupMenuButton<String>(
                        onSelected: (value) =>
                            _onInvoiceMenu(context, ref, workplace, invoice, value),
                        itemBuilder: (context) => const [
                          PopupMenuItem(value: 'share', child: Text('Teilen')),
                          PopupMenuItem(value: 'edit', child: Text('Bearbeiten')),
                          PopupMenuItem(value: 'delete', child: Text('Löschen')),
                        ],
                      ),
                    ],
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            InvoiceDetailScreen(invoice: invoice),
                      ),
                    );
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _onInvoiceMenu(
    BuildContext context,
    WidgetRef ref,
    Workplace workplace,
    SavedInvoice invoice,
    String action,
  ) async {
    switch (action) {
      case 'share':
        final file = File(invoice.pdfFilePath);
        if (!await file.exists()) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('PDF-Datei nicht gefunden.')),
            );
          }
          return;
        }
        await SharePlus.instance.share(
          ShareParams(
            files: [XFile(file.path)],
            subject: 'Honorarnote ${invoice.invoiceNumber}',
          ),
        );
      case 'edit':
        if (!context.mounted) return;
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => InvoiceBuilderScreen(
              workplace: workplace,
              existingInvoice: invoice,
            ),
          ),
        );
        bumpRefresh(ref);
      case 'delete':
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
    }
  }
}
