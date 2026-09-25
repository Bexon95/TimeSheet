// Cursor afterFileEdit hook: mark that source files were edited this session.
import 'dart:convert';
import 'dart:io';

void main() async {
  final input = await stdin.transform(utf8.decoder).join();
  if (input.isEmpty) return;

  try {
    final payload = jsonDecode(input) as Map<String, dynamic>;
    final filePath = _filePath(payload);
    if (filePath == null) return;
    if (!_shouldTrack(filePath)) return;

    final marker = File('.cursor/.bump-pending');
    marker.parent.createSync(recursive: true);
    marker.writeAsStringSync('1');
  } on Object {
    // Fail open: never block edits because of version tracking.
  }
}

String? _filePath(Map<String, dynamic> payload) {
  for (final key in ['file_path', 'path', 'filePath']) {
    final value = payload[key];
    if (value is String && value.isNotEmpty) return value;
  }
  return null;
}

bool _shouldTrack(String filePath) {
  final normalized = filePath.replaceAll('\\', '/');
  if (!normalized.contains('/lib/') && !normalized.startsWith('lib/')) {
    return false;
  }
  if (normalized.endsWith('.dart') == false) return false;
  if (normalized.contains('/test/') || normalized.startsWith('test/')) {
    return false;
  }
  return true;
}
