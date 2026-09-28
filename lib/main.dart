import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app.dart';
import 'database/database_helper.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('de_DE', null);
  await DatabaseHelper.instance.database;
  runApp(const ProviderScope(child: TimeSheetApp()));
}
