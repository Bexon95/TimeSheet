// Cursor stop hook: bump version when source files were edited this session.
import 'dart:convert';
import 'dart:io';

void main() async {
  await stdin.transform(utf8.decoder).join();

  final pending = File('.cursor/.bump-pending');
  if (!pending.existsSync()) return;

  final bumpTypeFile = File('.cursor/.bump-type');
  final bumpType = bumpTypeFile.existsSync()
      ? bumpTypeFile.readAsStringSync().trim()
      : 'build';

  final validTypes = {'major', 'minor', 'patch', 'build'};
  final type = validTypes.contains(bumpType) ? bumpType : 'build';

  try {
    final result = await _runBumpScript(type);
    if (result.stdout is String && (result.stdout as String).isNotEmpty) {
      stdout.write(result.stdout);
    }
    if (result.exitCode != 0) {
      stderr.write(result.stderr);
    }
  } on Object {
    // Fail open: never block agent stop because of version bumping.
  } finally {
    _deleteIfExists(pending);
    _deleteIfExists(bumpTypeFile);
  }
}

void _deleteIfExists(File file) {
  if (file.existsSync()) {
    file.deleteSync();
  }
}

Future<ProcessResult> _runBumpScript(String type) async {
  if (Platform.isWindows) {
    return Process.run(
      r'scripts\flutter.bat',
      ['pub', 'run', 'scripts/bump_version.dart', type],
      runInShell: true,
    );
  }

  final dart = await Process.run('dart', ['--version']);
  if (dart.exitCode == 0) {
    return Process.run('dart', ['run', 'scripts/bump_version.dart', type]);
  }

  return Process.run(
    'flutter',
    ['pub', 'run', 'scripts/bump_version.dart', type],
    runInShell: true,
  );
}
