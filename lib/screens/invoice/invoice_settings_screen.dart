import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../database/models.dart';
import '../../providers/providers.dart';

class InvoiceSettingsScreen extends ConsumerStatefulWidget {
  const InvoiceSettingsScreen({super.key});

  @override
  ConsumerState<InvoiceSettingsScreen> createState() =>
      _InvoiceSettingsScreenState();
}

class _InvoiceSettingsScreenState extends ConsumerState<InvoiceSettingsScreen> {
  final _senderName = TextEditingController();
  final _senderAddress = TextEditingController();
  final _senderSsn = TextEditingController();
  final _vatText = TextEditingController();
  final _paymentText = TextEditingController();
  final _iban = TextEditingController();
  final _bic = TextEditingController();
  bool _loaded = false;

  @override
  void dispose() {
    _senderName.dispose();
    _senderAddress.dispose();
    _senderSsn.dispose();
    _vatText.dispose();
    _paymentText.dispose();
    _iban.dispose();
    _bic.dispose();
    super.dispose();
  }

  void _load(InvoiceSettings settings) {
    if (_loaded) return;
    _senderName.text = settings.senderName;
    _senderAddress.text = settings.senderAddress;
    _senderSsn.text = settings.senderSsn;
    _vatText.text = settings.vatText;
    _paymentText.text = settings.paymentText;
    _iban.text = settings.iban;
    _bic.text = settings.bic;
    _loaded = true;
  }

  Future<void> _save() async {
    final current = await ref.read(databaseProvider).getInvoiceSettings();
    await ref.read(databaseProvider).saveInvoiceSettings(
          current.copyWith(
            senderName: _senderName.text.trim(),
            senderAddress: _senderAddress.text.trim(),
            senderSsn: _senderSsn.text.trim(),
            vatText: _vatText.text.trim(),
            paymentText: _paymentText.text.trim(),
            iban: _iban.text.trim(),
            bic: _bic.text.trim(),
          ),
        );
    bumpRefresh(ref);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Rechnungseinstellungen gespeichert')),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(invoiceSettingsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Rechnungseinstellungen')),
      body: settingsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Fehler: $e')),
        data: (settings) {
          _load(settings);
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              TextField(
                controller: _senderName,
                decoration: const InputDecoration(labelText: 'Ihr Name'),
              ),
              TextField(
                controller: _senderAddress,
                decoration: const InputDecoration(labelText: 'Ihre Adresse'),
                maxLines: 3,
              ),
              TextField(
                controller: _senderSsn,
                decoration: const InputDecoration(labelText: 'SVNr.'),
              ),
              TextField(
                controller: _vatText,
                decoration: const InputDecoration(labelText: 'USt-Text'),
                maxLines: 2,
              ),
              TextField(
                controller: _paymentText,
                decoration: const InputDecoration(
                  labelText: 'Zahlungshinweis',
                ),
                maxLines: 2,
              ),
              TextField(
                controller: _iban,
                decoration: const InputDecoration(labelText: 'IBAN'),
              ),
              TextField(
                controller: _bic,
                decoration: const InputDecoration(labelText: 'BIC'),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _save,
                child: const Text('Speichern'),
              ),
            ],
          );
        },
      ),
    );
  }
}
