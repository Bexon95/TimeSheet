class Workplace {
  Workplace({
    required this.id,
    required this.name,
    required this.defaultHourlyRate,
    this.recipientName = '',
    this.recipientAddress = '',
    this.sortOrder = 0,
  });

  final int id;
  final String name;
  final double defaultHourlyRate;
  final String recipientName;
  final String recipientAddress;
  final int sortOrder;

  Workplace copyWith({
    int? id,
    String? name,
    double? defaultHourlyRate,
    String? recipientName,
    String? recipientAddress,
    int? sortOrder,
  }) {
    return Workplace(
      id: id ?? this.id,
      name: name ?? this.name,
      defaultHourlyRate: defaultHourlyRate ?? this.defaultHourlyRate,
      recipientName: recipientName ?? this.recipientName,
      recipientAddress: recipientAddress ?? this.recipientAddress,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }

  Map<String, Object?> toMap() => {
        'id': id,
        'name': name,
        'default_hourly_rate': defaultHourlyRate,
        'recipient_name': recipientName,
        'recipient_address': recipientAddress,
        'sort_order': sortOrder,
      };

  factory Workplace.fromMap(Map<String, Object?> map) => Workplace(
        id: map['id'] as int,
        name: map['name'] as String,
        defaultHourlyRate: (map['default_hourly_rate'] as num).toDouble(),
        recipientName: map['recipient_name'] as String? ?? '',
        recipientAddress: map['recipient_address'] as String? ?? '',
        sortOrder: map['sort_order'] as int? ?? 0,
      );
}

class Project {
  Project({
    required this.id,
    required this.workplaceId,
    required this.name,
    this.colorValue,
  });

  final int id;
  final int workplaceId;
  final String name;
  final int? colorValue;

  Map<String, Object?> toMap() => {
        'id': id,
        'workplace_id': workplaceId,
        'name': name,
        'color_value': colorValue,
      };

  factory Project.fromMap(Map<String, Object?> map) => Project(
        id: map['id'] as int,
        workplaceId: map['workplace_id'] as int,
        name: map['name'] as String,
        colorValue: map['color_value'] as int?,
      );
}

enum EntrySource { manual, timer }

class TimeEntry {
  TimeEntry({
    required this.id,
    required this.workplaceId,
    this.projectId,
    required this.date,
    required this.startTime,
    required this.endTime,
    required this.hourlyRate,
    this.notes = '',
    this.source = EntrySource.manual,
  });

  final int id;
  final int workplaceId;
  final int? projectId;
  final DateTime date;
  final DateTime startTime;
  final DateTime endTime;
  final double hourlyRate;
  final String notes;
  final EntrySource source;

  int get durationMinutes {
    final diff = endTime.difference(startTime).inMinutes;
    return diff < 0 ? 0 : diff;
  }

  double get earned => durationMinutes * hourlyRate / 60;

  double get hours => durationMinutes / 60;

  TimeEntry copyWith({
    int? id,
    int? workplaceId,
    int? projectId,
    bool clearProject = false,
    DateTime? date,
    DateTime? startTime,
    DateTime? endTime,
    double? hourlyRate,
    String? notes,
    EntrySource? source,
  }) {
    return TimeEntry(
      id: id ?? this.id,
      workplaceId: workplaceId ?? this.workplaceId,
      projectId: clearProject ? null : (projectId ?? this.projectId),
      date: date ?? this.date,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      hourlyRate: hourlyRate ?? this.hourlyRate,
      notes: notes ?? this.notes,
      source: source ?? this.source,
    );
  }

  Map<String, Object?> toMap() => {
        'id': id,
        'workplace_id': workplaceId,
        'project_id': projectId,
        'date': date.toIso8601String().split('T').first,
        'start_time': startTime.toIso8601String(),
        'end_time': endTime.toIso8601String(),
        'hourly_rate': hourlyRate,
        'notes': notes,
        'source': source.name,
      };

  factory TimeEntry.fromMap(Map<String, Object?> map) => TimeEntry(
        id: map['id'] as int,
        workplaceId: map['workplace_id'] as int,
        projectId: map['project_id'] as int?,
        date: DateTime.parse(map['date'] as String),
        startTime: DateTime.parse(map['start_time'] as String),
        endTime: DateTime.parse(map['end_time'] as String),
        hourlyRate: (map['hourly_rate'] as num).toDouble(),
        notes: map['notes'] as String? ?? '',
        source: EntrySource.values.byName(map['source'] as String),
      );
}

class InvoiceSettings {
  InvoiceSettings({
    this.senderName = '',
    this.senderAddress = '',
    this.senderSsn = '',
    this.vatText = 'In diesem Betrag ist kein UST enthalten.',
    this.paymentText = 'Bitte um Überweisung auf mein Konto',
    this.iban = '',
    this.bic = '',
    this.lastInvoiceNumber = 0,
    this.lastInvoiceYear = 0,
  });

  final String senderName;
  final String senderAddress;
  final String senderSsn;
  final String vatText;
  final String paymentText;
  final String iban;
  final String bic;
  final int lastInvoiceNumber;
  final int lastInvoiceYear;

  InvoiceSettings copyWith({
    String? senderName,
    String? senderAddress,
    String? senderSsn,
    String? vatText,
    String? paymentText,
    String? iban,
    String? bic,
    int? lastInvoiceNumber,
    int? lastInvoiceYear,
  }) {
    return InvoiceSettings(
      senderName: senderName ?? this.senderName,
      senderAddress: senderAddress ?? this.senderAddress,
      senderSsn: senderSsn ?? this.senderSsn,
      vatText: vatText ?? this.vatText,
      paymentText: paymentText ?? this.paymentText,
      iban: iban ?? this.iban,
      bic: bic ?? this.bic,
      lastInvoiceNumber: lastInvoiceNumber ?? this.lastInvoiceNumber,
      lastInvoiceYear: lastInvoiceYear ?? this.lastInvoiceYear,
    );
  }

  Map<String, Object?> toMap() => {
        'sender_name': senderName,
        'sender_address': senderAddress,
        'sender_ssn': senderSsn,
        'vat_text': vatText,
        'payment_text': paymentText,
        'iban': iban,
        'bic': bic,
        'last_invoice_number': lastInvoiceNumber,
        'last_invoice_year': lastInvoiceYear,
      };

  factory InvoiceSettings.fromMap(Map<String, Object?> map) => InvoiceSettings(
        senderName: map['sender_name'] as String? ?? '',
        senderAddress: map['sender_address'] as String? ?? '',
        senderSsn: map['sender_ssn'] as String? ?? '',
        vatText: map['vat_text'] as String? ??
            'In diesem Betrag ist kein UST enthalten.',
        paymentText: map['payment_text'] as String? ??
            'Bitte um Überweisung auf mein Konto',
        iban: map['iban'] as String? ?? '',
        bic: map['bic'] as String? ?? '',
        lastInvoiceNumber: map['last_invoice_number'] as int? ?? 0,
        lastInvoiceYear: map['last_invoice_year'] as int? ?? 0,
      );
}

class SavedInvoice {
  SavedInvoice({
    required this.id,
    required this.workplaceId,
    required this.createdAt,
    required this.invoiceNumber,
    required this.title,
    required this.amount,
    required this.recipientName,
    required this.recipientAddress,
    required this.dateRangeStart,
    required this.dateRangeEnd,
    required this.bulletLines,
    required this.pdfFilePath,
    required this.senderSnapshot,
    required this.footerSnapshot,
    this.teilbetragLabel = 'Betrag',
  });

  final int id;
  final int workplaceId;
  final DateTime createdAt;
  final String invoiceNumber;
  final String title;
  final double amount;
  final String recipientName;
  final String recipientAddress;
  final DateTime dateRangeStart;
  final DateTime dateRangeEnd;
  final List<String> bulletLines;
  final String pdfFilePath;
  final String senderSnapshot;
  final String footerSnapshot;
  final String teilbetragLabel;

  Map<String, Object?> toMap() => {
        'id': id,
        'workplace_id': workplaceId,
        'created_at': createdAt.toIso8601String(),
        'invoice_number': invoiceNumber,
        'title': title,
        'amount': amount,
        'recipient_name': recipientName,
        'recipient_address': recipientAddress,
        'date_range_start': dateRangeStart.toIso8601String().split('T').first,
        'date_range_end': dateRangeEnd.toIso8601String().split('T').first,
        'bullet_lines': bulletLines.join('\n'),
        'pdf_file_path': pdfFilePath,
        'sender_snapshot': senderSnapshot,
        'footer_snapshot': footerSnapshot,
        'teilbetrag_label': teilbetragLabel,
      };

  factory SavedInvoice.fromMap(Map<String, Object?> map) => SavedInvoice(
        id: map['id'] as int,
        workplaceId: map['workplace_id'] as int,
        createdAt: DateTime.parse(map['created_at'] as String),
        invoiceNumber: map['invoice_number'] as String,
        title: map['title'] as String,
        amount: (map['amount'] as num).toDouble(),
        recipientName: map['recipient_name'] as String? ?? '',
        recipientAddress: map['recipient_address'] as String? ?? '',
        dateRangeStart: DateTime.parse(map['date_range_start'] as String),
        dateRangeEnd: DateTime.parse(map['date_range_end'] as String),
        bulletLines: (map['bullet_lines'] as String? ?? '')
            .split('\n')
            .where((line) => line.isNotEmpty)
            .toList(),
        pdfFilePath: map['pdf_file_path'] as String,
        senderSnapshot: map['sender_snapshot'] as String? ?? '',
        footerSnapshot: map['footer_snapshot'] as String? ?? '',
        teilbetragLabel: map['teilbetrag_label'] as String? ?? 'Betrag',
      );
}

class WorkplaceSummary {
  WorkplaceSummary({
    required this.workplace,
    required this.hours,
    required this.earned,
  });

  final Workplace workplace;
  final double hours;
  final double earned;
}

class ActiveTimer {
  ActiveTimer({
    required this.workplaceId,
    required this.startedAt,
    this.projectId,
  });

  final int workplaceId;
  final DateTime startedAt;
  final int? projectId;

  Map<String, Object?> toJson() => {
        'workplaceId': workplaceId,
        'startedAt': startedAt.toIso8601String(),
        'projectId': projectId,
      };

  factory ActiveTimer.fromJson(Map<String, dynamic> json) => ActiveTimer(
        workplaceId: json['workplaceId'] as int,
        startedAt: DateTime.parse(json['startedAt'] as String),
        projectId: json['projectId'] as int?,
      );
}
