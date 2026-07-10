// Coverage gate: parses coverage/lcov.info and fails if line coverage of
// non-generated sources under lib/src/ is below the threshold.
import 'dart:io';

const threshold = 90.0;

void main(List<String> args) {
  final lcov = File('coverage/lcov.info');
  if (!lcov.existsSync()) {
    stderr.writeln('coverage/lcov.info not found — run `flutter test --coverage` first.');
    exit(2);
  }

  var found = 0;
  var hit = 0;
  String? current;
  var include = false;

  for (final line in lcov.readAsLinesSync()) {
    if (line.startsWith('SF:')) {
      current = line.substring(3).replaceAll('\\', '/');
      include = current.contains('lib/src/') &&
          !current.endsWith('.g.dart') &&
          !current.endsWith('.drift.dart') &&
          !current.endsWith('.freezed.dart');
    } else if (include && line.startsWith('LF:')) {
      found += int.parse(line.substring(3));
    } else if (include && line.startsWith('LH:')) {
      hit += int.parse(line.substring(3));
    }
  }

  if (found == 0) {
    stderr.writeln('No coverage data for lib/src/ — suspicious, failing.');
    exit(2);
  }

  final pct = hit * 100.0 / found;
  stdout.writeln('lib/src coverage: ${pct.toStringAsFixed(2)}% ($hit/$found lines), threshold $threshold%');
  if (pct < threshold) {
    stderr.writeln('FAIL: coverage below threshold.');
    exit(1);
  }
  stdout.writeln('PASS');
}
