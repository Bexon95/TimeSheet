import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/providers.dart';
import '../../services/backup_service.dart';
import '../invoice/invoice_settings_screen.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _busy = false;

  Future<File> _createBackupFile() async {
    return BackupService(ref.read(databaseProvider)).exportToZipFile();
  }

  Future<void> _exportShare() async {
    setState(() => _busy = true);
    try {
      final file = await _createBackupFile();
      await BackupService(ref.read(databaseProvider)).shareBackup(file);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export fehlgeschlagen: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _exportSave() async {
    setState(() => _busy = true);
    try {
      final file = await _createBackupFile();
      final service = BackupService(ref.read(databaseProvider));
      final saved = await service.saveBackupToUserSelectedLocation(file);
      if (!mounted) return;
      if (saved == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Speichern abgebrochen.')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Backup gespeichert: $saved')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Speichern fehlgeschlagen: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _import() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Backup importieren?'),
        content: const Text(
          'Neue Daten werden hinzugefügt. Einträge mit gleichem Datum und '
          'Start-/Endzeit sowie doppelte Rechnungen werden übersprungen.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Importieren'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _busy = true);
    try {
      final result =
          await BackupService(ref.read(databaseProvider)).importFromUserPick();
      await ref.read(appStateProvider.notifier).reload();
      bumpRefresh(ref);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Import: ${result.entriesAdded} Einträge, '
              '${result.invoicesAdded} Rechnungen hinzugefügt '
              '(${result.entriesSkipped} Einträge, '
              '${result.invoicesSkipped} Rechnungen übersprungen).',
            ),
          ),
        );
      }
    } on BackupImportCancelled {
      // user cancelled picker
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Import fehlgeschlagen: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);
    final entryPrefs = ref.watch(entryPreferencesProvider);
    final packageInfo = ref.watch(packageInfoProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Einstellungen')),
      body: _busy
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                ListTile(
                  leading: const Icon(Icons.person_outline),
                  title: const Text('Meine Rechnungsdaten'),
                  subtitle: const Text('Name, Adresse, IBAN, BIC'),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const InvoiceSettingsScreen(),
                      ),
                    );
                  },
                ),
                const Divider(),
                ListTile(
                  leading: Icon(
                    switch (themeMode) {
                      ThemeMode.dark => Icons.dark_mode,
                      ThemeMode.light => Icons.light_mode,
                      ThemeMode.system => Icons.brightness_auto,
                    },
                  ),
                  title: const Text('Erscheinungsbild'),
                  subtitle: Text(
                    switch (themeMode) {
                      ThemeMode.dark => 'Dunkel',
                      ThemeMode.light => 'Hell',
                      ThemeMode.system => 'System',
                    },
                  ),
                  onTap: () async {
                    final next = switch (themeMode) {
                      ThemeMode.system => AppThemeMode.light,
                      ThemeMode.light => AppThemeMode.dark,
                      ThemeMode.dark => AppThemeMode.system,
                    };
                    await ref.read(themeModeProvider.notifier).setMode(next);
                  },
                ),
                const Divider(),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Text(
                    'Zeiteinträge',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                SwitchListTile(
                  secondary: const Icon(Icons.schedule),
                  title: const Text('Endzeit nach Start automatisch öffnen'),
                  value: entryPrefs.autoOpenEndTime,
                  onChanged: (value) => ref
                      .read(entryPreferencesProvider.notifier)
                      .setAutoOpenEndTime(value),
                ),
                ListTile(
                  leading: const Icon(Icons.timelapse),
                  title: const Text('Standard-Dauer'),
                  subtitle: Text('${entryPrefs.defaultDurationMinutes} Minuten'),
                  trailing: SizedBox(
                    width: 120,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.remove),
                          onPressed: entryPrefs.defaultDurationMinutes <= 1
                              ? null
                              : () => ref
                                  .read(entryPreferencesProvider.notifier)
                                  .setDefaultDurationMinutes(
                                    entryPrefs.defaultDurationMinutes - 15,
                                  ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.add),
                          onPressed: () => ref
                              .read(entryPreferencesProvider.notifier)
                              .setDefaultDurationMinutes(
                                entryPrefs.defaultDurationMinutes + 15,
                              ),
                        ),
                      ],
                    ),
                  ),
                ),
                const Divider(),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Text(
                    'Daten',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.save_alt),
                  title: const Text('Backup speichern'),
                  subtitle: const Text(
                    'In Downloads oder einen Ordner auf dem Gerät',
                  ),
                  onTap: _exportSave,
                ),
                ListTile(
                  leading: const Icon(Icons.share),
                  title: const Text('Backup teilen'),
                  subtitle: const Text('Per E-Mail, Drive, usw.'),
                  onTap: _exportShare,
                ),
                ListTile(
                  leading: const Icon(Icons.download),
                  title: const Text('Daten importieren'),
                  subtitle: const Text('Backup-Datei (.zip) zusammenführen'),
                  onTap: _import,
                ),
                const Divider(),
                packageInfo.when(
                  data: (info) => Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'Version ${info.version} (${info.buildNumber})',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant,
                          ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  loading: () => const SizedBox.shrink(),
                  error: (_, _) => const SizedBox.shrink(),
                ),
              ],
            ),
    );
  }
}
