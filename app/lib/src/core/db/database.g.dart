// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $JobsTable extends Jobs with TableInfo<$JobsTable, Job> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $JobsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _transcriptJsonMeta = const VerificationMeta(
    'transcriptJson',
  );
  @override
  late final GeneratedColumn<String> transcriptJson = GeneratedColumn<String>(
    'transcript_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<JobStatus, String> status =
      GeneratedColumn<String>(
        'status',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<JobStatus>($JobsTable.$converterstatus);
  static const VerificationMeta _progressMeta = const VerificationMeta(
    'progress',
  );
  @override
  late final GeneratedColumn<double> progress = GeneratedColumn<double>(
    'progress',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _statusDetailMeta = const VerificationMeta(
    'statusDetail',
  );
  @override
  late final GeneratedColumn<String> statusDetail = GeneratedColumn<String>(
    'status_detail',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _errorMeta = const VerificationMeta('error');
  @override
  late final GeneratedColumn<String> error = GeneratedColumn<String>(
    'error',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _recordingIdMeta = const VerificationMeta(
    'recordingId',
  );
  @override
  late final GeneratedColumn<String> recordingId = GeneratedColumn<String>(
    'recording_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _voiceMeta = const VerificationMeta('voice');
  @override
  late final GeneratedColumn<String> voice = GeneratedColumn<String>(
    'voice',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _speedMeta = const VerificationMeta('speed');
  @override
  late final GeneratedColumn<double> speed = GeneratedColumn<double>(
    'speed',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _filePathMeta = const VerificationMeta(
    'filePath',
  );
  @override
  late final GeneratedColumn<String> filePath = GeneratedColumn<String>(
    'file_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _durationSecondsMeta = const VerificationMeta(
    'durationSeconds',
  );
  @override
  late final GeneratedColumn<double> durationSeconds = GeneratedColumn<double>(
    'duration_seconds',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sizeBytesMeta = const VerificationMeta(
    'sizeBytes',
  );
  @override
  late final GeneratedColumn<int> sizeBytes = GeneratedColumn<int>(
    'size_bytes',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _completedAtMeta = const VerificationMeta(
    'completedAt',
  );
  @override
  late final GeneratedColumn<DateTime> completedAt = GeneratedColumn<DateTime>(
    'completed_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    transcriptJson,
    status,
    progress,
    statusDetail,
    error,
    recordingId,
    voice,
    speed,
    filePath,
    durationSeconds,
    sizeBytes,
    createdAt,
    completedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'jobs';
  @override
  VerificationContext validateIntegrity(
    Insertable<Job> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('transcript_json')) {
      context.handle(
        _transcriptJsonMeta,
        transcriptJson.isAcceptableOrUnknown(
          data['transcript_json']!,
          _transcriptJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_transcriptJsonMeta);
    }
    if (data.containsKey('progress')) {
      context.handle(
        _progressMeta,
        progress.isAcceptableOrUnknown(data['progress']!, _progressMeta),
      );
    }
    if (data.containsKey('status_detail')) {
      context.handle(
        _statusDetailMeta,
        statusDetail.isAcceptableOrUnknown(
          data['status_detail']!,
          _statusDetailMeta,
        ),
      );
    }
    if (data.containsKey('error')) {
      context.handle(
        _errorMeta,
        error.isAcceptableOrUnknown(data['error']!, _errorMeta),
      );
    }
    if (data.containsKey('recording_id')) {
      context.handle(
        _recordingIdMeta,
        recordingId.isAcceptableOrUnknown(
          data['recording_id']!,
          _recordingIdMeta,
        ),
      );
    }
    if (data.containsKey('voice')) {
      context.handle(
        _voiceMeta,
        voice.isAcceptableOrUnknown(data['voice']!, _voiceMeta),
      );
    }
    if (data.containsKey('speed')) {
      context.handle(
        _speedMeta,
        speed.isAcceptableOrUnknown(data['speed']!, _speedMeta),
      );
    }
    if (data.containsKey('file_path')) {
      context.handle(
        _filePathMeta,
        filePath.isAcceptableOrUnknown(data['file_path']!, _filePathMeta),
      );
    }
    if (data.containsKey('duration_seconds')) {
      context.handle(
        _durationSecondsMeta,
        durationSeconds.isAcceptableOrUnknown(
          data['duration_seconds']!,
          _durationSecondsMeta,
        ),
      );
    }
    if (data.containsKey('size_bytes')) {
      context.handle(
        _sizeBytesMeta,
        sizeBytes.isAcceptableOrUnknown(data['size_bytes']!, _sizeBytesMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('completed_at')) {
      context.handle(
        _completedAtMeta,
        completedAt.isAcceptableOrUnknown(
          data['completed_at']!,
          _completedAtMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Job map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Job(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      transcriptJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}transcript_json'],
      )!,
      status: $JobsTable.$converterstatus.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}status'],
        )!,
      ),
      progress: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}progress'],
      )!,
      statusDetail: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status_detail'],
      ),
      error: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}error'],
      ),
      recordingId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}recording_id'],
      ),
      voice: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}voice'],
      ),
      speed: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}speed'],
      ),
      filePath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}file_path'],
      ),
      durationSeconds: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}duration_seconds'],
      ),
      sizeBytes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}size_bytes'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      completedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}completed_at'],
      ),
    );
  }

  @override
  $JobsTable createAlias(String alias) {
    return $JobsTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<JobStatus, String, String> $converterstatus =
      const EnumNameConverter<JobStatus>(JobStatus.values);
}

class Job extends DataClass implements Insertable<Job> {
  final int id;
  final String name;

  /// Full transcript, stored as a JSON array of paragraphs BEFORE submission.
  final String transcriptJson;
  final JobStatus status;
  final double progress;
  final String? statusDetail;
  final String? error;
  final String? recordingId;
  final String? voice;
  final double? speed;
  final String? filePath;
  final double? durationSeconds;
  final int? sizeBytes;
  final DateTime createdAt;
  final DateTime? completedAt;
  const Job({
    required this.id,
    required this.name,
    required this.transcriptJson,
    required this.status,
    required this.progress,
    this.statusDetail,
    this.error,
    this.recordingId,
    this.voice,
    this.speed,
    this.filePath,
    this.durationSeconds,
    this.sizeBytes,
    required this.createdAt,
    this.completedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    map['transcript_json'] = Variable<String>(transcriptJson);
    {
      map['status'] = Variable<String>(
        $JobsTable.$converterstatus.toSql(status),
      );
    }
    map['progress'] = Variable<double>(progress);
    if (!nullToAbsent || statusDetail != null) {
      map['status_detail'] = Variable<String>(statusDetail);
    }
    if (!nullToAbsent || error != null) {
      map['error'] = Variable<String>(error);
    }
    if (!nullToAbsent || recordingId != null) {
      map['recording_id'] = Variable<String>(recordingId);
    }
    if (!nullToAbsent || voice != null) {
      map['voice'] = Variable<String>(voice);
    }
    if (!nullToAbsent || speed != null) {
      map['speed'] = Variable<double>(speed);
    }
    if (!nullToAbsent || filePath != null) {
      map['file_path'] = Variable<String>(filePath);
    }
    if (!nullToAbsent || durationSeconds != null) {
      map['duration_seconds'] = Variable<double>(durationSeconds);
    }
    if (!nullToAbsent || sizeBytes != null) {
      map['size_bytes'] = Variable<int>(sizeBytes);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    if (!nullToAbsent || completedAt != null) {
      map['completed_at'] = Variable<DateTime>(completedAt);
    }
    return map;
  }

  JobsCompanion toCompanion(bool nullToAbsent) {
    return JobsCompanion(
      id: Value(id),
      name: Value(name),
      transcriptJson: Value(transcriptJson),
      status: Value(status),
      progress: Value(progress),
      statusDetail: statusDetail == null && nullToAbsent
          ? const Value.absent()
          : Value(statusDetail),
      error: error == null && nullToAbsent
          ? const Value.absent()
          : Value(error),
      recordingId: recordingId == null && nullToAbsent
          ? const Value.absent()
          : Value(recordingId),
      voice: voice == null && nullToAbsent
          ? const Value.absent()
          : Value(voice),
      speed: speed == null && nullToAbsent
          ? const Value.absent()
          : Value(speed),
      filePath: filePath == null && nullToAbsent
          ? const Value.absent()
          : Value(filePath),
      durationSeconds: durationSeconds == null && nullToAbsent
          ? const Value.absent()
          : Value(durationSeconds),
      sizeBytes: sizeBytes == null && nullToAbsent
          ? const Value.absent()
          : Value(sizeBytes),
      createdAt: Value(createdAt),
      completedAt: completedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(completedAt),
    );
  }

  factory Job.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Job(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      transcriptJson: serializer.fromJson<String>(json['transcriptJson']),
      status: $JobsTable.$converterstatus.fromJson(
        serializer.fromJson<String>(json['status']),
      ),
      progress: serializer.fromJson<double>(json['progress']),
      statusDetail: serializer.fromJson<String?>(json['statusDetail']),
      error: serializer.fromJson<String?>(json['error']),
      recordingId: serializer.fromJson<String?>(json['recordingId']),
      voice: serializer.fromJson<String?>(json['voice']),
      speed: serializer.fromJson<double?>(json['speed']),
      filePath: serializer.fromJson<String?>(json['filePath']),
      durationSeconds: serializer.fromJson<double?>(json['durationSeconds']),
      sizeBytes: serializer.fromJson<int?>(json['sizeBytes']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      completedAt: serializer.fromJson<DateTime?>(json['completedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'transcriptJson': serializer.toJson<String>(transcriptJson),
      'status': serializer.toJson<String>(
        $JobsTable.$converterstatus.toJson(status),
      ),
      'progress': serializer.toJson<double>(progress),
      'statusDetail': serializer.toJson<String?>(statusDetail),
      'error': serializer.toJson<String?>(error),
      'recordingId': serializer.toJson<String?>(recordingId),
      'voice': serializer.toJson<String?>(voice),
      'speed': serializer.toJson<double?>(speed),
      'filePath': serializer.toJson<String?>(filePath),
      'durationSeconds': serializer.toJson<double?>(durationSeconds),
      'sizeBytes': serializer.toJson<int?>(sizeBytes),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'completedAt': serializer.toJson<DateTime?>(completedAt),
    };
  }

  Job copyWith({
    int? id,
    String? name,
    String? transcriptJson,
    JobStatus? status,
    double? progress,
    Value<String?> statusDetail = const Value.absent(),
    Value<String?> error = const Value.absent(),
    Value<String?> recordingId = const Value.absent(),
    Value<String?> voice = const Value.absent(),
    Value<double?> speed = const Value.absent(),
    Value<String?> filePath = const Value.absent(),
    Value<double?> durationSeconds = const Value.absent(),
    Value<int?> sizeBytes = const Value.absent(),
    DateTime? createdAt,
    Value<DateTime?> completedAt = const Value.absent(),
  }) => Job(
    id: id ?? this.id,
    name: name ?? this.name,
    transcriptJson: transcriptJson ?? this.transcriptJson,
    status: status ?? this.status,
    progress: progress ?? this.progress,
    statusDetail: statusDetail.present ? statusDetail.value : this.statusDetail,
    error: error.present ? error.value : this.error,
    recordingId: recordingId.present ? recordingId.value : this.recordingId,
    voice: voice.present ? voice.value : this.voice,
    speed: speed.present ? speed.value : this.speed,
    filePath: filePath.present ? filePath.value : this.filePath,
    durationSeconds: durationSeconds.present
        ? durationSeconds.value
        : this.durationSeconds,
    sizeBytes: sizeBytes.present ? sizeBytes.value : this.sizeBytes,
    createdAt: createdAt ?? this.createdAt,
    completedAt: completedAt.present ? completedAt.value : this.completedAt,
  );
  Job copyWithCompanion(JobsCompanion data) {
    return Job(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      transcriptJson: data.transcriptJson.present
          ? data.transcriptJson.value
          : this.transcriptJson,
      status: data.status.present ? data.status.value : this.status,
      progress: data.progress.present ? data.progress.value : this.progress,
      statusDetail: data.statusDetail.present
          ? data.statusDetail.value
          : this.statusDetail,
      error: data.error.present ? data.error.value : this.error,
      recordingId: data.recordingId.present
          ? data.recordingId.value
          : this.recordingId,
      voice: data.voice.present ? data.voice.value : this.voice,
      speed: data.speed.present ? data.speed.value : this.speed,
      filePath: data.filePath.present ? data.filePath.value : this.filePath,
      durationSeconds: data.durationSeconds.present
          ? data.durationSeconds.value
          : this.durationSeconds,
      sizeBytes: data.sizeBytes.present ? data.sizeBytes.value : this.sizeBytes,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      completedAt: data.completedAt.present
          ? data.completedAt.value
          : this.completedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Job(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('transcriptJson: $transcriptJson, ')
          ..write('status: $status, ')
          ..write('progress: $progress, ')
          ..write('statusDetail: $statusDetail, ')
          ..write('error: $error, ')
          ..write('recordingId: $recordingId, ')
          ..write('voice: $voice, ')
          ..write('speed: $speed, ')
          ..write('filePath: $filePath, ')
          ..write('durationSeconds: $durationSeconds, ')
          ..write('sizeBytes: $sizeBytes, ')
          ..write('createdAt: $createdAt, ')
          ..write('completedAt: $completedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    transcriptJson,
    status,
    progress,
    statusDetail,
    error,
    recordingId,
    voice,
    speed,
    filePath,
    durationSeconds,
    sizeBytes,
    createdAt,
    completedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Job &&
          other.id == this.id &&
          other.name == this.name &&
          other.transcriptJson == this.transcriptJson &&
          other.status == this.status &&
          other.progress == this.progress &&
          other.statusDetail == this.statusDetail &&
          other.error == this.error &&
          other.recordingId == this.recordingId &&
          other.voice == this.voice &&
          other.speed == this.speed &&
          other.filePath == this.filePath &&
          other.durationSeconds == this.durationSeconds &&
          other.sizeBytes == this.sizeBytes &&
          other.createdAt == this.createdAt &&
          other.completedAt == this.completedAt);
}

class JobsCompanion extends UpdateCompanion<Job> {
  final Value<int> id;
  final Value<String> name;
  final Value<String> transcriptJson;
  final Value<JobStatus> status;
  final Value<double> progress;
  final Value<String?> statusDetail;
  final Value<String?> error;
  final Value<String?> recordingId;
  final Value<String?> voice;
  final Value<double?> speed;
  final Value<String?> filePath;
  final Value<double?> durationSeconds;
  final Value<int?> sizeBytes;
  final Value<DateTime> createdAt;
  final Value<DateTime?> completedAt;
  const JobsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.transcriptJson = const Value.absent(),
    this.status = const Value.absent(),
    this.progress = const Value.absent(),
    this.statusDetail = const Value.absent(),
    this.error = const Value.absent(),
    this.recordingId = const Value.absent(),
    this.voice = const Value.absent(),
    this.speed = const Value.absent(),
    this.filePath = const Value.absent(),
    this.durationSeconds = const Value.absent(),
    this.sizeBytes = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.completedAt = const Value.absent(),
  });
  JobsCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    required String transcriptJson,
    required JobStatus status,
    this.progress = const Value.absent(),
    this.statusDetail = const Value.absent(),
    this.error = const Value.absent(),
    this.recordingId = const Value.absent(),
    this.voice = const Value.absent(),
    this.speed = const Value.absent(),
    this.filePath = const Value.absent(),
    this.durationSeconds = const Value.absent(),
    this.sizeBytes = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.completedAt = const Value.absent(),
  }) : name = Value(name),
       transcriptJson = Value(transcriptJson),
       status = Value(status);
  static Insertable<Job> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<String>? transcriptJson,
    Expression<String>? status,
    Expression<double>? progress,
    Expression<String>? statusDetail,
    Expression<String>? error,
    Expression<String>? recordingId,
    Expression<String>? voice,
    Expression<double>? speed,
    Expression<String>? filePath,
    Expression<double>? durationSeconds,
    Expression<int>? sizeBytes,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? completedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (transcriptJson != null) 'transcript_json': transcriptJson,
      if (status != null) 'status': status,
      if (progress != null) 'progress': progress,
      if (statusDetail != null) 'status_detail': statusDetail,
      if (error != null) 'error': error,
      if (recordingId != null) 'recording_id': recordingId,
      if (voice != null) 'voice': voice,
      if (speed != null) 'speed': speed,
      if (filePath != null) 'file_path': filePath,
      if (durationSeconds != null) 'duration_seconds': durationSeconds,
      if (sizeBytes != null) 'size_bytes': sizeBytes,
      if (createdAt != null) 'created_at': createdAt,
      if (completedAt != null) 'completed_at': completedAt,
    });
  }

  JobsCompanion copyWith({
    Value<int>? id,
    Value<String>? name,
    Value<String>? transcriptJson,
    Value<JobStatus>? status,
    Value<double>? progress,
    Value<String?>? statusDetail,
    Value<String?>? error,
    Value<String?>? recordingId,
    Value<String?>? voice,
    Value<double?>? speed,
    Value<String?>? filePath,
    Value<double?>? durationSeconds,
    Value<int?>? sizeBytes,
    Value<DateTime>? createdAt,
    Value<DateTime?>? completedAt,
  }) {
    return JobsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      transcriptJson: transcriptJson ?? this.transcriptJson,
      status: status ?? this.status,
      progress: progress ?? this.progress,
      statusDetail: statusDetail ?? this.statusDetail,
      error: error ?? this.error,
      recordingId: recordingId ?? this.recordingId,
      voice: voice ?? this.voice,
      speed: speed ?? this.speed,
      filePath: filePath ?? this.filePath,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      sizeBytes: sizeBytes ?? this.sizeBytes,
      createdAt: createdAt ?? this.createdAt,
      completedAt: completedAt ?? this.completedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (transcriptJson.present) {
      map['transcript_json'] = Variable<String>(transcriptJson.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(
        $JobsTable.$converterstatus.toSql(status.value),
      );
    }
    if (progress.present) {
      map['progress'] = Variable<double>(progress.value);
    }
    if (statusDetail.present) {
      map['status_detail'] = Variable<String>(statusDetail.value);
    }
    if (error.present) {
      map['error'] = Variable<String>(error.value);
    }
    if (recordingId.present) {
      map['recording_id'] = Variable<String>(recordingId.value);
    }
    if (voice.present) {
      map['voice'] = Variable<String>(voice.value);
    }
    if (speed.present) {
      map['speed'] = Variable<double>(speed.value);
    }
    if (filePath.present) {
      map['file_path'] = Variable<String>(filePath.value);
    }
    if (durationSeconds.present) {
      map['duration_seconds'] = Variable<double>(durationSeconds.value);
    }
    if (sizeBytes.present) {
      map['size_bytes'] = Variable<int>(sizeBytes.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (completedAt.present) {
      map['completed_at'] = Variable<DateTime>(completedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('JobsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('transcriptJson: $transcriptJson, ')
          ..write('status: $status, ')
          ..write('progress: $progress, ')
          ..write('statusDetail: $statusDetail, ')
          ..write('error: $error, ')
          ..write('recordingId: $recordingId, ')
          ..write('voice: $voice, ')
          ..write('speed: $speed, ')
          ..write('filePath: $filePath, ')
          ..write('durationSeconds: $durationSeconds, ')
          ..write('sizeBytes: $sizeBytes, ')
          ..write('createdAt: $createdAt, ')
          ..write('completedAt: $completedAt')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $JobsTable jobs = $JobsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [jobs];
}

typedef $$JobsTableCreateCompanionBuilder =
    JobsCompanion Function({
      Value<int> id,
      required String name,
      required String transcriptJson,
      required JobStatus status,
      Value<double> progress,
      Value<String?> statusDetail,
      Value<String?> error,
      Value<String?> recordingId,
      Value<String?> voice,
      Value<double?> speed,
      Value<String?> filePath,
      Value<double?> durationSeconds,
      Value<int?> sizeBytes,
      Value<DateTime> createdAt,
      Value<DateTime?> completedAt,
    });
typedef $$JobsTableUpdateCompanionBuilder =
    JobsCompanion Function({
      Value<int> id,
      Value<String> name,
      Value<String> transcriptJson,
      Value<JobStatus> status,
      Value<double> progress,
      Value<String?> statusDetail,
      Value<String?> error,
      Value<String?> recordingId,
      Value<String?> voice,
      Value<double?> speed,
      Value<String?> filePath,
      Value<double?> durationSeconds,
      Value<int?> sizeBytes,
      Value<DateTime> createdAt,
      Value<DateTime?> completedAt,
    });

class $$JobsTableFilterComposer extends Composer<_$AppDatabase, $JobsTable> {
  $$JobsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get transcriptJson => $composableBuilder(
    column: $table.transcriptJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<JobStatus, JobStatus, String> get status =>
      $composableBuilder(
        column: $table.status,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<double> get progress => $composableBuilder(
    column: $table.progress,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get statusDetail => $composableBuilder(
    column: $table.statusDetail,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get error => $composableBuilder(
    column: $table.error,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get recordingId => $composableBuilder(
    column: $table.recordingId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get voice => $composableBuilder(
    column: $table.voice,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get speed => $composableBuilder(
    column: $table.speed,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get filePath => $composableBuilder(
    column: $table.filePath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get durationSeconds => $composableBuilder(
    column: $table.durationSeconds,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sizeBytes => $composableBuilder(
    column: $table.sizeBytes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$JobsTableOrderingComposer extends Composer<_$AppDatabase, $JobsTable> {
  $$JobsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get transcriptJson => $composableBuilder(
    column: $table.transcriptJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get progress => $composableBuilder(
    column: $table.progress,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get statusDetail => $composableBuilder(
    column: $table.statusDetail,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get error => $composableBuilder(
    column: $table.error,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get recordingId => $composableBuilder(
    column: $table.recordingId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get voice => $composableBuilder(
    column: $table.voice,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get speed => $composableBuilder(
    column: $table.speed,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get filePath => $composableBuilder(
    column: $table.filePath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get durationSeconds => $composableBuilder(
    column: $table.durationSeconds,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sizeBytes => $composableBuilder(
    column: $table.sizeBytes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$JobsTableAnnotationComposer
    extends Composer<_$AppDatabase, $JobsTable> {
  $$JobsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get transcriptJson => $composableBuilder(
    column: $table.transcriptJson,
    builder: (column) => column,
  );

  GeneratedColumnWithTypeConverter<JobStatus, String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<double> get progress =>
      $composableBuilder(column: $table.progress, builder: (column) => column);

  GeneratedColumn<String> get statusDetail => $composableBuilder(
    column: $table.statusDetail,
    builder: (column) => column,
  );

  GeneratedColumn<String> get error =>
      $composableBuilder(column: $table.error, builder: (column) => column);

  GeneratedColumn<String> get recordingId => $composableBuilder(
    column: $table.recordingId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get voice =>
      $composableBuilder(column: $table.voice, builder: (column) => column);

  GeneratedColumn<double> get speed =>
      $composableBuilder(column: $table.speed, builder: (column) => column);

  GeneratedColumn<String> get filePath =>
      $composableBuilder(column: $table.filePath, builder: (column) => column);

  GeneratedColumn<double> get durationSeconds => $composableBuilder(
    column: $table.durationSeconds,
    builder: (column) => column,
  );

  GeneratedColumn<int> get sizeBytes =>
      $composableBuilder(column: $table.sizeBytes, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => column,
  );
}

class $$JobsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $JobsTable,
          Job,
          $$JobsTableFilterComposer,
          $$JobsTableOrderingComposer,
          $$JobsTableAnnotationComposer,
          $$JobsTableCreateCompanionBuilder,
          $$JobsTableUpdateCompanionBuilder,
          (Job, BaseReferences<_$AppDatabase, $JobsTable, Job>),
          Job,
          PrefetchHooks Function()
        > {
  $$JobsTableTableManager(_$AppDatabase db, $JobsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$JobsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$JobsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$JobsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> transcriptJson = const Value.absent(),
                Value<JobStatus> status = const Value.absent(),
                Value<double> progress = const Value.absent(),
                Value<String?> statusDetail = const Value.absent(),
                Value<String?> error = const Value.absent(),
                Value<String?> recordingId = const Value.absent(),
                Value<String?> voice = const Value.absent(),
                Value<double?> speed = const Value.absent(),
                Value<String?> filePath = const Value.absent(),
                Value<double?> durationSeconds = const Value.absent(),
                Value<int?> sizeBytes = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime?> completedAt = const Value.absent(),
              }) => JobsCompanion(
                id: id,
                name: name,
                transcriptJson: transcriptJson,
                status: status,
                progress: progress,
                statusDetail: statusDetail,
                error: error,
                recordingId: recordingId,
                voice: voice,
                speed: speed,
                filePath: filePath,
                durationSeconds: durationSeconds,
                sizeBytes: sizeBytes,
                createdAt: createdAt,
                completedAt: completedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String name,
                required String transcriptJson,
                required JobStatus status,
                Value<double> progress = const Value.absent(),
                Value<String?> statusDetail = const Value.absent(),
                Value<String?> error = const Value.absent(),
                Value<String?> recordingId = const Value.absent(),
                Value<String?> voice = const Value.absent(),
                Value<double?> speed = const Value.absent(),
                Value<String?> filePath = const Value.absent(),
                Value<double?> durationSeconds = const Value.absent(),
                Value<int?> sizeBytes = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime?> completedAt = const Value.absent(),
              }) => JobsCompanion.insert(
                id: id,
                name: name,
                transcriptJson: transcriptJson,
                status: status,
                progress: progress,
                statusDetail: statusDetail,
                error: error,
                recordingId: recordingId,
                voice: voice,
                speed: speed,
                filePath: filePath,
                durationSeconds: durationSeconds,
                sizeBytes: sizeBytes,
                createdAt: createdAt,
                completedAt: completedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$JobsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $JobsTable,
      Job,
      $$JobsTableFilterComposer,
      $$JobsTableOrderingComposer,
      $$JobsTableAnnotationComposer,
      $$JobsTableCreateCompanionBuilder,
      $$JobsTableUpdateCompanionBuilder,
      (Job, BaseReferences<_$AppDatabase, $JobsTable, Job>),
      Job,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$JobsTableTableManager get jobs => $$JobsTableTableManager(_db, _db.jobs);
}
