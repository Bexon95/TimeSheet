import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import 'models.dart';

class DatabaseHelper {
  DatabaseHelper._();
  static final DatabaseHelper instance = DatabaseHelper._();

  Database? _db;

  Future<Database> get database async {
    _db ??= await _init();
    return _db!;
  }

  Future<Database> _init() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'timesheet.db');
    return openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE workplaces (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            default_hourly_rate REAL NOT NULL,
            recipient_name TEXT NOT NULL DEFAULT '',
            recipient_address TEXT NOT NULL DEFAULT '',
            sort_order INTEGER NOT NULL DEFAULT 0
          )
        ''');
        await db.execute('''
          CREATE TABLE projects (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            workplace_id INTEGER NOT NULL,
            name TEXT NOT NULL,
            color_value INTEGER,
            FOREIGN KEY (workplace_id) REFERENCES workplaces(id) ON DELETE CASCADE
          )
        ''');
        await db.execute('''
          CREATE TABLE time_entries (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            workplace_id INTEGER NOT NULL,
            project_id INTEGER,
            date TEXT NOT NULL,
            start_time TEXT NOT NULL,
            end_time TEXT NOT NULL,
            hourly_rate REAL NOT NULL,
            notes TEXT NOT NULL DEFAULT '',
            source TEXT NOT NULL DEFAULT 'manual',
            FOREIGN KEY (workplace_id) REFERENCES workplaces(id) ON DELETE CASCADE,
            FOREIGN KEY (project_id) REFERENCES projects(id) ON DELETE SET NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE invoice_settings (
            id INTEGER PRIMARY KEY CHECK (id = 1),
            sender_name TEXT NOT NULL DEFAULT '',
            sender_address TEXT NOT NULL DEFAULT '',
            sender_ssn TEXT NOT NULL DEFAULT '',
            vat_text TEXT NOT NULL DEFAULT '',
            payment_text TEXT NOT NULL DEFAULT '',
            iban TEXT NOT NULL DEFAULT '',
            bic TEXT NOT NULL DEFAULT '',
            last_invoice_number INTEGER NOT NULL DEFAULT 0,
            last_invoice_year INTEGER NOT NULL DEFAULT 0
          )
        ''');
        await db.execute('''
          CREATE TABLE saved_invoices (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            workplace_id INTEGER NOT NULL,
            created_at TEXT NOT NULL,
            invoice_number TEXT NOT NULL,
            title TEXT NOT NULL,
            amount REAL NOT NULL,
            recipient_name TEXT NOT NULL DEFAULT '',
            recipient_address TEXT NOT NULL DEFAULT '',
            date_range_start TEXT NOT NULL,
            date_range_end TEXT NOT NULL,
            bullet_lines TEXT NOT NULL DEFAULT '',
            pdf_file_path TEXT NOT NULL,
            sender_snapshot TEXT NOT NULL DEFAULT '',
            footer_snapshot TEXT NOT NULL DEFAULT '',
            teilbetrag_label TEXT NOT NULL DEFAULT 'Betrag',
            FOREIGN KEY (workplace_id) REFERENCES workplaces(id) ON DELETE CASCADE
          )
        ''');
        await db.insert('invoice_settings', {'id': 1});
      },
    );
  }

  Future<List<Workplace>> getWorkplaces() async {
    final db = await database;
    final rows = await db.query('workplaces', orderBy: 'sort_order ASC');
    return rows.map(Workplace.fromMap).toList();
  }

  Future<Workplace?> getWorkplace(int id) async {
    final db = await database;
    final rows = await db.query('workplaces', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return Workplace.fromMap(rows.first);
  }

  Future<int> insertWorkplace(Workplace workplace) async {
    final db = await database;
    final maxOrder = Sqflite.firstIntValue(await db
            .rawQuery('SELECT MAX(sort_order) as m FROM workplaces')) ??
        -1;
    final map = workplace.toMap();
    map.remove('id');
    map['sort_order'] = maxOrder + 1;
    return db.insert('workplaces', map);
  }

  Future<void> updateWorkplace(Workplace workplace) async {
    final db = await database;
    await db.update(
      'workplaces',
      workplace.toMap(),
      where: 'id = ?',
      whereArgs: [workplace.id],
    );
  }

  Future<void> deleteWorkplace(int id) async {
    final db = await database;
    await db.delete('workplaces', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> reorderWorkplaces(List<int> orderedIds) async {
    final db = await database;
    final batch = db.batch();
    for (var i = 0; i < orderedIds.length; i++) {
      batch.update(
        'workplaces',
        {'sort_order': i},
        where: 'id = ?',
        whereArgs: [orderedIds[i]],
      );
    }
    await batch.commit(noResult: true);
  }

  Future<List<Project>> getAllProjects() async {
    final db = await database;
    final rows = await db.query('projects', orderBy: 'workplace_id ASC, name ASC');
    return rows.map(Project.fromMap).toList();
  }

  Future<List<SavedInvoice>> getAllSavedInvoices() async {
    final db = await database;
    final rows = await db.query('saved_invoices', orderBy: 'created_at DESC');
    return rows.map(SavedInvoice.fromMap).toList();
  }

  Future<List<Project>> getProjectsForWorkplace(int workplaceId) async {
    final db = await database;
    final rows = await db.query(
      'projects',
      where: 'workplace_id = ?',
      whereArgs: [workplaceId],
      orderBy: 'name ASC',
    );
    return rows.map(Project.fromMap).toList();
  }

  Future<int> insertProject(Project project) async {
    final db = await database;
    final map = project.toMap();
    map.remove('id');
    return db.insert('projects', map);
  }

  Future<void> updateProject(Project project) async {
    final db = await database;
    await db.update(
      'projects',
      project.toMap(),
      where: 'id = ?',
      whereArgs: [project.id],
    );
  }

  Future<void> deleteProject(int id) async {
    final db = await database;
    await db.delete('projects', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<TimeEntry>> getEntries({
    int? workplaceId,
    DateTime? start,
    DateTime? end,
  }) async {
    final db = await database;
    final where = <String>[];
    final args = <Object?>[];

    if (workplaceId != null) {
      where.add('workplace_id = ?');
      args.add(workplaceId);
    }
    if (start != null) {
      where.add('date >= ?');
      args.add(_dateKey(start));
    }
    if (end != null) {
      where.add('date <= ?');
      args.add(_dateKey(end));
    }

    final rows = await db.query(
      'time_entries',
      where: where.isEmpty ? null : where.join(' AND '),
      whereArgs: args.isEmpty ? null : args,
      orderBy: 'date ASC, start_time ASC',
    );
    return rows.map(TimeEntry.fromMap).toList();
  }

  Future<List<TimeEntry>> getEntriesForDay(int workplaceId, DateTime day) async {
    final db = await database;
    final rows = await db.query(
      'time_entries',
      where: 'workplace_id = ? AND date = ?',
      whereArgs: [workplaceId, _dateKey(day)],
      orderBy: 'start_time ASC',
    );
    return rows.map(TimeEntry.fromMap).toList();
  }

  Future<Set<DateTime>> getDatesWithEntries(int workplaceId, DateTime month) async {
    final start = DateTime(month.year, month.month, 1);
    final end = DateTime(month.year, month.month + 1, 0);
    final entries = await getEntries(
      workplaceId: workplaceId,
      start: start,
      end: end,
    );
    return entries
        .map((e) => DateTime(e.date.year, e.date.month, e.date.day))
        .toSet();
  }

  Future<int> insertEntry(TimeEntry entry) async {
    final db = await database;
    final map = entry.toMap();
    map.remove('id');
    return db.insert('time_entries', map);
  }

  Future<void> updateEntry(TimeEntry entry) async {
    final db = await database;
    await db.update(
      'time_entries',
      entry.toMap(),
      where: 'id = ?',
      whereArgs: [entry.id],
    );
  }

  Future<void> deleteEntry(int id) async {
    final db = await database;
    await db.delete('time_entries', where: 'id = ?', whereArgs: [id]);
  }

  Future<InvoiceSettings> getInvoiceSettings() async {
    final db = await database;
    final rows = await db.query('invoice_settings', where: 'id = 1');
    if (rows.isEmpty) {
      await db.insert('invoice_settings', {'id': 1});
      return InvoiceSettings();
    }
    return InvoiceSettings.fromMap(rows.first);
  }

  Future<void> saveInvoiceSettings(InvoiceSettings settings) async {
    final db = await database;
    await db.update(
      'invoice_settings',
      settings.toMap(),
      where: 'id = ?',
      whereArgs: [1],
    );
  }

  Future<String> suggestInvoiceNumber() async {
    final settings = await getInvoiceSettings();
    final year = DateTime.now().year % 100;
    var number = settings.lastInvoiceNumber + 1;
    if (settings.lastInvoiceYear != year) {
      number = 1;
    }
    return '${number.toString().padLeft(2, '0')}/$year';
  }

  Future<void> incrementInvoiceCounter(String invoiceNumber) async {
    final settings = await getInvoiceSettings();
    final parts = invoiceNumber.split('/');
    final num = int.tryParse(parts.first) ?? settings.lastInvoiceNumber + 1;
    final year = int.tryParse(parts.length > 1 ? parts[1] : '') ??
        DateTime.now().year % 100;
    await saveInvoiceSettings(settings.copyWith(
      lastInvoiceNumber: num,
      lastInvoiceYear: year,
    ));
  }

  Future<int> insertSavedInvoice(SavedInvoice invoice) async {
    final db = await database;
    final map = invoice.toMap();
    map.remove('id');
    return db.insert('saved_invoices', map);
  }

  Future<List<SavedInvoice>> getSavedInvoices(int workplaceId) async {
    final db = await database;
    final rows = await db.query(
      'saved_invoices',
      where: 'workplace_id = ?',
      whereArgs: [workplaceId],
      orderBy: 'created_at DESC',
    );
    return rows.map(SavedInvoice.fromMap).toList();
  }

  Future<SavedInvoice?> getSavedInvoice(int id) async {
    final db = await database;
    final rows =
        await db.query('saved_invoices', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return SavedInvoice.fromMap(rows.first);
  }

  Future<void> updateSavedInvoice(SavedInvoice invoice) async {
    final db = await database;
    await db.update(
      'saved_invoices',
      invoice.toMap(),
      where: 'id = ?',
      whereArgs: [invoice.id],
    );
  }

  Future<void> deleteSavedInvoice(int id) async {
    final db = await database;
    await db.delete('saved_invoices', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<WorkplaceSummary>> getWorkplaceSummaries({
    required DateTime start,
    required DateTime end,
  }) async {
    final workplaces = await getWorkplaces();
    final entries = await getEntries(start: start, end: end);
    return workplaces.map((workplace) {
      final workplaceEntries =
          entries.where((e) => e.workplaceId == workplace.id);
      final minutes =
          workplaceEntries.fold<int>(0, (sum, e) => sum + e.durationMinutes);
      final earned =
          workplaceEntries.fold<double>(0, (sum, e) => sum + e.earned);
      return WorkplaceSummary(
        workplace: workplace,
        hours: minutes / 60,
        earned: earned,
      );
    }).toList();
  }

  String _dateKey(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}
