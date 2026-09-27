import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:file_picker/file_picker.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../database/database_helper.dart';
import '../database/models.dart';
import 'backup_dedupe.dart';
import 'quick_entry_service.dart';

const backupFormatVersion = 1;

class BackupImportResult {
  const BackupImportResult({
    required this.workplacesAdded,
    required this.projectsAdded,
    required this.entriesAdded,
    required this.entriesSkipped,
    required this.invoicesAdded,
    required this.invoicesSkipped,
    required this.pdfsCopied,
    required this.pdfsSkipped,
  });

  final int workplacesAdded;
  final int projectsAdded;
  final int entriesAdded;
  final int entriesSkipped;
  final int invoicesAdded;
  final int invoicesSkipped;
  final int pdfsCopied;
  final int pdfsSkipped;
}

class BackupService {
  BackupService(this._db);

  final DatabaseHelper _db;

  Future<File> exportToZipFile() async {
    final packageInfo = await PackageInfo.fromPlatform();
    final workplaces = await _db.getWorkplaces();
    final projects = await _db.getAllProjects();
    final entries = await _db.getEntries();
    final invoiceSettings = await _db.getInvoiceSettings();
    final savedInvoices = await _db.getAllSavedInvoices();
    final preferences = await _exportPreferences();

    final manifest = {
      'formatVersion': backupFormatVersion,
      'appVersion': packageInfo.version,
      'buildNumber': packageInfo.buildNumber,
      'exportedAt': DateTime.now().toIso8601String(),
    };

    final databaseJson = {
      'workplaces': workplaces.map((w) => w.toMap()).toList(),
      'projects': projects.map((p) => p.toMap()).toList(),
      'time_entries': entries.map((e) => e.toMap()).toList(),
      'invoice_settings': invoiceSettings.toMap(),
      'saved_invoices': savedInvoices.map((i) => i.toMap()).toList(),
    };

    final archive = Archive();
    archive.addFile(
      ArchiveFile(
        'manifest.json',
        utf8.encode(jsonEncode(manifest)).length,
        utf8.encode(jsonEncode(manifest)),
      ),
    );
    archive.addFile(
      ArchiveFile(
        'database.json',
        utf8.encode(jsonEncode(databaseJson)).length,
        utf8.encode(jsonEncode(databaseJson)),
      ),
    );
    archive.addFile(
      ArchiveFile(
        'preferences.json',
        utf8.encode(jsonEncode(preferences)).length,
        utf8.encode(jsonEncode(preferences)),
      ),
    );

    for (final invoice in savedInvoices) {
      final file = File(invoice.pdfFilePath);
      if (!await file.exists()) continue;
      final bytes = await file.readAsBytes();
      final name = p.join('invoices', pdfBasename(invoice.pdfFilePath));
      archive.addFile(ArchiveFile(name, bytes.length, bytes));
    }

    final encoded = ZipEncoder().encode(archive)!;

    final dir = await getTemporaryDirectory();
    final stamp = DateTime.now().toIso8601String().split('T').first;
    final out = File(p.join(dir.path, 'TimeSheet-Backup-$stamp.timesheet.zip'));
    await out.writeAsBytes(encoded);
    return out;
  }

  Future<void> shareBackup(File file) async {
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path)],
        subject: 'TimeSheet Backup',
      ),
    );
  }

  /// Opens the system save dialog (Downloads, SD card, etc.).
  /// Returns a short user-facing path/URI string, or null if cancelled.
  Future<String?> saveBackupToUserSelectedLocation(File file) async {
    final bytes = await file.readAsBytes();
    final uri = await FilePicker.saveFile(
      dialogTitle: 'TimeSheet-Backup speichern',
      fileName: p.basename(file.path),
      bytes: Uint8List.fromList(bytes),
      mimeType: 'application/zip',
      type: FileType.custom,
      allowedExtensions: const ['zip', 'timesheet'],
    );
    if (uri == null) return null;
    if (uri.scheme == 'file') {
      return uri.toFilePath();
    }
    return uri.toString();
  }

  Future<BackupImportResult> importFromUserPick() async {
    final files = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['zip', 'timesheet'],
    );
    if (files.isEmpty) {
      throw BackupImportCancelled();
    }
    final file = files.first;
    final path = file.path;
    if (path == null) {
      throw FormatException('Datei konnte nicht gelesen werden.');
    }
    final bytes = await file.readAsBytes();
    return importFromZipBytes(bytes);
  }

  Future<BackupImportResult> importFromZipBytes(List<int> bytes) async {
    final archive = ZipDecoder().decodeBytes(bytes);
    final dbFile = archive.files.firstWhere(
      (f) => f.name == 'database.json',
      orElse: () => throw FormatException('database.json fehlt im Backup.'),
    );
    final databaseJson =
        jsonDecode(utf8.decode(dbFile.content as List<int>)) as Map<String, dynamic>;

    final workplaces = (databaseJson['workplaces'] as List)
        .map((m) => Workplace.fromMap(Map<String, Object?>.from(m as Map)))
        .toList();
    final projects = (databaseJson['projects'] as List)
        .map((m) => Project.fromMap(Map<String, Object?>.from(m as Map)))
        .toList();
    final entries = (databaseJson['time_entries'] as List)
        .map((m) => TimeEntry.fromMap(Map<String, Object?>.from(m as Map)))
        .toList();
    final invoiceSettings = InvoiceSettings.fromMap(
      Map<String, Object?>.from(
        databaseJson['invoice_settings'] as Map<String, dynamic>,
      ),
    );
    final savedInvoices = (databaseJson['saved_invoices'] as List)
        .map((m) => SavedInvoice.fromMap(Map<String, Object?>.from(m as Map)))
        .toList();

    final prefsFile = archive.files
        .where((f) => f.name == 'preferences.json')
        .firstOrNull;
    Map<String, dynamic>? preferences;
    if (prefsFile != null) {
      preferences = jsonDecode(
        utf8.decode(prefsFile.content as List<int>),
      ) as Map<String, dynamic>;
    }

    return _mergeImport(
      archive: archive,
      workplaces: workplaces,
      projects: projects,
      entries: entries,
      invoiceSettings: invoiceSettings,
      savedInvoices: savedInvoices,
      preferences: preferences,
    );
  }

  Future<BackupImportResult> _mergeImport({
    required Archive archive,
    required List<Workplace> workplaces,
    required List<Project> projects,
    required List<TimeEntry> entries,
    required InvoiceSettings invoiceSettings,
    required List<SavedInvoice> savedInvoices,
    Map<String, dynamic>? preferences,
  }) async {
    var workplacesAdded = 0;
    var projectsAdded = 0;
    var entriesAdded = 0;
    var entriesSkipped = 0;
    var invoicesAdded = 0;
    var invoicesSkipped = 0;
    var pdfsCopied = 0;
    var pdfsSkipped = 0;

    final existingWorkplaces = await _db.getWorkplaces();
    final workplaceIdMap = <int, int>{};
    for (final w in existingWorkplaces) {
      for (final imported in workplaces.where((i) => i.name == w.name)) {
        workplaceIdMap[imported.id] = w.id;
      }
    }
    for (final imported in workplaces) {
      if (workplaceIdMap.containsKey(imported.id)) continue;
      final newId = await _db.insertWorkplace(
        imported.copyWith(id: 0),
      );
      workplaceIdMap[imported.id] = newId;
      workplacesAdded++;
    }

    final existingProjects = await _db.getAllProjects();
    final projectIdMap = <int, int>{};
    for (final p in existingProjects) {
      for (final imported in projects.where(
        (i) =>
            workplaceIdMap[i.workplaceId] == p.workplaceId && i.name == p.name,
      )) {
        projectIdMap[imported.id] = p.id;
      }
    }
    for (final imported in projects) {
      if (projectIdMap.containsKey(imported.id)) continue;
      final mappedWorkplaceId = workplaceIdMap[imported.workplaceId];
      if (mappedWorkplaceId == null) continue;
      final newId = await _db.insertProject(
        imported.copyWith(id: 0, workplaceId: mappedWorkplaceId),
      );
      projectIdMap[imported.id] = newId;
      projectsAdded++;
    }

    final existingEntries = await _db.getEntries();
    final existingEntryKeys = existingEntries
        .map(timeEntryDedupeKeyFromEntry)
        .toSet();

    for (final entry in entries) {
      final workplaceId = workplaceIdMap[entry.workplaceId];
      if (workplaceId == null) continue;
      final projectId = entry.projectId != null
          ? projectIdMap[entry.projectId!]
          : null;
      final mapped = entry.copyWith(
        id: 0,
        workplaceId: workplaceId,
        projectId: projectId,
        clearProject: entry.projectId != null && projectId == null,
      );
      final key = timeEntryDedupeKeyFromEntry(mapped);
      if (existingEntryKeys.contains(key)) {
        entriesSkipped++;
        continue;
      }
      await _db.insertEntry(mapped);
      existingEntryKeys.add(key);
      entriesAdded++;
    }

    await _db.saveInvoiceSettings(invoiceSettings);

    final existingInvoices = await _db.getAllSavedInvoices();
    final existingInvoiceKeys = existingInvoices
        .map(savedInvoiceDedupeKeyFromInvoice)
        .toSet();
    final existingPdfNames = existingInvoices
        .map((i) => pdfBasename(i.pdfFilePath))
        .toSet();

    final docsDir = await getApplicationDocumentsDirectory();
    final invoicesDir = Directory(p.join(docsDir.path, 'invoices'));
    if (!await invoicesDir.exists()) {
      await invoicesDir.create(recursive: true);
    }

    for (final invoice in savedInvoices) {
      final workplaceId = workplaceIdMap[invoice.workplaceId];
      if (workplaceId == null) continue;
      final mapped = invoice.copyWith(id: 0, workplaceId: workplaceId);
      final key = savedInvoiceDedupeKeyFromInvoice(mapped);
      if (existingInvoiceKeys.contains(key)) {
        invoicesSkipped++;
        continue;
      }

      final baseName = pdfBasename(invoice.pdfFilePath);
      final zipEntry = archive.files
          .where((f) => f.name == p.join('invoices', baseName))
          .firstOrNull;
      var pdfPath = p.join(invoicesDir.path, baseName);
      if (zipEntry != null) {
        if (existingPdfNames.contains(baseName) && await File(pdfPath).exists()) {
          pdfsSkipped++;
        } else {
          await File(pdfPath).writeAsBytes(zipEntry.content as List<int>);
          existingPdfNames.add(baseName);
          pdfsCopied++;
        }
      }
      pdfPath = p.join(invoicesDir.path, baseName);

      await _db.insertSavedInvoice(
        mapped.copyWith(pdfFilePath: pdfPath),
      );
      existingInvoiceKeys.add(key);
      invoicesAdded++;
    }

    if (preferences != null) {
      await _importPreferences(preferences, workplaceIdMap, projectIdMap);
    }

    return BackupImportResult(
      workplacesAdded: workplacesAdded,
      projectsAdded: projectsAdded,
      entriesAdded: entriesAdded,
      entriesSkipped: entriesSkipped,
      invoicesAdded: invoicesAdded,
      invoicesSkipped: invoicesSkipped,
      pdfsCopied: pdfsCopied,
      pdfsSkipped: pdfsSkipped,
    );
  }

  Future<Map<String, dynamic>> _exportPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().toList();
    final map = <String, dynamic>{};
    for (final key in keys) {
      final value = prefs.get(key);
      map[key] = value;
    }
    final quickPresets = await QuickEntryService().getPresets();
    map['quick_entry_presets_export'] =
        quickPresets.map((p) => p.toJson()).toList();
    return map;
  }

  Future<void> _importPreferences(
    Map<String, dynamic> preferences,
    Map<int, int> workplaceIdMap,
    Map<int, int> projectIdMap,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    for (final entry in preferences.entries) {
      if (entry.key == 'quick_entry_presets_export') {
        continue;
      }
      if (entry.key.startsWith('last_project_')) {
        continue;
      }
      final value = entry.value;
      if (value is String) {
        await prefs.setString(entry.key, value);
      } else if (value is int) {
        await prefs.setInt(entry.key, value);
      } else if (value is bool) {
        await prefs.setBool(entry.key, value);
      } else if (value is double) {
        await prefs.setDouble(entry.key, value);
      }
    }

    for (final entry in preferences.entries) {
      if (!entry.key.startsWith('last_project_')) continue;
      final oldId = int.tryParse(entry.key.substring('last_project_'.length));
      if (oldId == null) continue;
      final newId = workplaceIdMap[oldId];
      if (newId == null) continue;
      final projectId = entry.value as int?;
      if (projectId == null) continue;
      final mappedProject = projectIdMap[projectId];
      if (mappedProject != null) {
        await prefs.setInt('last_project_$newId', mappedProject);
      }
    }

    final presetsRaw = preferences['quick_entry_presets_export'];
    if (presetsRaw is List) {
      final service = QuickEntryService();
      final presets = presetsRaw
          .map((e) => QuickEntryPreset.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
      await service.savePresets(presets);
    }
  }
}

class BackupImportCancelled implements Exception {}

extension _FirstOrNull<E> on Iterable<E> {
  E? get firstOrNull {
    final iterator = this.iterator;
    if (!iterator.moveNext()) return null;
    return iterator.current;
  }
}
