// Bumps the version in pubspec.yaml.
//
// Usage: dart run scripts/bump_version.dart [major|minor|patch|build]
//
// - major: 1.0.0 -> 2.0.0 (breaking change)
// - minor: 1.0.0 -> 1.1.0 (new feature)
// - patch: 1.1.0 -> 1.1.1 (bug fix)
// - build: 1.1.1+5 -> 1.1.1+6 (typos, chores, small tweaks)
import 'dart:io';

const _validTypes = {'major', 'minor', 'patch', 'build'};

void main(List<String> args) {
  final bumpType = args.isEmpty ? 'build' : args.first;
  if (!_validTypes.contains(bumpType)) {
    stderr.writeln(
      'Usage: dart run scripts/bump_version.dart [major|minor|patch|build]',
    );
    exit(1);
  }

  final pubspecFile = File('pubspec.yaml');
  if (!pubspecFile.existsSync()) {
    stderr.writeln('pubspec.yaml not found in ${Directory.current.path}');
    exit(1);
  }

  final content = pubspecFile.readAsStringSync();
  final match = RegExp(
    r'^version:\s*(\d+)\.(\d+)\.(\d+)\+(\d+)\s*$',
    multiLine: true,
  ).firstMatch(content);

  if (match == null) {
    stderr.writeln('Could not parse version from pubspec.yaml');
    exit(1);
  }

  var major = int.parse(match.group(1)!);
  var minor = int.parse(match.group(2)!);
  var patch = int.parse(match.group(3)!);
  var build = int.parse(match.group(4)!);

  switch (bumpType) {
    case 'major':
      major++;
      minor = 0;
      patch = 0;
      build++;
    case 'minor':
      minor++;
      patch = 0;
      build++;
    case 'patch':
      patch++;
      build++;
    case 'build':
      build++;
  }

  final newVersion = '$major.$minor.$patch+$build';
  final updated = content.replaceFirst(
    RegExp(r'^version:\s*.+$', multiLine: true),
    'version: $newVersion',
  );

  pubspecFile.writeAsStringSync(updated);
  stdout.writeln('Bumped version to $newVersion ($bumpType)');
}
