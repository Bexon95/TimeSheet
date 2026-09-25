import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import '../../database/models.dart';
import '../../providers/providers.dart';
import '../../services/formatters.dart';
import '../../services/pdf_invoice_service.dart';

class InvoiceBuilderScreen extends ConsumerStatefulWidget {
  const InvoiceBuilderScreen({super.key, required this.workplace});

  final Workplace workplace;

  @override
  ConsumerState<InvoiceBuilderScreen> createState() =>
      _InvoiceBuilderScreenState();
}

class _InvoiceBuilderScreenState extends ConsumerState<InvoiceBuilderScreen> {
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();
  final _invoiceNumberController = TextEditingController();
  final _recipientNameController = TextEditingController();
  final _recipientAddressController = TextEditingController();
  final _teilbetragController = TextEditingController(text: 'Betrag');
  final List<TextEditingController> _bulletControllers = [];
  bool _initialized = false;

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    _invoiceNumberController.dispose();
    _recipientNameController.dispose();
    _recipientAddressController.dispose();
    _teilbetragController.dispose();
    for (final c in _bulletControllers) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _initialize() async {
    if (_initialized) return;
    final db = ref.read(databaseProvider);
    final range = ref.read(appStateProvider).dateRange;
    final entries = await db.getEntries(
      workplaceId: widget.workplace.id,
      start: range.start,
      end: range.end,
    );
    final invoiceNumber = await db.suggestInvoiceNumber();
    final notes = entries
        .map((e) => e.notes.trim())
        .where((n) => n.isNotEmpty)
        .toList();
    final amount = entries.fold<double>(0, (sum, e) => sum + e.earned);

    _invoiceNumberController.text = invoiceNumber;
    _recipientNameController.text = widget.workplace.recipientName;
    _recipientAddressController.text = widget.workplace.recipientAddress;
    _amountController.text = amount.toStringAsFixed(2);
    _bulletControllers.clear();
    if (notes.isEmpty) {
      _bulletControllers.add(TextEditingController());
    } else {
      for (final note in notes) {
        _bulletControllers.add(TextEditingController(text: note));
      }
    }
    _initialized = true;
    setState(() {});
  }

  void _addBullet() {
    setState(() => _bulletControllers.add(TextEditingController()));
  }

  void _removeBullet(int index) {
    setState(() {
      _bulletControllers[index].dispose();
      _bulletControllers.removeAt(index);
    });
  }

  Future<void> _preview() async {
    final settings = await ref.read(databaseProvider).getInvoiceSettings();
    final invoice = _buildDraft(settings);
    final pdf = await PdfInvoiceService().buildPdf(
      invoice: invoice,
      settings: settings,
    );
    await Printing.layoutPdf(onLayout: (_) async => pdf.save());
  }

  Future<void> _saveAndExport() async {
    final db = ref.read(databaseProvider);
    final settings = await db.getInvoiceSettings();
    final draft = _buildDraft(settings);
    final pdfService = PdfInvoiceService();

    final file = await pdfService.generateAndSave(
      invoice: draft,
      settings: settings,
    );

    final saved = SavedInvoice(
      id: 0,
      workplaceId: draft.workplaceId,
      createdAt: draft.createdAt,
      invoiceNumber: draft.invoiceNumber,
      title: draft.title,
      amount: draft.amount,
      recipientName: draft.recipientName,
      recipientAddress: draft.recipientAddress,
      dateRangeStart: draft.dateRangeStart,
      dateRangeEnd: draft.dateRangeEnd,
      bulletLines: draft.bulletLines,
      pdfFilePath: file.path,
      senderSnapshot: _senderSnapshot(settings),
      footerSnapshot: _footerSnapshot(settings),
      teilbetragLabel: draft.teilbetragLabel,
    );
    await db.insertSavedInvoice(saved);
    await db.incrementInvoiceCounter(saved.invoiceNumber);

    bumpRefresh(ref);

    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path)],
        subject: 'Honorarnote ${saved.invoiceNumber}',
      ),
    );

    if (mounted) Navigator.pop(context, true);
  }

  String _senderSnapshot(InvoiceSettings settings) {
    return PdfInvoiceService.senderLinesFrom(
      snapshot: '',
      settings: settings,
    ).join('\n');
  }

  String _footerSnapshot(InvoiceSettings settings) {
    return [
      settings.vatText,
      settings.paymentText,
      if (settings.iban.isNotEmpty) settings.iban,
      if (settings.bic.isNotEmpty) 'BIC ${settings.bic}',
    ].where((line) => line.isNotEmpty).join('\n');
  }

  SavedInvoice _buildDraft(InvoiceSettings settings) {
    final range = ref.read(appStateProvider).dateRange;

    return SavedInvoice(
      id: 0,
      workplaceId: widget.workplace.id,
      createdAt: DateTime.now(),
      invoiceNumber: _invoiceNumberController.text.trim(),
      title: _titleController.text.trim(),
      amount: double.tryParse(_amountController.text.replaceAll(',', '.')) ?? 0,
      recipientName: _recipientNameController.text.trim(),
      recipientAddress: _recipientAddressController.text.trim(),
      dateRangeStart: range.start,
      dateRangeEnd: range.end,
      bulletLines: _bulletControllers
          .map((c) => c.text.trim())
          .where((line) => line.isNotEmpty)
          .toList(),
      pdfFilePath: '',
      senderSnapshot: _senderSnapshot(settings),
      footerSnapshot: _footerSnapshot(settings),
      teilbetragLabel: _teilbetragController.text.trim(),
    );
  }

  @override
  Widget build(BuildContext context) {
    _initialize();

    final range = ref.watch(appStateProvider).dateRange;

    return Scaffold(
      appBar: AppBar(title: const Text('Neue Honorarnote')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Zeitraum: ${AppFormatters.dateRange(range.start, range.end)}'),
          const SizedBox(height: 12),
          TextField(
            controller: _invoiceNumberController,
            decoration: const InputDecoration(labelText: 'Rechnungsnummer (x/YY)'),
          ),
          TextField(
            controller: _recipientNameController,
            decoration: const InputDecoration(labelText: 'Empfänger'),
          ),
          TextField(
            controller: _recipientAddressController,
            decoration: const InputDecoration(labelText: 'Empfängeradresse'),
            maxLines: 3,
          ),
          TextField(
            controller: _titleController,
            decoration: const InputDecoration(labelText: 'Titel'),
          ),
          const SizedBox(height: 8),
          Text('Leistungsbeschreibung', style: Theme.of(context).textTheme.titleSmall),
          ...List.generate(_bulletControllers.length, (index) {
            return Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _bulletControllers[index],
                    decoration: InputDecoration(labelText: 'Punkt ${index + 1}'),
                  ),
                ),
                IconButton(
                  onPressed: () => _removeBullet(index),
                  icon: const Icon(Icons.remove_circle_outline),
                ),
              ],
            );
          }),
          TextButton.icon(
            onPressed: _addBullet,
            icon: const Icon(Icons.add),
            label: const Text('Punkt hinzufügen'),
          ),
          TextField(
            controller: _teilbetragController,
            decoration: const InputDecoration(labelText: 'Betrag-Bezeichnung'),
          ),
          TextField(
            controller: _amountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Betrag (EUR)'),
          ),
          const SizedBox(height: 16),
          OutlinedButton(
            onPressed: _preview,
            child: const Text('Vorschau'),
          ),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: _saveAndExport,
            child: const Text('Speichern & PDF exportieren'),
          ),
        ],
      ),
    );
  }
}
