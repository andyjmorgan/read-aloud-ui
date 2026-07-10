import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';

part 'database.g.dart';

/// Job lifecycle. Order matters for UI sorting of active vs terminal states.
enum JobStatus { queued, submitting, generating, downloading, done, failed }

class Jobs extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();

  /// Full transcript, stored as a JSON array of paragraphs BEFORE submission.
  TextColumn get transcriptJson => text()();
  TextColumn get status => textEnum<JobStatus>()();
  RealColumn get progress => real().withDefault(const Constant(0))();
  TextColumn get statusDetail => text().nullable()();
  TextColumn get error => text().nullable()();
  TextColumn get recordingId => text().nullable()();
  TextColumn get voice => text().nullable()();
  RealColumn get speed => real().nullable()();
  TextColumn get filePath => text().nullable()();
  RealColumn get durationSeconds => real().nullable()();
  IntColumn get sizeBytes => integer().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get completedAt => dateTime().nullable()();
}

@DriftDatabase(tables: [Jobs])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.executor);

  AppDatabase.file(String path)
      : super(NativeDatabase.createInBackground(File(path)));

  AppDatabase.memory() : super(NativeDatabase.memory());

  @override
  int get schemaVersion => 1;

  Future<Job> insertJob({
    required String name,
    required List<String> paragraphs,
    String? voice,
    double? speed,
  }) async {
    final id = await into(jobs).insert(JobsCompanion.insert(
      name: name,
      transcriptJson: jsonEncode(paragraphs),
      status: JobStatus.queued,
      voice: Value(voice),
      speed: Value(speed),
    ));
    return (select(jobs)..where((j) => j.id.equals(id))).getSingle();
  }

  Future<Job?> getJob(int id) =>
      (select(jobs)..where((j) => j.id.equals(id))).getSingleOrNull();

  Future<List<Job>> allJobs() =>
      (select(jobs)..orderBy([(j) => OrderingTerm.desc(j.createdAt), (j) => OrderingTerm.desc(j.id)])).get();

  Stream<List<Job>> watchJobs() =>
      (select(jobs)..orderBy([(j) => OrderingTerm.desc(j.createdAt), (j) => OrderingTerm.desc(j.id)])).watch();

  Future<List<Job>> pendingJobs() => (select(jobs)
        ..where((j) => j.status.isInValues([JobStatus.queued, JobStatus.submitting, JobStatus.generating, JobStatus.downloading]))
        ..orderBy([(j) => OrderingTerm.asc(j.id)]))
      .get();

  Future<void> updateJob(int id, JobsCompanion changes) =>
      (update(jobs)..where((j) => j.id.equals(id))).write(changes);

  Future<void> deleteJob(int id) =>
      (delete(jobs)..where((j) => j.id.equals(id))).go();
}

List<String> decodeTranscript(String transcriptJson) =>
    (jsonDecode(transcriptJson) as List).cast<String>();
