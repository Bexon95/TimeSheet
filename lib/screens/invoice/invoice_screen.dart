import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/providers.dart';
import '../../services/formatters.dart';
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
                  subtitle: Text(
                    '${AppFormatters.date(invoice.createdAt)} • ${invoice.title.isNotEmpty ? invoice.title : invoice.recipientName}',
                  ),
                  trailing: Text(AppFormatters.money(invoice.amount)),
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
}
