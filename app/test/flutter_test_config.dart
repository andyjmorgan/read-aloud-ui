import 'dart:async';

import 'package:drift/drift.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  // Tests intentionally create many independent in-memory databases.
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  await testMain();
}
