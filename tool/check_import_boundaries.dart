// Checks the feature boundaries from "Modularity" in CLAUDE.md.
//
// Run from the repository root: `dart run tool/check_import_boundaries.dart`
//
// In an app, each folder under `lib/src/` is a feature, except:
//   - `app/`    the app shell (composition root); may import any feature entry.
//   - `shared/` code for all features; may not import features or `app/`.
// Rules:
//   1. Code outside feature F imports F only through its entry file
//      `lib/src/F/F.dart`, never F's other files.
//   2. Features and `shared/` never import `app/`.
//   3. `shared/` never imports a feature.
//   4. Tests in `test/F/` may use F's internal files; other tests (e.g.
//      `test/flows/`) follow rule 1.
//   5. No package imports another workspace package's `src/` files.
import 'dart:io';

const apps = ['apps/app', 'apps/console'];
const packages = [
  'apps/app',
  'apps/console',
  'packages/core',
  'packages/ui_kit',
];
const shell = 'app';
const shared = 'shared';

final _import = RegExp(r'''^\s*(?:import|export)\s+['"]([^'"]+)['"]''');

void main() {
  final names = {for (final p in packages) _packageName(p): p};
  final problems = <String>[];

  for (final pkg in packages) {
    final self = _packageName(pkg);
    final isApp = apps.contains(pkg);
    for (final file in _dartFiles(pkg)) {
      final rel = _rel(pkg, file.path);
      final lines = file.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final match = _import.firstMatch(lines[i]);
        if (match == null) continue;
        final uri = match.group(1)!;
        final where = '$pkg/$rel:${i + 1}';

        // Rule 5: other workspace packages only through their public API.
        if (uri.startsWith('package:')) {
          final parts = uri.substring('package:'.length).split('/');
          final target = parts.first;
          if (target != self &&
              names.containsKey(target) &&
              parts.length > 1 &&
              parts[1] == 'src') {
            problems.add(
              '$where imports $uri (use package:$target/$target.dart)',
            );
          }
        }
        if (!isApp) continue;

        final target = _resolve(self, rel, uri);
        if (target == null) continue;
        final problem = _check(rel, target);
        if (problem != null) problems.add('$where: $problem ($uri)');
      }
    }
  }

  if (problems.isEmpty) {
    stdout.writeln('Import boundaries: OK');
    return;
  }
  stderr.writeln('Import boundary violations:');
  for (final p in problems) {
    stderr.writeln('  $p');
  }
  exitCode = 1;
}

/// The area a file belongs to: a feature name, [shell], [shared], or null
/// (e.g. `lib/main.dart`, `lib/l10n/`, test helpers and cross-feature tests).
String? _area(String rel) {
  final parts = rel.split('/');
  if (parts.length > 3 && parts[0] == 'lib' && parts[1] == 'src') {
    return parts[2];
  }
  if (parts.length > 2 && parts[0] == 'test') return parts[1];
  return null;
}

String? _check(String from, String to) {
  final toParts = to.split('/');
  if (toParts.length < 4 || toParts[0] != 'lib' || toParts[1] != 'src') {
    return null; // not a file inside lib/src/<area>/
  }
  final toArea = toParts[2];
  final fromArea = _area(from);
  if (fromArea == toArea) return null;

  if (toArea == shell) {
    if (fromArea == shared || (fromArea != null && from.startsWith('lib/'))) {
      return 'only main.dart and tests may import the app shell';
    }
    return null;
  }
  if (toArea == shared) return null;
  if (fromArea == shared && from.startsWith('lib/')) {
    return 'shared code may not import a feature';
  }
  final entry = 'lib/src/$toArea/$toArea.dart';
  if (to != entry) return 'import feature "$toArea" through $entry';
  return null;
}

/// Resolves an import to a path relative to the package root, or null when it
/// points outside the package.
String? _resolve(String self, String fromRel, String uri) {
  if (uri.startsWith('package:$self/')) {
    return 'lib/${uri.substring('package:$self/'.length)}';
  }
  if (uri.contains(':')) return null;
  final base = fromRel.split('/')..removeLast();
  for (final part in uri.split('/')) {
    if (part == '..') {
      if (base.isEmpty) return null;
      base.removeLast();
    } else if (part != '.') {
      base.add(part);
    }
  }
  return base.join('/');
}

String _packageName(String pkg) {
  final line = File('$pkg/pubspec.yaml')
      .readAsLinesSync()
      .firstWhere((l) => l.startsWith('name:'));
  return line.substring('name:'.length).trim();
}

Iterable<File> _dartFiles(String pkg) sync* {
  for (final dir in ['lib', 'test']) {
    final d = Directory('$pkg/$dir');
    if (!d.existsSync()) continue;
    for (final entity in d.listSync(recursive: true)) {
      if (entity is File &&
          entity.path.endsWith('.dart') &&
          !entity.path.replaceAll('\\', '/').contains('/generated/')) {
        yield entity;
      }
    }
  }
}

String _rel(String pkg, String path) =>
    path.replaceAll('\\', '/').substring(pkg.length + 1);
