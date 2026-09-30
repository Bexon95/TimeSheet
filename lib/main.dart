import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app.dart';
import 'screens/calendar/calendar_view_mode.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('de_DE', null);
  final calendarViewMode = await loadStoredCalendarViewMode();
  runApp(
    ProviderScope(
      overrides: [
        calendarViewModeProvider.overrideWith((ref) => calendarViewMode),
      ],
      child: const TimeSheetApp(),
    ),
  );
}
