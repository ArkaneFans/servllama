// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $AssistantsTable extends Assistants
    with TableInfo<$AssistantsTable, DbAssistants> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AssistantsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
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
  static const VerificationMeta _revisionMeta = const VerificationMeta(
    'revision',
  );
  @override
  late final GeneratedColumn<int> revision = GeneratedColumn<int>(
    'revision',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _configMeta = const VerificationMeta('config');
  @override
  late final GeneratedColumn<String> config = GeneratedColumn<String>(
    'config',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, name, revision, config];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'assistants';
  @override
  VerificationContext validateIntegrity(
    Insertable<DbAssistants> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('revision')) {
      context.handle(
        _revisionMeta,
        revision.isAcceptableOrUnknown(data['revision']!, _revisionMeta),
      );
    } else if (isInserting) {
      context.missing(_revisionMeta);
    }
    if (data.containsKey('config')) {
      context.handle(
        _configMeta,
        config.isAcceptableOrUnknown(data['config']!, _configMeta),
      );
    } else if (isInserting) {
      context.missing(_configMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  DbAssistants map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DbAssistants(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      revision: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}revision'],
      )!,
      config: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}config'],
      )!,
    );
  }

  @override
  $AssistantsTable createAlias(String alias) {
    return $AssistantsTable(attachedDatabase, alias);
  }
}

class DbAssistants extends DataClass implements Insertable<DbAssistants> {
  final String id;
  final String name;
  final int revision;
  final String config;
  const DbAssistants({
    required this.id,
    required this.name,
    required this.revision,
    required this.config,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['revision'] = Variable<int>(revision);
    map['config'] = Variable<String>(config);
    return map;
  }

  AssistantsCompanion toCompanion(bool nullToAbsent) {
    return AssistantsCompanion(
      id: Value(id),
      name: Value(name),
      revision: Value(revision),
      config: Value(config),
    );
  }

  factory DbAssistants.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DbAssistants(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      revision: serializer.fromJson<int>(json['revision']),
      config: serializer.fromJson<String>(json['config']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'revision': serializer.toJson<int>(revision),
      'config': serializer.toJson<String>(config),
    };
  }

  DbAssistants copyWith({
    String? id,
    String? name,
    int? revision,
    String? config,
  }) => DbAssistants(
    id: id ?? this.id,
    name: name ?? this.name,
    revision: revision ?? this.revision,
    config: config ?? this.config,
  );
  DbAssistants copyWithCompanion(AssistantsCompanion data) {
    return DbAssistants(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      revision: data.revision.present ? data.revision.value : this.revision,
      config: data.config.present ? data.config.value : this.config,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DbAssistants(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('revision: $revision, ')
          ..write('config: $config')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, revision, config);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DbAssistants &&
          other.id == this.id &&
          other.name == this.name &&
          other.revision == this.revision &&
          other.config == this.config);
}

class AssistantsCompanion extends UpdateCompanion<DbAssistants> {
  final Value<String> id;
  final Value<String> name;
  final Value<int> revision;
  final Value<String> config;
  final Value<int> rowid;
  const AssistantsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.revision = const Value.absent(),
    this.config = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AssistantsCompanion.insert({
    required String id,
    required String name,
    required int revision,
    required String config,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       revision = Value(revision),
       config = Value(config);
  static Insertable<DbAssistants> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<int>? revision,
    Expression<String>? config,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (revision != null) 'revision': revision,
      if (config != null) 'config': config,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AssistantsCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<int>? revision,
    Value<String>? config,
    Value<int>? rowid,
  }) {
    return AssistantsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      revision: revision ?? this.revision,
      config: config ?? this.config,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (revision.present) {
      map['revision'] = Variable<int>(revision.value);
    }
    if (config.present) {
      map['config'] = Variable<String>(config.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AssistantsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('revision: $revision, ')
          ..write('config: $config, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AiConnectionsTable extends AiConnections
    with TableInfo<$AiConnectionsTable, DbAiConnections> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AiConnectionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
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
  static const VerificationMeta _revisionMeta = const VerificationMeta(
    'revision',
  );
  @override
  late final GeneratedColumn<int> revision = GeneratedColumn<int>(
    'revision',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _configMeta = const VerificationMeta('config');
  @override
  late final GeneratedColumn<String> config = GeneratedColumn<String>(
    'config',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, name, revision, config];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'ai_connections';
  @override
  VerificationContext validateIntegrity(
    Insertable<DbAiConnections> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('revision')) {
      context.handle(
        _revisionMeta,
        revision.isAcceptableOrUnknown(data['revision']!, _revisionMeta),
      );
    } else if (isInserting) {
      context.missing(_revisionMeta);
    }
    if (data.containsKey('config')) {
      context.handle(
        _configMeta,
        config.isAcceptableOrUnknown(data['config']!, _configMeta),
      );
    } else if (isInserting) {
      context.missing(_configMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  DbAiConnections map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DbAiConnections(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      revision: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}revision'],
      )!,
      config: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}config'],
      )!,
    );
  }

  @override
  $AiConnectionsTable createAlias(String alias) {
    return $AiConnectionsTable(attachedDatabase, alias);
  }
}

class DbAiConnections extends DataClass implements Insertable<DbAiConnections> {
  final String id;
  final String name;
  final int revision;
  final String config;
  const DbAiConnections({
    required this.id,
    required this.name,
    required this.revision,
    required this.config,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['revision'] = Variable<int>(revision);
    map['config'] = Variable<String>(config);
    return map;
  }

  AiConnectionsCompanion toCompanion(bool nullToAbsent) {
    return AiConnectionsCompanion(
      id: Value(id),
      name: Value(name),
      revision: Value(revision),
      config: Value(config),
    );
  }

  factory DbAiConnections.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DbAiConnections(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      revision: serializer.fromJson<int>(json['revision']),
      config: serializer.fromJson<String>(json['config']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'revision': serializer.toJson<int>(revision),
      'config': serializer.toJson<String>(config),
    };
  }

  DbAiConnections copyWith({
    String? id,
    String? name,
    int? revision,
    String? config,
  }) => DbAiConnections(
    id: id ?? this.id,
    name: name ?? this.name,
    revision: revision ?? this.revision,
    config: config ?? this.config,
  );
  DbAiConnections copyWithCompanion(AiConnectionsCompanion data) {
    return DbAiConnections(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      revision: data.revision.present ? data.revision.value : this.revision,
      config: data.config.present ? data.config.value : this.config,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DbAiConnections(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('revision: $revision, ')
          ..write('config: $config')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, revision, config);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DbAiConnections &&
          other.id == this.id &&
          other.name == this.name &&
          other.revision == this.revision &&
          other.config == this.config);
}

class AiConnectionsCompanion extends UpdateCompanion<DbAiConnections> {
  final Value<String> id;
  final Value<String> name;
  final Value<int> revision;
  final Value<String> config;
  final Value<int> rowid;
  const AiConnectionsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.revision = const Value.absent(),
    this.config = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AiConnectionsCompanion.insert({
    required String id,
    required String name,
    required int revision,
    required String config,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       revision = Value(revision),
       config = Value(config);
  static Insertable<DbAiConnections> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<int>? revision,
    Expression<String>? config,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (revision != null) 'revision': revision,
      if (config != null) 'config': config,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AiConnectionsCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<int>? revision,
    Value<String>? config,
    Value<int>? rowid,
  }) {
    return AiConnectionsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      revision: revision ?? this.revision,
      config: config ?? this.config,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (revision.present) {
      map['revision'] = Variable<int>(revision.value);
    }
    if (config.present) {
      map['config'] = Variable<String>(config.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AiConnectionsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('revision: $revision, ')
          ..write('config: $config, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SkillsTable extends Skills with TableInfo<$SkillsTable, DbSkills> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SkillsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
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
  static const VerificationMeta _hashMeta = const VerificationMeta('hash');
  @override
  late final GeneratedColumn<String> hash = GeneratedColumn<String>(
    'hash',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _configMeta = const VerificationMeta('config');
  @override
  late final GeneratedColumn<String> config = GeneratedColumn<String>(
    'config',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, name, hash, config];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'skills';
  @override
  VerificationContext validateIntegrity(
    Insertable<DbSkills> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('hash')) {
      context.handle(
        _hashMeta,
        hash.isAcceptableOrUnknown(data['hash']!, _hashMeta),
      );
    } else if (isInserting) {
      context.missing(_hashMeta);
    }
    if (data.containsKey('config')) {
      context.handle(
        _configMeta,
        config.isAcceptableOrUnknown(data['config']!, _configMeta),
      );
    } else if (isInserting) {
      context.missing(_configMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  DbSkills map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DbSkills(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      hash: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}hash'],
      )!,
      config: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}config'],
      )!,
    );
  }

  @override
  $SkillsTable createAlias(String alias) {
    return $SkillsTable(attachedDatabase, alias);
  }
}

class DbSkills extends DataClass implements Insertable<DbSkills> {
  final String id;
  final String name;
  final String hash;
  final String config;
  const DbSkills({
    required this.id,
    required this.name,
    required this.hash,
    required this.config,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['hash'] = Variable<String>(hash);
    map['config'] = Variable<String>(config);
    return map;
  }

  SkillsCompanion toCompanion(bool nullToAbsent) {
    return SkillsCompanion(
      id: Value(id),
      name: Value(name),
      hash: Value(hash),
      config: Value(config),
    );
  }

  factory DbSkills.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DbSkills(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      hash: serializer.fromJson<String>(json['hash']),
      config: serializer.fromJson<String>(json['config']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'hash': serializer.toJson<String>(hash),
      'config': serializer.toJson<String>(config),
    };
  }

  DbSkills copyWith({String? id, String? name, String? hash, String? config}) =>
      DbSkills(
        id: id ?? this.id,
        name: name ?? this.name,
        hash: hash ?? this.hash,
        config: config ?? this.config,
      );
  DbSkills copyWithCompanion(SkillsCompanion data) {
    return DbSkills(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      hash: data.hash.present ? data.hash.value : this.hash,
      config: data.config.present ? data.config.value : this.config,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DbSkills(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('hash: $hash, ')
          ..write('config: $config')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, hash, config);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DbSkills &&
          other.id == this.id &&
          other.name == this.name &&
          other.hash == this.hash &&
          other.config == this.config);
}

class SkillsCompanion extends UpdateCompanion<DbSkills> {
  final Value<String> id;
  final Value<String> name;
  final Value<String> hash;
  final Value<String> config;
  final Value<int> rowid;
  const SkillsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.hash = const Value.absent(),
    this.config = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SkillsCompanion.insert({
    required String id,
    required String name,
    required String hash,
    required String config,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       hash = Value(hash),
       config = Value(config);
  static Insertable<DbSkills> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? hash,
    Expression<String>? config,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (hash != null) 'hash': hash,
      if (config != null) 'config': config,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SkillsCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<String>? hash,
    Value<String>? config,
    Value<int>? rowid,
  }) {
    return SkillsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      hash: hash ?? this.hash,
      config: config ?? this.config,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (hash.present) {
      map['hash'] = Variable<String>(hash.value);
    }
    if (config.present) {
      map['config'] = Variable<String>(config.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SkillsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('hash: $hash, ')
          ..write('config: $config, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $McpServersTable extends McpServers
    with TableInfo<$McpServersTable, DbMcpServers> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $McpServersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
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
  static const VerificationMeta _revisionMeta = const VerificationMeta(
    'revision',
  );
  @override
  late final GeneratedColumn<int> revision = GeneratedColumn<int>(
    'revision',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _configMeta = const VerificationMeta('config');
  @override
  late final GeneratedColumn<String> config = GeneratedColumn<String>(
    'config',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, name, revision, config];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'mcp_servers';
  @override
  VerificationContext validateIntegrity(
    Insertable<DbMcpServers> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('revision')) {
      context.handle(
        _revisionMeta,
        revision.isAcceptableOrUnknown(data['revision']!, _revisionMeta),
      );
    } else if (isInserting) {
      context.missing(_revisionMeta);
    }
    if (data.containsKey('config')) {
      context.handle(
        _configMeta,
        config.isAcceptableOrUnknown(data['config']!, _configMeta),
      );
    } else if (isInserting) {
      context.missing(_configMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  DbMcpServers map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DbMcpServers(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      revision: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}revision'],
      )!,
      config: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}config'],
      )!,
    );
  }

  @override
  $McpServersTable createAlias(String alias) {
    return $McpServersTable(attachedDatabase, alias);
  }
}

class DbMcpServers extends DataClass implements Insertable<DbMcpServers> {
  final String id;
  final String name;
  final int revision;
  final String config;
  const DbMcpServers({
    required this.id,
    required this.name,
    required this.revision,
    required this.config,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['revision'] = Variable<int>(revision);
    map['config'] = Variable<String>(config);
    return map;
  }

  McpServersCompanion toCompanion(bool nullToAbsent) {
    return McpServersCompanion(
      id: Value(id),
      name: Value(name),
      revision: Value(revision),
      config: Value(config),
    );
  }

  factory DbMcpServers.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DbMcpServers(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      revision: serializer.fromJson<int>(json['revision']),
      config: serializer.fromJson<String>(json['config']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'revision': serializer.toJson<int>(revision),
      'config': serializer.toJson<String>(config),
    };
  }

  DbMcpServers copyWith({
    String? id,
    String? name,
    int? revision,
    String? config,
  }) => DbMcpServers(
    id: id ?? this.id,
    name: name ?? this.name,
    revision: revision ?? this.revision,
    config: config ?? this.config,
  );
  DbMcpServers copyWithCompanion(McpServersCompanion data) {
    return DbMcpServers(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      revision: data.revision.present ? data.revision.value : this.revision,
      config: data.config.present ? data.config.value : this.config,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DbMcpServers(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('revision: $revision, ')
          ..write('config: $config')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, revision, config);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DbMcpServers &&
          other.id == this.id &&
          other.name == this.name &&
          other.revision == this.revision &&
          other.config == this.config);
}

class McpServersCompanion extends UpdateCompanion<DbMcpServers> {
  final Value<String> id;
  final Value<String> name;
  final Value<int> revision;
  final Value<String> config;
  final Value<int> rowid;
  const McpServersCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.revision = const Value.absent(),
    this.config = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  McpServersCompanion.insert({
    required String id,
    required String name,
    required int revision,
    required String config,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       revision = Value(revision),
       config = Value(config);
  static Insertable<DbMcpServers> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<int>? revision,
    Expression<String>? config,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (revision != null) 'revision': revision,
      if (config != null) 'config': config,
      if (rowid != null) 'rowid': rowid,
    });
  }

  McpServersCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<int>? revision,
    Value<String>? config,
    Value<int>? rowid,
  }) {
    return McpServersCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      revision: revision ?? this.revision,
      config: config ?? this.config,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (revision.present) {
      map['revision'] = Variable<int>(revision.value);
    }
    if (config.present) {
      map['config'] = Variable<String>(config.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('McpServersCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('revision: $revision, ')
          ..write('config: $config, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ConversationsTable extends Conversations
    with TableInfo<$ConversationsTable, DbConversations> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ConversationsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _assistantIdMeta = const VerificationMeta(
    'assistantId',
  );
  @override
  late final GeneratedColumn<String> assistantId = GeneratedColumn<String>(
    'assistant_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES assistants (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    title,
    assistantId,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'conversations';
  @override
  VerificationContext validateIntegrity(
    Insertable<DbConversations> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('assistant_id')) {
      context.handle(
        _assistantIdMeta,
        assistantId.isAcceptableOrUnknown(
          data['assistant_id']!,
          _assistantIdMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  DbConversations map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DbConversations(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      assistantId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}assistant_id'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $ConversationsTable createAlias(String alias) {
    return $ConversationsTable(attachedDatabase, alias);
  }
}

class DbConversations extends DataClass implements Insertable<DbConversations> {
  final String id;
  final String title;
  final String? assistantId;
  final int createdAt;
  final int updatedAt;
  const DbConversations({
    required this.id,
    required this.title,
    this.assistantId,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['title'] = Variable<String>(title);
    if (!nullToAbsent || assistantId != null) {
      map['assistant_id'] = Variable<String>(assistantId);
    }
    map['created_at'] = Variable<int>(createdAt);
    map['updated_at'] = Variable<int>(updatedAt);
    return map;
  }

  ConversationsCompanion toCompanion(bool nullToAbsent) {
    return ConversationsCompanion(
      id: Value(id),
      title: Value(title),
      assistantId: assistantId == null && nullToAbsent
          ? const Value.absent()
          : Value(assistantId),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory DbConversations.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DbConversations(
      id: serializer.fromJson<String>(json['id']),
      title: serializer.fromJson<String>(json['title']),
      assistantId: serializer.fromJson<String?>(json['assistantId']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'title': serializer.toJson<String>(title),
      'assistantId': serializer.toJson<String?>(assistantId),
      'createdAt': serializer.toJson<int>(createdAt),
      'updatedAt': serializer.toJson<int>(updatedAt),
    };
  }

  DbConversations copyWith({
    String? id,
    String? title,
    Value<String?> assistantId = const Value.absent(),
    int? createdAt,
    int? updatedAt,
  }) => DbConversations(
    id: id ?? this.id,
    title: title ?? this.title,
    assistantId: assistantId.present ? assistantId.value : this.assistantId,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  DbConversations copyWithCompanion(ConversationsCompanion data) {
    return DbConversations(
      id: data.id.present ? data.id.value : this.id,
      title: data.title.present ? data.title.value : this.title,
      assistantId: data.assistantId.present
          ? data.assistantId.value
          : this.assistantId,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DbConversations(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('assistantId: $assistantId, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, title, assistantId, createdAt, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DbConversations &&
          other.id == this.id &&
          other.title == this.title &&
          other.assistantId == this.assistantId &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class ConversationsCompanion extends UpdateCompanion<DbConversations> {
  final Value<String> id;
  final Value<String> title;
  final Value<String?> assistantId;
  final Value<int> createdAt;
  final Value<int> updatedAt;
  final Value<int> rowid;
  const ConversationsCompanion({
    this.id = const Value.absent(),
    this.title = const Value.absent(),
    this.assistantId = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ConversationsCompanion.insert({
    required String id,
    required String title,
    this.assistantId = const Value.absent(),
    required int createdAt,
    required int updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       title = Value(title),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<DbConversations> custom({
    Expression<String>? id,
    Expression<String>? title,
    Expression<String>? assistantId,
    Expression<int>? createdAt,
    Expression<int>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (title != null) 'title': title,
      if (assistantId != null) 'assistant_id': assistantId,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ConversationsCompanion copyWith({
    Value<String>? id,
    Value<String>? title,
    Value<String?>? assistantId,
    Value<int>? createdAt,
    Value<int>? updatedAt,
    Value<int>? rowid,
  }) {
    return ConversationsCompanion(
      id: id ?? this.id,
      title: title ?? this.title,
      assistantId: assistantId ?? this.assistantId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (assistantId.present) {
      map['assistant_id'] = Variable<String>(assistantId.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ConversationsCompanion(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('assistantId: $assistantId, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $MessagesTable extends Messages
    with TableInfo<$MessagesTable, DbMessages> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MessagesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _conversationIdMeta = const VerificationMeta(
    'conversationId',
  );
  @override
  late final GeneratedColumn<String> conversationId = GeneratedColumn<String>(
    'conversation_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES conversations (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _positionMeta = const VerificationMeta(
    'position',
  );
  @override
  late final GeneratedColumn<int> position = GeneratedColumn<int>(
    'position',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _roleMeta = const VerificationMeta('role');
  @override
  late final GeneratedColumn<String> role = GeneratedColumn<String>(
    'role',
    aliasedName,
    false,
    check: () => role.isIn(['user', 'assistant']),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, conversationId, position, role];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'messages';
  @override
  VerificationContext validateIntegrity(
    Insertable<DbMessages> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('conversation_id')) {
      context.handle(
        _conversationIdMeta,
        conversationId.isAcceptableOrUnknown(
          data['conversation_id']!,
          _conversationIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_conversationIdMeta);
    }
    if (data.containsKey('position')) {
      context.handle(
        _positionMeta,
        position.isAcceptableOrUnknown(data['position']!, _positionMeta),
      );
    } else if (isInserting) {
      context.missing(_positionMeta);
    }
    if (data.containsKey('role')) {
      context.handle(
        _roleMeta,
        role.isAcceptableOrUnknown(data['role']!, _roleMeta),
      );
    } else if (isInserting) {
      context.missing(_roleMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  DbMessages map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DbMessages(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      conversationId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}conversation_id'],
      )!,
      position: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}position'],
      )!,
      role: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}role'],
      )!,
    );
  }

  @override
  $MessagesTable createAlias(String alias) {
    return $MessagesTable(attachedDatabase, alias);
  }
}

class DbMessages extends DataClass implements Insertable<DbMessages> {
  final String id;
  final String conversationId;
  final int position;
  final String role;
  const DbMessages({
    required this.id,
    required this.conversationId,
    required this.position,
    required this.role,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['conversation_id'] = Variable<String>(conversationId);
    map['position'] = Variable<int>(position);
    map['role'] = Variable<String>(role);
    return map;
  }

  MessagesCompanion toCompanion(bool nullToAbsent) {
    return MessagesCompanion(
      id: Value(id),
      conversationId: Value(conversationId),
      position: Value(position),
      role: Value(role),
    );
  }

  factory DbMessages.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DbMessages(
      id: serializer.fromJson<String>(json['id']),
      conversationId: serializer.fromJson<String>(json['conversationId']),
      position: serializer.fromJson<int>(json['position']),
      role: serializer.fromJson<String>(json['role']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'conversationId': serializer.toJson<String>(conversationId),
      'position': serializer.toJson<int>(position),
      'role': serializer.toJson<String>(role),
    };
  }

  DbMessages copyWith({
    String? id,
    String? conversationId,
    int? position,
    String? role,
  }) => DbMessages(
    id: id ?? this.id,
    conversationId: conversationId ?? this.conversationId,
    position: position ?? this.position,
    role: role ?? this.role,
  );
  DbMessages copyWithCompanion(MessagesCompanion data) {
    return DbMessages(
      id: data.id.present ? data.id.value : this.id,
      conversationId: data.conversationId.present
          ? data.conversationId.value
          : this.conversationId,
      position: data.position.present ? data.position.value : this.position,
      role: data.role.present ? data.role.value : this.role,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DbMessages(')
          ..write('id: $id, ')
          ..write('conversationId: $conversationId, ')
          ..write('position: $position, ')
          ..write('role: $role')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, conversationId, position, role);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DbMessages &&
          other.id == this.id &&
          other.conversationId == this.conversationId &&
          other.position == this.position &&
          other.role == this.role);
}

class MessagesCompanion extends UpdateCompanion<DbMessages> {
  final Value<String> id;
  final Value<String> conversationId;
  final Value<int> position;
  final Value<String> role;
  final Value<int> rowid;
  const MessagesCompanion({
    this.id = const Value.absent(),
    this.conversationId = const Value.absent(),
    this.position = const Value.absent(),
    this.role = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MessagesCompanion.insert({
    required String id,
    required String conversationId,
    required int position,
    required String role,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       conversationId = Value(conversationId),
       position = Value(position),
       role = Value(role);
  static Insertable<DbMessages> custom({
    Expression<String>? id,
    Expression<String>? conversationId,
    Expression<int>? position,
    Expression<String>? role,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (conversationId != null) 'conversation_id': conversationId,
      if (position != null) 'position': position,
      if (role != null) 'role': role,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MessagesCompanion copyWith({
    Value<String>? id,
    Value<String>? conversationId,
    Value<int>? position,
    Value<String>? role,
    Value<int>? rowid,
  }) {
    return MessagesCompanion(
      id: id ?? this.id,
      conversationId: conversationId ?? this.conversationId,
      position: position ?? this.position,
      role: role ?? this.role,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (conversationId.present) {
      map['conversation_id'] = Variable<String>(conversationId.value);
    }
    if (position.present) {
      map['position'] = Variable<int>(position.value);
    }
    if (role.present) {
      map['role'] = Variable<String>(role.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MessagesCompanion(')
          ..write('id: $id, ')
          ..write('conversationId: $conversationId, ')
          ..write('position: $position, ')
          ..write('role: $role, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $GenerationRunsTable extends GenerationRuns
    with TableInfo<$GenerationRunsTable, DbGenerationRuns> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $GenerationRunsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _conversationIdMeta = const VerificationMeta(
    'conversationId',
  );
  @override
  late final GeneratedColumn<String> conversationId = GeneratedColumn<String>(
    'conversation_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES conversations (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _stateMeta = const VerificationMeta('state');
  @override
  late final GeneratedColumn<String> state = GeneratedColumn<String>(
    'state',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _snapshotMeta = const VerificationMeta(
    'snapshot',
  );
  @override
  late final GeneratedColumn<String> snapshot = GeneratedColumn<String>(
    'snapshot',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _checkpointMeta = const VerificationMeta(
    'checkpoint',
  );
  @override
  late final GeneratedColumn<String> checkpoint = GeneratedColumn<String>(
    'checkpoint',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    conversationId,
    state,
    snapshot,
    checkpoint,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'generation_runs';
  @override
  VerificationContext validateIntegrity(
    Insertable<DbGenerationRuns> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('conversation_id')) {
      context.handle(
        _conversationIdMeta,
        conversationId.isAcceptableOrUnknown(
          data['conversation_id']!,
          _conversationIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_conversationIdMeta);
    }
    if (data.containsKey('state')) {
      context.handle(
        _stateMeta,
        state.isAcceptableOrUnknown(data['state']!, _stateMeta),
      );
    } else if (isInserting) {
      context.missing(_stateMeta);
    }
    if (data.containsKey('snapshot')) {
      context.handle(
        _snapshotMeta,
        snapshot.isAcceptableOrUnknown(data['snapshot']!, _snapshotMeta),
      );
    } else if (isInserting) {
      context.missing(_snapshotMeta);
    }
    if (data.containsKey('checkpoint')) {
      context.handle(
        _checkpointMeta,
        checkpoint.isAcceptableOrUnknown(data['checkpoint']!, _checkpointMeta),
      );
    } else if (isInserting) {
      context.missing(_checkpointMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  DbGenerationRuns map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DbGenerationRuns(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      conversationId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}conversation_id'],
      )!,
      state: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}state'],
      )!,
      snapshot: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}snapshot'],
      )!,
      checkpoint: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}checkpoint'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $GenerationRunsTable createAlias(String alias) {
    return $GenerationRunsTable(attachedDatabase, alias);
  }
}

class DbGenerationRuns extends DataClass
    implements Insertable<DbGenerationRuns> {
  final String id;
  final String conversationId;
  final String state;
  final String snapshot;
  final String checkpoint;
  final int updatedAt;
  const DbGenerationRuns({
    required this.id,
    required this.conversationId,
    required this.state,
    required this.snapshot,
    required this.checkpoint,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['conversation_id'] = Variable<String>(conversationId);
    map['state'] = Variable<String>(state);
    map['snapshot'] = Variable<String>(snapshot);
    map['checkpoint'] = Variable<String>(checkpoint);
    map['updated_at'] = Variable<int>(updatedAt);
    return map;
  }

  GenerationRunsCompanion toCompanion(bool nullToAbsent) {
    return GenerationRunsCompanion(
      id: Value(id),
      conversationId: Value(conversationId),
      state: Value(state),
      snapshot: Value(snapshot),
      checkpoint: Value(checkpoint),
      updatedAt: Value(updatedAt),
    );
  }

  factory DbGenerationRuns.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DbGenerationRuns(
      id: serializer.fromJson<String>(json['id']),
      conversationId: serializer.fromJson<String>(json['conversationId']),
      state: serializer.fromJson<String>(json['state']),
      snapshot: serializer.fromJson<String>(json['snapshot']),
      checkpoint: serializer.fromJson<String>(json['checkpoint']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'conversationId': serializer.toJson<String>(conversationId),
      'state': serializer.toJson<String>(state),
      'snapshot': serializer.toJson<String>(snapshot),
      'checkpoint': serializer.toJson<String>(checkpoint),
      'updatedAt': serializer.toJson<int>(updatedAt),
    };
  }

  DbGenerationRuns copyWith({
    String? id,
    String? conversationId,
    String? state,
    String? snapshot,
    String? checkpoint,
    int? updatedAt,
  }) => DbGenerationRuns(
    id: id ?? this.id,
    conversationId: conversationId ?? this.conversationId,
    state: state ?? this.state,
    snapshot: snapshot ?? this.snapshot,
    checkpoint: checkpoint ?? this.checkpoint,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  DbGenerationRuns copyWithCompanion(GenerationRunsCompanion data) {
    return DbGenerationRuns(
      id: data.id.present ? data.id.value : this.id,
      conversationId: data.conversationId.present
          ? data.conversationId.value
          : this.conversationId,
      state: data.state.present ? data.state.value : this.state,
      snapshot: data.snapshot.present ? data.snapshot.value : this.snapshot,
      checkpoint: data.checkpoint.present
          ? data.checkpoint.value
          : this.checkpoint,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DbGenerationRuns(')
          ..write('id: $id, ')
          ..write('conversationId: $conversationId, ')
          ..write('state: $state, ')
          ..write('snapshot: $snapshot, ')
          ..write('checkpoint: $checkpoint, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, conversationId, state, snapshot, checkpoint, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DbGenerationRuns &&
          other.id == this.id &&
          other.conversationId == this.conversationId &&
          other.state == this.state &&
          other.snapshot == this.snapshot &&
          other.checkpoint == this.checkpoint &&
          other.updatedAt == this.updatedAt);
}

class GenerationRunsCompanion extends UpdateCompanion<DbGenerationRuns> {
  final Value<String> id;
  final Value<String> conversationId;
  final Value<String> state;
  final Value<String> snapshot;
  final Value<String> checkpoint;
  final Value<int> updatedAt;
  final Value<int> rowid;
  const GenerationRunsCompanion({
    this.id = const Value.absent(),
    this.conversationId = const Value.absent(),
    this.state = const Value.absent(),
    this.snapshot = const Value.absent(),
    this.checkpoint = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  GenerationRunsCompanion.insert({
    required String id,
    required String conversationId,
    required String state,
    required String snapshot,
    required String checkpoint,
    required int updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       conversationId = Value(conversationId),
       state = Value(state),
       snapshot = Value(snapshot),
       checkpoint = Value(checkpoint),
       updatedAt = Value(updatedAt);
  static Insertable<DbGenerationRuns> custom({
    Expression<String>? id,
    Expression<String>? conversationId,
    Expression<String>? state,
    Expression<String>? snapshot,
    Expression<String>? checkpoint,
    Expression<int>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (conversationId != null) 'conversation_id': conversationId,
      if (state != null) 'state': state,
      if (snapshot != null) 'snapshot': snapshot,
      if (checkpoint != null) 'checkpoint': checkpoint,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  GenerationRunsCompanion copyWith({
    Value<String>? id,
    Value<String>? conversationId,
    Value<String>? state,
    Value<String>? snapshot,
    Value<String>? checkpoint,
    Value<int>? updatedAt,
    Value<int>? rowid,
  }) {
    return GenerationRunsCompanion(
      id: id ?? this.id,
      conversationId: conversationId ?? this.conversationId,
      state: state ?? this.state,
      snapshot: snapshot ?? this.snapshot,
      checkpoint: checkpoint ?? this.checkpoint,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (conversationId.present) {
      map['conversation_id'] = Variable<String>(conversationId.value);
    }
    if (state.present) {
      map['state'] = Variable<String>(state.value);
    }
    if (snapshot.present) {
      map['snapshot'] = Variable<String>(snapshot.value);
    }
    if (checkpoint.present) {
      map['checkpoint'] = Variable<String>(checkpoint.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('GenerationRunsCompanion(')
          ..write('id: $id, ')
          ..write('conversationId: $conversationId, ')
          ..write('state: $state, ')
          ..write('snapshot: $snapshot, ')
          ..write('checkpoint: $checkpoint, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $MessageRevisionsTable extends MessageRevisions
    with TableInfo<$MessageRevisionsTable, DbMessageRevisions> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MessageRevisionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _messageIdMeta = const VerificationMeta(
    'messageId',
  );
  @override
  late final GeneratedColumn<String> messageId = GeneratedColumn<String>(
    'message_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES messages (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _positionMeta = const VerificationMeta(
    'position',
  );
  @override
  late final GeneratedColumn<int> position = GeneratedColumn<int>(
    'position',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _runIdMeta = const VerificationMeta('runId');
  @override
  late final GeneratedColumn<String> runId = GeneratedColumn<String>(
    'run_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES generation_runs (id) DEFERRABLE INITIALLY DEFERRED',
    ),
  );
  static const VerificationMeta _isDraftMeta = const VerificationMeta(
    'isDraft',
  );
  @override
  late final GeneratedColumn<int> isDraft = GeneratedColumn<int>(
    'is_draft',
    aliasedName,
    false,
    check: () => isDraft.isIn([0, 1]),
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _isSelectedMeta = const VerificationMeta(
    'isSelected',
  );
  @override
  late final GeneratedColumn<int> isSelected = GeneratedColumn<int>(
    'is_selected',
    aliasedName,
    false,
    check: () => isSelected.isIn([0, 1]),
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _contentMeta = const VerificationMeta(
    'content',
  );
  @override
  late final GeneratedColumn<String> content = GeneratedColumn<String>(
    'content',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _reasoningContentMeta = const VerificationMeta(
    'reasoningContent',
  );
  @override
  late final GeneratedColumn<String> reasoningContent = GeneratedColumn<String>(
    'reasoning_content',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _modelNameMeta = const VerificationMeta(
    'modelName',
  );
  @override
  late final GeneratedColumn<String> modelName = GeneratedColumn<String>(
    'model_name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _authorMeta = const VerificationMeta('author');
  @override
  late final GeneratedColumn<String> author = GeneratedColumn<String>(
    'author',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _generationMetricsMeta = const VerificationMeta(
    'generationMetrics',
  );
  @override
  late final GeneratedColumn<String> generationMetrics =
      GeneratedColumn<String>(
        'generation_metrics',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    messageId,
    position,
    runId,
    isDraft,
    isSelected,
    createdAt,
    content,
    reasoningContent,
    modelName,
    author,
    generationMetrics,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'message_revisions';
  @override
  VerificationContext validateIntegrity(
    Insertable<DbMessageRevisions> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('message_id')) {
      context.handle(
        _messageIdMeta,
        messageId.isAcceptableOrUnknown(data['message_id']!, _messageIdMeta),
      );
    } else if (isInserting) {
      context.missing(_messageIdMeta);
    }
    if (data.containsKey('position')) {
      context.handle(
        _positionMeta,
        position.isAcceptableOrUnknown(data['position']!, _positionMeta),
      );
    } else if (isInserting) {
      context.missing(_positionMeta);
    }
    if (data.containsKey('run_id')) {
      context.handle(
        _runIdMeta,
        runId.isAcceptableOrUnknown(data['run_id']!, _runIdMeta),
      );
    }
    if (data.containsKey('is_draft')) {
      context.handle(
        _isDraftMeta,
        isDraft.isAcceptableOrUnknown(data['is_draft']!, _isDraftMeta),
      );
    }
    if (data.containsKey('is_selected')) {
      context.handle(
        _isSelectedMeta,
        isSelected.isAcceptableOrUnknown(data['is_selected']!, _isSelectedMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('content')) {
      context.handle(
        _contentMeta,
        content.isAcceptableOrUnknown(data['content']!, _contentMeta),
      );
    } else if (isInserting) {
      context.missing(_contentMeta);
    }
    if (data.containsKey('reasoning_content')) {
      context.handle(
        _reasoningContentMeta,
        reasoningContent.isAcceptableOrUnknown(
          data['reasoning_content']!,
          _reasoningContentMeta,
        ),
      );
    }
    if (data.containsKey('model_name')) {
      context.handle(
        _modelNameMeta,
        modelName.isAcceptableOrUnknown(data['model_name']!, _modelNameMeta),
      );
    }
    if (data.containsKey('author')) {
      context.handle(
        _authorMeta,
        author.isAcceptableOrUnknown(data['author']!, _authorMeta),
      );
    }
    if (data.containsKey('generation_metrics')) {
      context.handle(
        _generationMetricsMeta,
        generationMetrics.isAcceptableOrUnknown(
          data['generation_metrics']!,
          _generationMetricsMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  DbMessageRevisions map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DbMessageRevisions(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      messageId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}message_id'],
      )!,
      position: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}position'],
      )!,
      runId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}run_id'],
      ),
      isDraft: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}is_draft'],
      )!,
      isSelected: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}is_selected'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
      content: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}content'],
      )!,
      reasoningContent: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}reasoning_content'],
      ),
      modelName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}model_name'],
      ),
      author: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}author'],
      ),
      generationMetrics: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}generation_metrics'],
      ),
    );
  }

  @override
  $MessageRevisionsTable createAlias(String alias) {
    return $MessageRevisionsTable(attachedDatabase, alias);
  }
}

class DbMessageRevisions extends DataClass
    implements Insertable<DbMessageRevisions> {
  final String id;
  final String messageId;
  final int position;
  final String? runId;
  final int isDraft;
  final int isSelected;
  final int createdAt;
  final String content;
  final String? reasoningContent;
  final String? modelName;
  final String? author;
  final String? generationMetrics;
  const DbMessageRevisions({
    required this.id,
    required this.messageId,
    required this.position,
    this.runId,
    required this.isDraft,
    required this.isSelected,
    required this.createdAt,
    required this.content,
    this.reasoningContent,
    this.modelName,
    this.author,
    this.generationMetrics,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['message_id'] = Variable<String>(messageId);
    map['position'] = Variable<int>(position);
    if (!nullToAbsent || runId != null) {
      map['run_id'] = Variable<String>(runId);
    }
    map['is_draft'] = Variable<int>(isDraft);
    map['is_selected'] = Variable<int>(isSelected);
    map['created_at'] = Variable<int>(createdAt);
    map['content'] = Variable<String>(content);
    if (!nullToAbsent || reasoningContent != null) {
      map['reasoning_content'] = Variable<String>(reasoningContent);
    }
    if (!nullToAbsent || modelName != null) {
      map['model_name'] = Variable<String>(modelName);
    }
    if (!nullToAbsent || author != null) {
      map['author'] = Variable<String>(author);
    }
    if (!nullToAbsent || generationMetrics != null) {
      map['generation_metrics'] = Variable<String>(generationMetrics);
    }
    return map;
  }

  MessageRevisionsCompanion toCompanion(bool nullToAbsent) {
    return MessageRevisionsCompanion(
      id: Value(id),
      messageId: Value(messageId),
      position: Value(position),
      runId: runId == null && nullToAbsent
          ? const Value.absent()
          : Value(runId),
      isDraft: Value(isDraft),
      isSelected: Value(isSelected),
      createdAt: Value(createdAt),
      content: Value(content),
      reasoningContent: reasoningContent == null && nullToAbsent
          ? const Value.absent()
          : Value(reasoningContent),
      modelName: modelName == null && nullToAbsent
          ? const Value.absent()
          : Value(modelName),
      author: author == null && nullToAbsent
          ? const Value.absent()
          : Value(author),
      generationMetrics: generationMetrics == null && nullToAbsent
          ? const Value.absent()
          : Value(generationMetrics),
    );
  }

  factory DbMessageRevisions.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DbMessageRevisions(
      id: serializer.fromJson<String>(json['id']),
      messageId: serializer.fromJson<String>(json['messageId']),
      position: serializer.fromJson<int>(json['position']),
      runId: serializer.fromJson<String?>(json['runId']),
      isDraft: serializer.fromJson<int>(json['isDraft']),
      isSelected: serializer.fromJson<int>(json['isSelected']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
      content: serializer.fromJson<String>(json['content']),
      reasoningContent: serializer.fromJson<String?>(json['reasoningContent']),
      modelName: serializer.fromJson<String?>(json['modelName']),
      author: serializer.fromJson<String?>(json['author']),
      generationMetrics: serializer.fromJson<String?>(
        json['generationMetrics'],
      ),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'messageId': serializer.toJson<String>(messageId),
      'position': serializer.toJson<int>(position),
      'runId': serializer.toJson<String?>(runId),
      'isDraft': serializer.toJson<int>(isDraft),
      'isSelected': serializer.toJson<int>(isSelected),
      'createdAt': serializer.toJson<int>(createdAt),
      'content': serializer.toJson<String>(content),
      'reasoningContent': serializer.toJson<String?>(reasoningContent),
      'modelName': serializer.toJson<String?>(modelName),
      'author': serializer.toJson<String?>(author),
      'generationMetrics': serializer.toJson<String?>(generationMetrics),
    };
  }

  DbMessageRevisions copyWith({
    String? id,
    String? messageId,
    int? position,
    Value<String?> runId = const Value.absent(),
    int? isDraft,
    int? isSelected,
    int? createdAt,
    String? content,
    Value<String?> reasoningContent = const Value.absent(),
    Value<String?> modelName = const Value.absent(),
    Value<String?> author = const Value.absent(),
    Value<String?> generationMetrics = const Value.absent(),
  }) => DbMessageRevisions(
    id: id ?? this.id,
    messageId: messageId ?? this.messageId,
    position: position ?? this.position,
    runId: runId.present ? runId.value : this.runId,
    isDraft: isDraft ?? this.isDraft,
    isSelected: isSelected ?? this.isSelected,
    createdAt: createdAt ?? this.createdAt,
    content: content ?? this.content,
    reasoningContent: reasoningContent.present
        ? reasoningContent.value
        : this.reasoningContent,
    modelName: modelName.present ? modelName.value : this.modelName,
    author: author.present ? author.value : this.author,
    generationMetrics: generationMetrics.present
        ? generationMetrics.value
        : this.generationMetrics,
  );
  DbMessageRevisions copyWithCompanion(MessageRevisionsCompanion data) {
    return DbMessageRevisions(
      id: data.id.present ? data.id.value : this.id,
      messageId: data.messageId.present ? data.messageId.value : this.messageId,
      position: data.position.present ? data.position.value : this.position,
      runId: data.runId.present ? data.runId.value : this.runId,
      isDraft: data.isDraft.present ? data.isDraft.value : this.isDraft,
      isSelected: data.isSelected.present
          ? data.isSelected.value
          : this.isSelected,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      content: data.content.present ? data.content.value : this.content,
      reasoningContent: data.reasoningContent.present
          ? data.reasoningContent.value
          : this.reasoningContent,
      modelName: data.modelName.present ? data.modelName.value : this.modelName,
      author: data.author.present ? data.author.value : this.author,
      generationMetrics: data.generationMetrics.present
          ? data.generationMetrics.value
          : this.generationMetrics,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DbMessageRevisions(')
          ..write('id: $id, ')
          ..write('messageId: $messageId, ')
          ..write('position: $position, ')
          ..write('runId: $runId, ')
          ..write('isDraft: $isDraft, ')
          ..write('isSelected: $isSelected, ')
          ..write('createdAt: $createdAt, ')
          ..write('content: $content, ')
          ..write('reasoningContent: $reasoningContent, ')
          ..write('modelName: $modelName, ')
          ..write('author: $author, ')
          ..write('generationMetrics: $generationMetrics')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    messageId,
    position,
    runId,
    isDraft,
    isSelected,
    createdAt,
    content,
    reasoningContent,
    modelName,
    author,
    generationMetrics,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DbMessageRevisions &&
          other.id == this.id &&
          other.messageId == this.messageId &&
          other.position == this.position &&
          other.runId == this.runId &&
          other.isDraft == this.isDraft &&
          other.isSelected == this.isSelected &&
          other.createdAt == this.createdAt &&
          other.content == this.content &&
          other.reasoningContent == this.reasoningContent &&
          other.modelName == this.modelName &&
          other.author == this.author &&
          other.generationMetrics == this.generationMetrics);
}

class MessageRevisionsCompanion extends UpdateCompanion<DbMessageRevisions> {
  final Value<String> id;
  final Value<String> messageId;
  final Value<int> position;
  final Value<String?> runId;
  final Value<int> isDraft;
  final Value<int> isSelected;
  final Value<int> createdAt;
  final Value<String> content;
  final Value<String?> reasoningContent;
  final Value<String?> modelName;
  final Value<String?> author;
  final Value<String?> generationMetrics;
  final Value<int> rowid;
  const MessageRevisionsCompanion({
    this.id = const Value.absent(),
    this.messageId = const Value.absent(),
    this.position = const Value.absent(),
    this.runId = const Value.absent(),
    this.isDraft = const Value.absent(),
    this.isSelected = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.content = const Value.absent(),
    this.reasoningContent = const Value.absent(),
    this.modelName = const Value.absent(),
    this.author = const Value.absent(),
    this.generationMetrics = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MessageRevisionsCompanion.insert({
    required String id,
    required String messageId,
    required int position,
    this.runId = const Value.absent(),
    this.isDraft = const Value.absent(),
    this.isSelected = const Value.absent(),
    required int createdAt,
    required String content,
    this.reasoningContent = const Value.absent(),
    this.modelName = const Value.absent(),
    this.author = const Value.absent(),
    this.generationMetrics = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       messageId = Value(messageId),
       position = Value(position),
       createdAt = Value(createdAt),
       content = Value(content);
  static Insertable<DbMessageRevisions> custom({
    Expression<String>? id,
    Expression<String>? messageId,
    Expression<int>? position,
    Expression<String>? runId,
    Expression<int>? isDraft,
    Expression<int>? isSelected,
    Expression<int>? createdAt,
    Expression<String>? content,
    Expression<String>? reasoningContent,
    Expression<String>? modelName,
    Expression<String>? author,
    Expression<String>? generationMetrics,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (messageId != null) 'message_id': messageId,
      if (position != null) 'position': position,
      if (runId != null) 'run_id': runId,
      if (isDraft != null) 'is_draft': isDraft,
      if (isSelected != null) 'is_selected': isSelected,
      if (createdAt != null) 'created_at': createdAt,
      if (content != null) 'content': content,
      if (reasoningContent != null) 'reasoning_content': reasoningContent,
      if (modelName != null) 'model_name': modelName,
      if (author != null) 'author': author,
      if (generationMetrics != null) 'generation_metrics': generationMetrics,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MessageRevisionsCompanion copyWith({
    Value<String>? id,
    Value<String>? messageId,
    Value<int>? position,
    Value<String?>? runId,
    Value<int>? isDraft,
    Value<int>? isSelected,
    Value<int>? createdAt,
    Value<String>? content,
    Value<String?>? reasoningContent,
    Value<String?>? modelName,
    Value<String?>? author,
    Value<String?>? generationMetrics,
    Value<int>? rowid,
  }) {
    return MessageRevisionsCompanion(
      id: id ?? this.id,
      messageId: messageId ?? this.messageId,
      position: position ?? this.position,
      runId: runId ?? this.runId,
      isDraft: isDraft ?? this.isDraft,
      isSelected: isSelected ?? this.isSelected,
      createdAt: createdAt ?? this.createdAt,
      content: content ?? this.content,
      reasoningContent: reasoningContent ?? this.reasoningContent,
      modelName: modelName ?? this.modelName,
      author: author ?? this.author,
      generationMetrics: generationMetrics ?? this.generationMetrics,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (messageId.present) {
      map['message_id'] = Variable<String>(messageId.value);
    }
    if (position.present) {
      map['position'] = Variable<int>(position.value);
    }
    if (runId.present) {
      map['run_id'] = Variable<String>(runId.value);
    }
    if (isDraft.present) {
      map['is_draft'] = Variable<int>(isDraft.value);
    }
    if (isSelected.present) {
      map['is_selected'] = Variable<int>(isSelected.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (content.present) {
      map['content'] = Variable<String>(content.value);
    }
    if (reasoningContent.present) {
      map['reasoning_content'] = Variable<String>(reasoningContent.value);
    }
    if (modelName.present) {
      map['model_name'] = Variable<String>(modelName.value);
    }
    if (author.present) {
      map['author'] = Variable<String>(author.value);
    }
    if (generationMetrics.present) {
      map['generation_metrics'] = Variable<String>(generationMetrics.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MessageRevisionsCompanion(')
          ..write('id: $id, ')
          ..write('messageId: $messageId, ')
          ..write('position: $position, ')
          ..write('runId: $runId, ')
          ..write('isDraft: $isDraft, ')
          ..write('isSelected: $isSelected, ')
          ..write('createdAt: $createdAt, ')
          ..write('content: $content, ')
          ..write('reasoningContent: $reasoningContent, ')
          ..write('modelName: $modelName, ')
          ..write('author: $author, ')
          ..write('generationMetrics: $generationMetrics, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $RevisionAttachmentsTable extends RevisionAttachments
    with TableInfo<$RevisionAttachmentsTable, DbRevisionAttachments> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RevisionAttachmentsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _revisionIdMeta = const VerificationMeta(
    'revisionId',
  );
  @override
  late final GeneratedColumn<String> revisionId = GeneratedColumn<String>(
    'revision_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES message_revisions (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _positionMeta = const VerificationMeta(
    'position',
  );
  @override
  late final GeneratedColumn<int> position = GeneratedColumn<int>(
    'position',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _pathMeta = const VerificationMeta('path');
  @override
  late final GeneratedColumn<String> path = GeneratedColumn<String>(
    'path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [revisionId, position, path];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'revision_attachments';
  @override
  VerificationContext validateIntegrity(
    Insertable<DbRevisionAttachments> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('revision_id')) {
      context.handle(
        _revisionIdMeta,
        revisionId.isAcceptableOrUnknown(data['revision_id']!, _revisionIdMeta),
      );
    } else if (isInserting) {
      context.missing(_revisionIdMeta);
    }
    if (data.containsKey('position')) {
      context.handle(
        _positionMeta,
        position.isAcceptableOrUnknown(data['position']!, _positionMeta),
      );
    } else if (isInserting) {
      context.missing(_positionMeta);
    }
    if (data.containsKey('path')) {
      context.handle(
        _pathMeta,
        path.isAcceptableOrUnknown(data['path']!, _pathMeta),
      );
    } else if (isInserting) {
      context.missing(_pathMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {revisionId, position};
  @override
  DbRevisionAttachments map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DbRevisionAttachments(
      revisionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}revision_id'],
      )!,
      position: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}position'],
      )!,
      path: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}path'],
      )!,
    );
  }

  @override
  $RevisionAttachmentsTable createAlias(String alias) {
    return $RevisionAttachmentsTable(attachedDatabase, alias);
  }
}

class DbRevisionAttachments extends DataClass
    implements Insertable<DbRevisionAttachments> {
  final String revisionId;
  final int position;
  final String path;
  const DbRevisionAttachments({
    required this.revisionId,
    required this.position,
    required this.path,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['revision_id'] = Variable<String>(revisionId);
    map['position'] = Variable<int>(position);
    map['path'] = Variable<String>(path);
    return map;
  }

  RevisionAttachmentsCompanion toCompanion(bool nullToAbsent) {
    return RevisionAttachmentsCompanion(
      revisionId: Value(revisionId),
      position: Value(position),
      path: Value(path),
    );
  }

  factory DbRevisionAttachments.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DbRevisionAttachments(
      revisionId: serializer.fromJson<String>(json['revisionId']),
      position: serializer.fromJson<int>(json['position']),
      path: serializer.fromJson<String>(json['path']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'revisionId': serializer.toJson<String>(revisionId),
      'position': serializer.toJson<int>(position),
      'path': serializer.toJson<String>(path),
    };
  }

  DbRevisionAttachments copyWith({
    String? revisionId,
    int? position,
    String? path,
  }) => DbRevisionAttachments(
    revisionId: revisionId ?? this.revisionId,
    position: position ?? this.position,
    path: path ?? this.path,
  );
  DbRevisionAttachments copyWithCompanion(RevisionAttachmentsCompanion data) {
    return DbRevisionAttachments(
      revisionId: data.revisionId.present
          ? data.revisionId.value
          : this.revisionId,
      position: data.position.present ? data.position.value : this.position,
      path: data.path.present ? data.path.value : this.path,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DbRevisionAttachments(')
          ..write('revisionId: $revisionId, ')
          ..write('position: $position, ')
          ..write('path: $path')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(revisionId, position, path);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DbRevisionAttachments &&
          other.revisionId == this.revisionId &&
          other.position == this.position &&
          other.path == this.path);
}

class RevisionAttachmentsCompanion
    extends UpdateCompanion<DbRevisionAttachments> {
  final Value<String> revisionId;
  final Value<int> position;
  final Value<String> path;
  final Value<int> rowid;
  const RevisionAttachmentsCompanion({
    this.revisionId = const Value.absent(),
    this.position = const Value.absent(),
    this.path = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  RevisionAttachmentsCompanion.insert({
    required String revisionId,
    required int position,
    required String path,
    this.rowid = const Value.absent(),
  }) : revisionId = Value(revisionId),
       position = Value(position),
       path = Value(path);
  static Insertable<DbRevisionAttachments> custom({
    Expression<String>? revisionId,
    Expression<int>? position,
    Expression<String>? path,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (revisionId != null) 'revision_id': revisionId,
      if (position != null) 'position': position,
      if (path != null) 'path': path,
      if (rowid != null) 'rowid': rowid,
    });
  }

  RevisionAttachmentsCompanion copyWith({
    Value<String>? revisionId,
    Value<int>? position,
    Value<String>? path,
    Value<int>? rowid,
  }) {
    return RevisionAttachmentsCompanion(
      revisionId: revisionId ?? this.revisionId,
      position: position ?? this.position,
      path: path ?? this.path,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (revisionId.present) {
      map['revision_id'] = Variable<String>(revisionId.value);
    }
    if (position.present) {
      map['position'] = Variable<int>(position.value);
    }
    if (path.present) {
      map['path'] = Variable<String>(path.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RevisionAttachmentsCompanion(')
          ..write('revisionId: $revisionId, ')
          ..write('position: $position, ')
          ..write('path: $path, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ToolInvocationsTable extends ToolInvocations
    with TableInfo<$ToolInvocationsTable, DbToolInvocations> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ToolInvocationsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _runIdMeta = const VerificationMeta('runId');
  @override
  late final GeneratedColumn<String> runId = GeneratedColumn<String>(
    'run_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES generation_runs (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _callIdMeta = const VerificationMeta('callId');
  @override
  late final GeneratedColumn<String> callId = GeneratedColumn<String>(
    'call_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
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
  static const VerificationMeta _stateMeta = const VerificationMeta('state');
  @override
  late final GeneratedColumn<String> state = GeneratedColumn<String>(
    'state',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _payloadMeta = const VerificationMeta(
    'payload',
  );
  @override
  late final GeneratedColumn<String> payload = GeneratedColumn<String>(
    'payload',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    runId,
    callId,
    name,
    state,
    payload,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'tool_invocations';
  @override
  VerificationContext validateIntegrity(
    Insertable<DbToolInvocations> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('run_id')) {
      context.handle(
        _runIdMeta,
        runId.isAcceptableOrUnknown(data['run_id']!, _runIdMeta),
      );
    } else if (isInserting) {
      context.missing(_runIdMeta);
    }
    if (data.containsKey('call_id')) {
      context.handle(
        _callIdMeta,
        callId.isAcceptableOrUnknown(data['call_id']!, _callIdMeta),
      );
    } else if (isInserting) {
      context.missing(_callIdMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('state')) {
      context.handle(
        _stateMeta,
        state.isAcceptableOrUnknown(data['state']!, _stateMeta),
      );
    } else if (isInserting) {
      context.missing(_stateMeta);
    }
    if (data.containsKey('payload')) {
      context.handle(
        _payloadMeta,
        payload.isAcceptableOrUnknown(data['payload']!, _payloadMeta),
      );
    } else if (isInserting) {
      context.missing(_payloadMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  DbToolInvocations map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DbToolInvocations(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      runId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}run_id'],
      )!,
      callId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}call_id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      state: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}state'],
      )!,
      payload: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $ToolInvocationsTable createAlias(String alias) {
    return $ToolInvocationsTable(attachedDatabase, alias);
  }
}

class DbToolInvocations extends DataClass
    implements Insertable<DbToolInvocations> {
  final String id;
  final String runId;
  final String callId;
  final String name;
  final String state;
  final String payload;
  final int createdAt;
  const DbToolInvocations({
    required this.id,
    required this.runId,
    required this.callId,
    required this.name,
    required this.state,
    required this.payload,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['run_id'] = Variable<String>(runId);
    map['call_id'] = Variable<String>(callId);
    map['name'] = Variable<String>(name);
    map['state'] = Variable<String>(state);
    map['payload'] = Variable<String>(payload);
    map['created_at'] = Variable<int>(createdAt);
    return map;
  }

  ToolInvocationsCompanion toCompanion(bool nullToAbsent) {
    return ToolInvocationsCompanion(
      id: Value(id),
      runId: Value(runId),
      callId: Value(callId),
      name: Value(name),
      state: Value(state),
      payload: Value(payload),
      createdAt: Value(createdAt),
    );
  }

  factory DbToolInvocations.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DbToolInvocations(
      id: serializer.fromJson<String>(json['id']),
      runId: serializer.fromJson<String>(json['runId']),
      callId: serializer.fromJson<String>(json['callId']),
      name: serializer.fromJson<String>(json['name']),
      state: serializer.fromJson<String>(json['state']),
      payload: serializer.fromJson<String>(json['payload']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'runId': serializer.toJson<String>(runId),
      'callId': serializer.toJson<String>(callId),
      'name': serializer.toJson<String>(name),
      'state': serializer.toJson<String>(state),
      'payload': serializer.toJson<String>(payload),
      'createdAt': serializer.toJson<int>(createdAt),
    };
  }

  DbToolInvocations copyWith({
    String? id,
    String? runId,
    String? callId,
    String? name,
    String? state,
    String? payload,
    int? createdAt,
  }) => DbToolInvocations(
    id: id ?? this.id,
    runId: runId ?? this.runId,
    callId: callId ?? this.callId,
    name: name ?? this.name,
    state: state ?? this.state,
    payload: payload ?? this.payload,
    createdAt: createdAt ?? this.createdAt,
  );
  DbToolInvocations copyWithCompanion(ToolInvocationsCompanion data) {
    return DbToolInvocations(
      id: data.id.present ? data.id.value : this.id,
      runId: data.runId.present ? data.runId.value : this.runId,
      callId: data.callId.present ? data.callId.value : this.callId,
      name: data.name.present ? data.name.value : this.name,
      state: data.state.present ? data.state.value : this.state,
      payload: data.payload.present ? data.payload.value : this.payload,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DbToolInvocations(')
          ..write('id: $id, ')
          ..write('runId: $runId, ')
          ..write('callId: $callId, ')
          ..write('name: $name, ')
          ..write('state: $state, ')
          ..write('payload: $payload, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, runId, callId, name, state, payload, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DbToolInvocations &&
          other.id == this.id &&
          other.runId == this.runId &&
          other.callId == this.callId &&
          other.name == this.name &&
          other.state == this.state &&
          other.payload == this.payload &&
          other.createdAt == this.createdAt);
}

class ToolInvocationsCompanion extends UpdateCompanion<DbToolInvocations> {
  final Value<String> id;
  final Value<String> runId;
  final Value<String> callId;
  final Value<String> name;
  final Value<String> state;
  final Value<String> payload;
  final Value<int> createdAt;
  final Value<int> rowid;
  const ToolInvocationsCompanion({
    this.id = const Value.absent(),
    this.runId = const Value.absent(),
    this.callId = const Value.absent(),
    this.name = const Value.absent(),
    this.state = const Value.absent(),
    this.payload = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ToolInvocationsCompanion.insert({
    required String id,
    required String runId,
    required String callId,
    required String name,
    required String state,
    required String payload,
    required int createdAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       runId = Value(runId),
       callId = Value(callId),
       name = Value(name),
       state = Value(state),
       payload = Value(payload),
       createdAt = Value(createdAt);
  static Insertable<DbToolInvocations> custom({
    Expression<String>? id,
    Expression<String>? runId,
    Expression<String>? callId,
    Expression<String>? name,
    Expression<String>? state,
    Expression<String>? payload,
    Expression<int>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (runId != null) 'run_id': runId,
      if (callId != null) 'call_id': callId,
      if (name != null) 'name': name,
      if (state != null) 'state': state,
      if (payload != null) 'payload': payload,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ToolInvocationsCompanion copyWith({
    Value<String>? id,
    Value<String>? runId,
    Value<String>? callId,
    Value<String>? name,
    Value<String>? state,
    Value<String>? payload,
    Value<int>? createdAt,
    Value<int>? rowid,
  }) {
    return ToolInvocationsCompanion(
      id: id ?? this.id,
      runId: runId ?? this.runId,
      callId: callId ?? this.callId,
      name: name ?? this.name,
      state: state ?? this.state,
      payload: payload ?? this.payload,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (runId.present) {
      map['run_id'] = Variable<String>(runId.value);
    }
    if (callId.present) {
      map['call_id'] = Variable<String>(callId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (state.present) {
      map['state'] = Variable<String>(state.value);
    }
    if (payload.present) {
      map['payload'] = Variable<String>(payload.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ToolInvocationsCompanion(')
          ..write('id: $id, ')
          ..write('runId: $runId, ')
          ..write('callId: $callId, ')
          ..write('name: $name, ')
          ..write('state: $state, ')
          ..write('payload: $payload, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ChatDraftsTable extends ChatDrafts
    with TableInfo<$ChatDraftsTable, DbChatDrafts> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ChatDraftsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _conversationIdMeta = const VerificationMeta(
    'conversationId',
  );
  @override
  late final GeneratedColumn<String> conversationId = GeneratedColumn<String>(
    'conversation_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'UNIQUE REFERENCES conversations (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _assistantIdMeta = const VerificationMeta(
    'assistantId',
  );
  @override
  late final GeneratedColumn<String> assistantId = GeneratedColumn<String>(
    'assistant_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'UNIQUE REFERENCES assistants (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _contentMeta = const VerificationMeta(
    'content',
  );
  @override
  late final GeneratedColumn<String> content = GeneratedColumn<String>(
    'content',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    key,
    conversationId,
    assistantId,
    content,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'chat_drafts';
  @override
  VerificationContext validateIntegrity(
    Insertable<DbChatDrafts> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('conversation_id')) {
      context.handle(
        _conversationIdMeta,
        conversationId.isAcceptableOrUnknown(
          data['conversation_id']!,
          _conversationIdMeta,
        ),
      );
    }
    if (data.containsKey('assistant_id')) {
      context.handle(
        _assistantIdMeta,
        assistantId.isAcceptableOrUnknown(
          data['assistant_id']!,
          _assistantIdMeta,
        ),
      );
    }
    if (data.containsKey('content')) {
      context.handle(
        _contentMeta,
        content.isAcceptableOrUnknown(data['content']!, _contentMeta),
      );
    } else if (isInserting) {
      context.missing(_contentMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  DbChatDrafts map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DbChatDrafts(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      conversationId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}conversation_id'],
      ),
      assistantId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}assistant_id'],
      ),
      content: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}content'],
      )!,
    );
  }

  @override
  $ChatDraftsTable createAlias(String alias) {
    return $ChatDraftsTable(attachedDatabase, alias);
  }
}

class DbChatDrafts extends DataClass implements Insertable<DbChatDrafts> {
  final String key;
  final String? conversationId;
  final String? assistantId;
  final String content;
  const DbChatDrafts({
    required this.key,
    this.conversationId,
    this.assistantId,
    required this.content,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    if (!nullToAbsent || conversationId != null) {
      map['conversation_id'] = Variable<String>(conversationId);
    }
    if (!nullToAbsent || assistantId != null) {
      map['assistant_id'] = Variable<String>(assistantId);
    }
    map['content'] = Variable<String>(content);
    return map;
  }

  ChatDraftsCompanion toCompanion(bool nullToAbsent) {
    return ChatDraftsCompanion(
      key: Value(key),
      conversationId: conversationId == null && nullToAbsent
          ? const Value.absent()
          : Value(conversationId),
      assistantId: assistantId == null && nullToAbsent
          ? const Value.absent()
          : Value(assistantId),
      content: Value(content),
    );
  }

  factory DbChatDrafts.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DbChatDrafts(
      key: serializer.fromJson<String>(json['key']),
      conversationId: serializer.fromJson<String?>(json['conversationId']),
      assistantId: serializer.fromJson<String?>(json['assistantId']),
      content: serializer.fromJson<String>(json['content']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'conversationId': serializer.toJson<String?>(conversationId),
      'assistantId': serializer.toJson<String?>(assistantId),
      'content': serializer.toJson<String>(content),
    };
  }

  DbChatDrafts copyWith({
    String? key,
    Value<String?> conversationId = const Value.absent(),
    Value<String?> assistantId = const Value.absent(),
    String? content,
  }) => DbChatDrafts(
    key: key ?? this.key,
    conversationId: conversationId.present
        ? conversationId.value
        : this.conversationId,
    assistantId: assistantId.present ? assistantId.value : this.assistantId,
    content: content ?? this.content,
  );
  DbChatDrafts copyWithCompanion(ChatDraftsCompanion data) {
    return DbChatDrafts(
      key: data.key.present ? data.key.value : this.key,
      conversationId: data.conversationId.present
          ? data.conversationId.value
          : this.conversationId,
      assistantId: data.assistantId.present
          ? data.assistantId.value
          : this.assistantId,
      content: data.content.present ? data.content.value : this.content,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DbChatDrafts(')
          ..write('key: $key, ')
          ..write('conversationId: $conversationId, ')
          ..write('assistantId: $assistantId, ')
          ..write('content: $content')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, conversationId, assistantId, content);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DbChatDrafts &&
          other.key == this.key &&
          other.conversationId == this.conversationId &&
          other.assistantId == this.assistantId &&
          other.content == this.content);
}

class ChatDraftsCompanion extends UpdateCompanion<DbChatDrafts> {
  final Value<String> key;
  final Value<String?> conversationId;
  final Value<String?> assistantId;
  final Value<String> content;
  final Value<int> rowid;
  const ChatDraftsCompanion({
    this.key = const Value.absent(),
    this.conversationId = const Value.absent(),
    this.assistantId = const Value.absent(),
    this.content = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ChatDraftsCompanion.insert({
    required String key,
    this.conversationId = const Value.absent(),
    this.assistantId = const Value.absent(),
    required String content,
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       content = Value(content);
  static Insertable<DbChatDrafts> custom({
    Expression<String>? key,
    Expression<String>? conversationId,
    Expression<String>? assistantId,
    Expression<String>? content,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (conversationId != null) 'conversation_id': conversationId,
      if (assistantId != null) 'assistant_id': assistantId,
      if (content != null) 'content': content,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ChatDraftsCompanion copyWith({
    Value<String>? key,
    Value<String?>? conversationId,
    Value<String?>? assistantId,
    Value<String>? content,
    Value<int>? rowid,
  }) {
    return ChatDraftsCompanion(
      key: key ?? this.key,
      conversationId: conversationId ?? this.conversationId,
      assistantId: assistantId ?? this.assistantId,
      content: content ?? this.content,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (conversationId.present) {
      map['conversation_id'] = Variable<String>(conversationId.value);
    }
    if (assistantId.present) {
      map['assistant_id'] = Variable<String>(assistantId.value);
    }
    if (content.present) {
      map['content'] = Variable<String>(content.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ChatDraftsCompanion(')
          ..write('key: $key, ')
          ..write('conversationId: $conversationId, ')
          ..write('assistantId: $assistantId, ')
          ..write('content: $content, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ModelAssetsTable extends ModelAssets
    with TableInfo<$ModelAssetsTable, DbModelAssets> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ModelAssetsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _engineMeta = const VerificationMeta('engine');
  @override
  late final GeneratedColumn<String> engine = GeneratedColumn<String>(
    'engine',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _runtimeIdMeta = const VerificationMeta(
    'runtimeId',
  );
  @override
  late final GeneratedColumn<String> runtimeId = GeneratedColumn<String>(
    'runtime_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _storageOwnerMeta = const VerificationMeta(
    'storageOwner',
  );
  @override
  late final GeneratedColumn<String> storageOwner = GeneratedColumn<String>(
    'storage_owner',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _pathMeta = const VerificationMeta('path');
  @override
  late final GeneratedColumn<String> path = GeneratedColumn<String>(
    'path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
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
  static const VerificationMeta _revisionMeta = const VerificationMeta(
    'revision',
  );
  @override
  late final GeneratedColumn<String> revision = GeneratedColumn<String>(
    'revision',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _stateMeta = const VerificationMeta('state');
  @override
  late final GeneratedColumn<String> state = GeneratedColumn<String>(
    'state',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _manifestMeta = const VerificationMeta(
    'manifest',
  );
  @override
  late final GeneratedColumn<String> manifest = GeneratedColumn<String>(
    'manifest',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    kind,
    engine,
    runtimeId,
    storageOwner,
    path,
    name,
    revision,
    state,
    manifest,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'model_assets';
  @override
  VerificationContext validateIntegrity(
    Insertable<DbModelAssets> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('engine')) {
      context.handle(
        _engineMeta,
        engine.isAcceptableOrUnknown(data['engine']!, _engineMeta),
      );
    } else if (isInserting) {
      context.missing(_engineMeta);
    }
    if (data.containsKey('runtime_id')) {
      context.handle(
        _runtimeIdMeta,
        runtimeId.isAcceptableOrUnknown(data['runtime_id']!, _runtimeIdMeta),
      );
    } else if (isInserting) {
      context.missing(_runtimeIdMeta);
    }
    if (data.containsKey('storage_owner')) {
      context.handle(
        _storageOwnerMeta,
        storageOwner.isAcceptableOrUnknown(
          data['storage_owner']!,
          _storageOwnerMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_storageOwnerMeta);
    }
    if (data.containsKey('path')) {
      context.handle(
        _pathMeta,
        path.isAcceptableOrUnknown(data['path']!, _pathMeta),
      );
    } else if (isInserting) {
      context.missing(_pathMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('revision')) {
      context.handle(
        _revisionMeta,
        revision.isAcceptableOrUnknown(data['revision']!, _revisionMeta),
      );
    } else if (isInserting) {
      context.missing(_revisionMeta);
    }
    if (data.containsKey('state')) {
      context.handle(
        _stateMeta,
        state.isAcceptableOrUnknown(data['state']!, _stateMeta),
      );
    } else if (isInserting) {
      context.missing(_stateMeta);
    }
    if (data.containsKey('manifest')) {
      context.handle(
        _manifestMeta,
        manifest.isAcceptableOrUnknown(data['manifest']!, _manifestMeta),
      );
    } else if (isInserting) {
      context.missing(_manifestMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  DbModelAssets map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DbModelAssets(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      engine: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}engine'],
      )!,
      runtimeId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}runtime_id'],
      )!,
      storageOwner: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}storage_owner'],
      )!,
      path: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}path'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      revision: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}revision'],
      )!,
      state: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}state'],
      )!,
      manifest: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}manifest'],
      )!,
    );
  }

  @override
  $ModelAssetsTable createAlias(String alias) {
    return $ModelAssetsTable(attachedDatabase, alias);
  }
}

class DbModelAssets extends DataClass implements Insertable<DbModelAssets> {
  final String id;
  final String kind;
  final String engine;
  final String runtimeId;
  final String storageOwner;
  final String path;
  final String name;
  final String revision;
  final String state;
  final String manifest;
  const DbModelAssets({
    required this.id,
    required this.kind,
    required this.engine,
    required this.runtimeId,
    required this.storageOwner,
    required this.path,
    required this.name,
    required this.revision,
    required this.state,
    required this.manifest,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['kind'] = Variable<String>(kind);
    map['engine'] = Variable<String>(engine);
    map['runtime_id'] = Variable<String>(runtimeId);
    map['storage_owner'] = Variable<String>(storageOwner);
    map['path'] = Variable<String>(path);
    map['name'] = Variable<String>(name);
    map['revision'] = Variable<String>(revision);
    map['state'] = Variable<String>(state);
    map['manifest'] = Variable<String>(manifest);
    return map;
  }

  ModelAssetsCompanion toCompanion(bool nullToAbsent) {
    return ModelAssetsCompanion(
      id: Value(id),
      kind: Value(kind),
      engine: Value(engine),
      runtimeId: Value(runtimeId),
      storageOwner: Value(storageOwner),
      path: Value(path),
      name: Value(name),
      revision: Value(revision),
      state: Value(state),
      manifest: Value(manifest),
    );
  }

  factory DbModelAssets.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DbModelAssets(
      id: serializer.fromJson<String>(json['id']),
      kind: serializer.fromJson<String>(json['kind']),
      engine: serializer.fromJson<String>(json['engine']),
      runtimeId: serializer.fromJson<String>(json['runtimeId']),
      storageOwner: serializer.fromJson<String>(json['storageOwner']),
      path: serializer.fromJson<String>(json['path']),
      name: serializer.fromJson<String>(json['name']),
      revision: serializer.fromJson<String>(json['revision']),
      state: serializer.fromJson<String>(json['state']),
      manifest: serializer.fromJson<String>(json['manifest']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'kind': serializer.toJson<String>(kind),
      'engine': serializer.toJson<String>(engine),
      'runtimeId': serializer.toJson<String>(runtimeId),
      'storageOwner': serializer.toJson<String>(storageOwner),
      'path': serializer.toJson<String>(path),
      'name': serializer.toJson<String>(name),
      'revision': serializer.toJson<String>(revision),
      'state': serializer.toJson<String>(state),
      'manifest': serializer.toJson<String>(manifest),
    };
  }

  DbModelAssets copyWith({
    String? id,
    String? kind,
    String? engine,
    String? runtimeId,
    String? storageOwner,
    String? path,
    String? name,
    String? revision,
    String? state,
    String? manifest,
  }) => DbModelAssets(
    id: id ?? this.id,
    kind: kind ?? this.kind,
    engine: engine ?? this.engine,
    runtimeId: runtimeId ?? this.runtimeId,
    storageOwner: storageOwner ?? this.storageOwner,
    path: path ?? this.path,
    name: name ?? this.name,
    revision: revision ?? this.revision,
    state: state ?? this.state,
    manifest: manifest ?? this.manifest,
  );
  DbModelAssets copyWithCompanion(ModelAssetsCompanion data) {
    return DbModelAssets(
      id: data.id.present ? data.id.value : this.id,
      kind: data.kind.present ? data.kind.value : this.kind,
      engine: data.engine.present ? data.engine.value : this.engine,
      runtimeId: data.runtimeId.present ? data.runtimeId.value : this.runtimeId,
      storageOwner: data.storageOwner.present
          ? data.storageOwner.value
          : this.storageOwner,
      path: data.path.present ? data.path.value : this.path,
      name: data.name.present ? data.name.value : this.name,
      revision: data.revision.present ? data.revision.value : this.revision,
      state: data.state.present ? data.state.value : this.state,
      manifest: data.manifest.present ? data.manifest.value : this.manifest,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DbModelAssets(')
          ..write('id: $id, ')
          ..write('kind: $kind, ')
          ..write('engine: $engine, ')
          ..write('runtimeId: $runtimeId, ')
          ..write('storageOwner: $storageOwner, ')
          ..write('path: $path, ')
          ..write('name: $name, ')
          ..write('revision: $revision, ')
          ..write('state: $state, ')
          ..write('manifest: $manifest')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    kind,
    engine,
    runtimeId,
    storageOwner,
    path,
    name,
    revision,
    state,
    manifest,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DbModelAssets &&
          other.id == this.id &&
          other.kind == this.kind &&
          other.engine == this.engine &&
          other.runtimeId == this.runtimeId &&
          other.storageOwner == this.storageOwner &&
          other.path == this.path &&
          other.name == this.name &&
          other.revision == this.revision &&
          other.state == this.state &&
          other.manifest == this.manifest);
}

class ModelAssetsCompanion extends UpdateCompanion<DbModelAssets> {
  final Value<String> id;
  final Value<String> kind;
  final Value<String> engine;
  final Value<String> runtimeId;
  final Value<String> storageOwner;
  final Value<String> path;
  final Value<String> name;
  final Value<String> revision;
  final Value<String> state;
  final Value<String> manifest;
  final Value<int> rowid;
  const ModelAssetsCompanion({
    this.id = const Value.absent(),
    this.kind = const Value.absent(),
    this.engine = const Value.absent(),
    this.runtimeId = const Value.absent(),
    this.storageOwner = const Value.absent(),
    this.path = const Value.absent(),
    this.name = const Value.absent(),
    this.revision = const Value.absent(),
    this.state = const Value.absent(),
    this.manifest = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ModelAssetsCompanion.insert({
    required String id,
    required String kind,
    required String engine,
    required String runtimeId,
    required String storageOwner,
    required String path,
    required String name,
    required String revision,
    required String state,
    required String manifest,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       kind = Value(kind),
       engine = Value(engine),
       runtimeId = Value(runtimeId),
       storageOwner = Value(storageOwner),
       path = Value(path),
       name = Value(name),
       revision = Value(revision),
       state = Value(state),
       manifest = Value(manifest);
  static Insertable<DbModelAssets> custom({
    Expression<String>? id,
    Expression<String>? kind,
    Expression<String>? engine,
    Expression<String>? runtimeId,
    Expression<String>? storageOwner,
    Expression<String>? path,
    Expression<String>? name,
    Expression<String>? revision,
    Expression<String>? state,
    Expression<String>? manifest,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (kind != null) 'kind': kind,
      if (engine != null) 'engine': engine,
      if (runtimeId != null) 'runtime_id': runtimeId,
      if (storageOwner != null) 'storage_owner': storageOwner,
      if (path != null) 'path': path,
      if (name != null) 'name': name,
      if (revision != null) 'revision': revision,
      if (state != null) 'state': state,
      if (manifest != null) 'manifest': manifest,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ModelAssetsCompanion copyWith({
    Value<String>? id,
    Value<String>? kind,
    Value<String>? engine,
    Value<String>? runtimeId,
    Value<String>? storageOwner,
    Value<String>? path,
    Value<String>? name,
    Value<String>? revision,
    Value<String>? state,
    Value<String>? manifest,
    Value<int>? rowid,
  }) {
    return ModelAssetsCompanion(
      id: id ?? this.id,
      kind: kind ?? this.kind,
      engine: engine ?? this.engine,
      runtimeId: runtimeId ?? this.runtimeId,
      storageOwner: storageOwner ?? this.storageOwner,
      path: path ?? this.path,
      name: name ?? this.name,
      revision: revision ?? this.revision,
      state: state ?? this.state,
      manifest: manifest ?? this.manifest,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (engine.present) {
      map['engine'] = Variable<String>(engine.value);
    }
    if (runtimeId.present) {
      map['runtime_id'] = Variable<String>(runtimeId.value);
    }
    if (storageOwner.present) {
      map['storage_owner'] = Variable<String>(storageOwner.value);
    }
    if (path.present) {
      map['path'] = Variable<String>(path.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (revision.present) {
      map['revision'] = Variable<String>(revision.value);
    }
    if (state.present) {
      map['state'] = Variable<String>(state.value);
    }
    if (manifest.present) {
      map['manifest'] = Variable<String>(manifest.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ModelAssetsCompanion(')
          ..write('id: $id, ')
          ..write('kind: $kind, ')
          ..write('engine: $engine, ')
          ..write('runtimeId: $runtimeId, ')
          ..write('storageOwner: $storageOwner, ')
          ..write('path: $path, ')
          ..write('name: $name, ')
          ..write('revision: $revision, ')
          ..write('state: $state, ')
          ..write('manifest: $manifest, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SpeechJobsTable extends SpeechJobs
    with TableInfo<$SpeechJobsTable, DbSpeechJobs> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SpeechJobsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _stateMeta = const VerificationMeta('state');
  @override
  late final GeneratedColumn<String> state = GeneratedColumn<String>(
    'state',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _assetIdMeta = const VerificationMeta(
    'assetId',
  );
  @override
  late final GeneratedColumn<String> assetId = GeneratedColumn<String>(
    'asset_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _voiceIdMeta = const VerificationMeta(
    'voiceId',
  );
  @override
  late final GeneratedColumn<String> voiceId = GeneratedColumn<String>(
    'voice_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _payloadMeta = const VerificationMeta(
    'payload',
  );
  @override
  late final GeneratedColumn<String> payload = GeneratedColumn<String>(
    'payload',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    state,
    assetId,
    voiceId,
    createdAt,
    payload,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'speech_jobs';
  @override
  VerificationContext validateIntegrity(
    Insertable<DbSpeechJobs> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('state')) {
      context.handle(
        _stateMeta,
        state.isAcceptableOrUnknown(data['state']!, _stateMeta),
      );
    } else if (isInserting) {
      context.missing(_stateMeta);
    }
    if (data.containsKey('asset_id')) {
      context.handle(
        _assetIdMeta,
        assetId.isAcceptableOrUnknown(data['asset_id']!, _assetIdMeta),
      );
    } else if (isInserting) {
      context.missing(_assetIdMeta);
    }
    if (data.containsKey('voice_id')) {
      context.handle(
        _voiceIdMeta,
        voiceId.isAcceptableOrUnknown(data['voice_id']!, _voiceIdMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('payload')) {
      context.handle(
        _payloadMeta,
        payload.isAcceptableOrUnknown(data['payload']!, _payloadMeta),
      );
    } else if (isInserting) {
      context.missing(_payloadMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  DbSpeechJobs map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DbSpeechJobs(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      state: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}state'],
      )!,
      assetId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}asset_id'],
      )!,
      voiceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}voice_id'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
      payload: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload'],
      )!,
    );
  }

  @override
  $SpeechJobsTable createAlias(String alias) {
    return $SpeechJobsTable(attachedDatabase, alias);
  }
}

class DbSpeechJobs extends DataClass implements Insertable<DbSpeechJobs> {
  final String id;
  final String state;
  final String assetId;
  final String? voiceId;
  final int createdAt;
  final String payload;
  const DbSpeechJobs({
    required this.id,
    required this.state,
    required this.assetId,
    this.voiceId,
    required this.createdAt,
    required this.payload,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['state'] = Variable<String>(state);
    map['asset_id'] = Variable<String>(assetId);
    if (!nullToAbsent || voiceId != null) {
      map['voice_id'] = Variable<String>(voiceId);
    }
    map['created_at'] = Variable<int>(createdAt);
    map['payload'] = Variable<String>(payload);
    return map;
  }

  SpeechJobsCompanion toCompanion(bool nullToAbsent) {
    return SpeechJobsCompanion(
      id: Value(id),
      state: Value(state),
      assetId: Value(assetId),
      voiceId: voiceId == null && nullToAbsent
          ? const Value.absent()
          : Value(voiceId),
      createdAt: Value(createdAt),
      payload: Value(payload),
    );
  }

  factory DbSpeechJobs.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DbSpeechJobs(
      id: serializer.fromJson<String>(json['id']),
      state: serializer.fromJson<String>(json['state']),
      assetId: serializer.fromJson<String>(json['assetId']),
      voiceId: serializer.fromJson<String?>(json['voiceId']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
      payload: serializer.fromJson<String>(json['payload']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'state': serializer.toJson<String>(state),
      'assetId': serializer.toJson<String>(assetId),
      'voiceId': serializer.toJson<String?>(voiceId),
      'createdAt': serializer.toJson<int>(createdAt),
      'payload': serializer.toJson<String>(payload),
    };
  }

  DbSpeechJobs copyWith({
    String? id,
    String? state,
    String? assetId,
    Value<String?> voiceId = const Value.absent(),
    int? createdAt,
    String? payload,
  }) => DbSpeechJobs(
    id: id ?? this.id,
    state: state ?? this.state,
    assetId: assetId ?? this.assetId,
    voiceId: voiceId.present ? voiceId.value : this.voiceId,
    createdAt: createdAt ?? this.createdAt,
    payload: payload ?? this.payload,
  );
  DbSpeechJobs copyWithCompanion(SpeechJobsCompanion data) {
    return DbSpeechJobs(
      id: data.id.present ? data.id.value : this.id,
      state: data.state.present ? data.state.value : this.state,
      assetId: data.assetId.present ? data.assetId.value : this.assetId,
      voiceId: data.voiceId.present ? data.voiceId.value : this.voiceId,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      payload: data.payload.present ? data.payload.value : this.payload,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DbSpeechJobs(')
          ..write('id: $id, ')
          ..write('state: $state, ')
          ..write('assetId: $assetId, ')
          ..write('voiceId: $voiceId, ')
          ..write('createdAt: $createdAt, ')
          ..write('payload: $payload')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, state, assetId, voiceId, createdAt, payload);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DbSpeechJobs &&
          other.id == this.id &&
          other.state == this.state &&
          other.assetId == this.assetId &&
          other.voiceId == this.voiceId &&
          other.createdAt == this.createdAt &&
          other.payload == this.payload);
}

class SpeechJobsCompanion extends UpdateCompanion<DbSpeechJobs> {
  final Value<String> id;
  final Value<String> state;
  final Value<String> assetId;
  final Value<String?> voiceId;
  final Value<int> createdAt;
  final Value<String> payload;
  final Value<int> rowid;
  const SpeechJobsCompanion({
    this.id = const Value.absent(),
    this.state = const Value.absent(),
    this.assetId = const Value.absent(),
    this.voiceId = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.payload = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SpeechJobsCompanion.insert({
    required String id,
    required String state,
    required String assetId,
    this.voiceId = const Value.absent(),
    required int createdAt,
    required String payload,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       state = Value(state),
       assetId = Value(assetId),
       createdAt = Value(createdAt),
       payload = Value(payload);
  static Insertable<DbSpeechJobs> custom({
    Expression<String>? id,
    Expression<String>? state,
    Expression<String>? assetId,
    Expression<String>? voiceId,
    Expression<int>? createdAt,
    Expression<String>? payload,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (state != null) 'state': state,
      if (assetId != null) 'asset_id': assetId,
      if (voiceId != null) 'voice_id': voiceId,
      if (createdAt != null) 'created_at': createdAt,
      if (payload != null) 'payload': payload,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SpeechJobsCompanion copyWith({
    Value<String>? id,
    Value<String>? state,
    Value<String>? assetId,
    Value<String?>? voiceId,
    Value<int>? createdAt,
    Value<String>? payload,
    Value<int>? rowid,
  }) {
    return SpeechJobsCompanion(
      id: id ?? this.id,
      state: state ?? this.state,
      assetId: assetId ?? this.assetId,
      voiceId: voiceId ?? this.voiceId,
      createdAt: createdAt ?? this.createdAt,
      payload: payload ?? this.payload,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (state.present) {
      map['state'] = Variable<String>(state.value);
    }
    if (assetId.present) {
      map['asset_id'] = Variable<String>(assetId.value);
    }
    if (voiceId.present) {
      map['voice_id'] = Variable<String>(voiceId.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (payload.present) {
      map['payload'] = Variable<String>(payload.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SpeechJobsCompanion(')
          ..write('id: $id, ')
          ..write('state: $state, ')
          ..write('assetId: $assetId, ')
          ..write('voiceId: $voiceId, ')
          ..write('createdAt: $createdAt, ')
          ..write('payload: $payload, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $VoiceProfilesTable extends VoiceProfiles
    with TableInfo<$VoiceProfilesTable, DbVoiceProfiles> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $VoiceProfilesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
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
  static const VerificationMeta _assetIdMeta = const VerificationMeta(
    'assetId',
  );
  @override
  late final GeneratedColumn<String> assetId = GeneratedColumn<String>(
    'asset_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _payloadMeta = const VerificationMeta(
    'payload',
  );
  @override
  late final GeneratedColumn<String> payload = GeneratedColumn<String>(
    'payload',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, name, assetId, payload];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'voice_profiles';
  @override
  VerificationContext validateIntegrity(
    Insertable<DbVoiceProfiles> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('asset_id')) {
      context.handle(
        _assetIdMeta,
        assetId.isAcceptableOrUnknown(data['asset_id']!, _assetIdMeta),
      );
    } else if (isInserting) {
      context.missing(_assetIdMeta);
    }
    if (data.containsKey('payload')) {
      context.handle(
        _payloadMeta,
        payload.isAcceptableOrUnknown(data['payload']!, _payloadMeta),
      );
    } else if (isInserting) {
      context.missing(_payloadMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  DbVoiceProfiles map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DbVoiceProfiles(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      assetId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}asset_id'],
      )!,
      payload: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload'],
      )!,
    );
  }

  @override
  $VoiceProfilesTable createAlias(String alias) {
    return $VoiceProfilesTable(attachedDatabase, alias);
  }
}

class DbVoiceProfiles extends DataClass implements Insertable<DbVoiceProfiles> {
  final String id;
  final String name;
  final String assetId;
  final String payload;
  const DbVoiceProfiles({
    required this.id,
    required this.name,
    required this.assetId,
    required this.payload,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['asset_id'] = Variable<String>(assetId);
    map['payload'] = Variable<String>(payload);
    return map;
  }

  VoiceProfilesCompanion toCompanion(bool nullToAbsent) {
    return VoiceProfilesCompanion(
      id: Value(id),
      name: Value(name),
      assetId: Value(assetId),
      payload: Value(payload),
    );
  }

  factory DbVoiceProfiles.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DbVoiceProfiles(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      assetId: serializer.fromJson<String>(json['assetId']),
      payload: serializer.fromJson<String>(json['payload']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'assetId': serializer.toJson<String>(assetId),
      'payload': serializer.toJson<String>(payload),
    };
  }

  DbVoiceProfiles copyWith({
    String? id,
    String? name,
    String? assetId,
    String? payload,
  }) => DbVoiceProfiles(
    id: id ?? this.id,
    name: name ?? this.name,
    assetId: assetId ?? this.assetId,
    payload: payload ?? this.payload,
  );
  DbVoiceProfiles copyWithCompanion(VoiceProfilesCompanion data) {
    return DbVoiceProfiles(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      assetId: data.assetId.present ? data.assetId.value : this.assetId,
      payload: data.payload.present ? data.payload.value : this.payload,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DbVoiceProfiles(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('assetId: $assetId, ')
          ..write('payload: $payload')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, assetId, payload);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DbVoiceProfiles &&
          other.id == this.id &&
          other.name == this.name &&
          other.assetId == this.assetId &&
          other.payload == this.payload);
}

class VoiceProfilesCompanion extends UpdateCompanion<DbVoiceProfiles> {
  final Value<String> id;
  final Value<String> name;
  final Value<String> assetId;
  final Value<String> payload;
  final Value<int> rowid;
  const VoiceProfilesCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.assetId = const Value.absent(),
    this.payload = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  VoiceProfilesCompanion.insert({
    required String id,
    required String name,
    required String assetId,
    required String payload,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       assetId = Value(assetId),
       payload = Value(payload);
  static Insertable<DbVoiceProfiles> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? assetId,
    Expression<String>? payload,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (assetId != null) 'asset_id': assetId,
      if (payload != null) 'payload': payload,
      if (rowid != null) 'rowid': rowid,
    });
  }

  VoiceProfilesCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<String>? assetId,
    Value<String>? payload,
    Value<int>? rowid,
  }) {
    return VoiceProfilesCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      assetId: assetId ?? this.assetId,
      payload: payload ?? this.payload,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (assetId.present) {
      map['asset_id'] = Variable<String>(assetId.value);
    }
    if (payload.present) {
      map['payload'] = Variable<String>(payload.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('VoiceProfilesCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('assetId: $assetId, ')
          ..write('payload: $payload, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $DownloadTasksTable extends DownloadTasks
    with TableInfo<$DownloadTasksTable, DbDownloadTasks> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DownloadTasksTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _payloadMeta = const VerificationMeta(
    'payload',
  );
  @override
  late final GeneratedColumn<String> payload = GeneratedColumn<String>(
    'payload',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, createdAt, payload];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'download_tasks';
  @override
  VerificationContext validateIntegrity(
    Insertable<DbDownloadTasks> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('payload')) {
      context.handle(
        _payloadMeta,
        payload.isAcceptableOrUnknown(data['payload']!, _payloadMeta),
      );
    } else if (isInserting) {
      context.missing(_payloadMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  DbDownloadTasks map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DbDownloadTasks(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
      payload: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload'],
      )!,
    );
  }

  @override
  $DownloadTasksTable createAlias(String alias) {
    return $DownloadTasksTable(attachedDatabase, alias);
  }
}

class DbDownloadTasks extends DataClass implements Insertable<DbDownloadTasks> {
  final String id;
  final int createdAt;
  final String payload;
  const DbDownloadTasks({
    required this.id,
    required this.createdAt,
    required this.payload,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['created_at'] = Variable<int>(createdAt);
    map['payload'] = Variable<String>(payload);
    return map;
  }

  DownloadTasksCompanion toCompanion(bool nullToAbsent) {
    return DownloadTasksCompanion(
      id: Value(id),
      createdAt: Value(createdAt),
      payload: Value(payload),
    );
  }

  factory DbDownloadTasks.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DbDownloadTasks(
      id: serializer.fromJson<String>(json['id']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
      payload: serializer.fromJson<String>(json['payload']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'createdAt': serializer.toJson<int>(createdAt),
      'payload': serializer.toJson<String>(payload),
    };
  }

  DbDownloadTasks copyWith({String? id, int? createdAt, String? payload}) =>
      DbDownloadTasks(
        id: id ?? this.id,
        createdAt: createdAt ?? this.createdAt,
        payload: payload ?? this.payload,
      );
  DbDownloadTasks copyWithCompanion(DownloadTasksCompanion data) {
    return DbDownloadTasks(
      id: data.id.present ? data.id.value : this.id,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      payload: data.payload.present ? data.payload.value : this.payload,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DbDownloadTasks(')
          ..write('id: $id, ')
          ..write('createdAt: $createdAt, ')
          ..write('payload: $payload')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, createdAt, payload);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DbDownloadTasks &&
          other.id == this.id &&
          other.createdAt == this.createdAt &&
          other.payload == this.payload);
}

class DownloadTasksCompanion extends UpdateCompanion<DbDownloadTasks> {
  final Value<String> id;
  final Value<int> createdAt;
  final Value<String> payload;
  final Value<int> rowid;
  const DownloadTasksCompanion({
    this.id = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.payload = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DownloadTasksCompanion.insert({
    required String id,
    required int createdAt,
    required String payload,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       createdAt = Value(createdAt),
       payload = Value(payload);
  static Insertable<DbDownloadTasks> custom({
    Expression<String>? id,
    Expression<int>? createdAt,
    Expression<String>? payload,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (createdAt != null) 'created_at': createdAt,
      if (payload != null) 'payload': payload,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DownloadTasksCompanion copyWith({
    Value<String>? id,
    Value<int>? createdAt,
    Value<String>? payload,
    Value<int>? rowid,
  }) {
    return DownloadTasksCompanion(
      id: id ?? this.id,
      createdAt: createdAt ?? this.createdAt,
      payload: payload ?? this.payload,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (payload.present) {
      map['payload'] = Variable<String>(payload.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DownloadTasksCompanion(')
          ..write('id: $id, ')
          ..write('createdAt: $createdAt, ')
          ..write('payload: $payload, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PendingFileDeletionsTable extends PendingFileDeletions
    with TableInfo<$PendingFileDeletionsTable, DbPendingFileDeletions> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PendingFileDeletionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _pathMeta = const VerificationMeta('path');
  @override
  late final GeneratedColumn<String> path = GeneratedColumn<String>(
    'path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    check: () => kind.isIn(['chatAttachment', 'speechJob', 'voiceProfile']),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [path, kind];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'pending_file_deletions';
  @override
  VerificationContext validateIntegrity(
    Insertable<DbPendingFileDeletions> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('path')) {
      context.handle(
        _pathMeta,
        path.isAcceptableOrUnknown(data['path']!, _pathMeta),
      );
    } else if (isInserting) {
      context.missing(_pathMeta);
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {path};
  @override
  DbPendingFileDeletions map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DbPendingFileDeletions(
      path: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}path'],
      )!,
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
    );
  }

  @override
  $PendingFileDeletionsTable createAlias(String alias) {
    return $PendingFileDeletionsTable(attachedDatabase, alias);
  }
}

class DbPendingFileDeletions extends DataClass
    implements Insertable<DbPendingFileDeletions> {
  final String path;
  final String kind;
  const DbPendingFileDeletions({required this.path, required this.kind});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['path'] = Variable<String>(path);
    map['kind'] = Variable<String>(kind);
    return map;
  }

  PendingFileDeletionsCompanion toCompanion(bool nullToAbsent) {
    return PendingFileDeletionsCompanion(path: Value(path), kind: Value(kind));
  }

  factory DbPendingFileDeletions.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DbPendingFileDeletions(
      path: serializer.fromJson<String>(json['path']),
      kind: serializer.fromJson<String>(json['kind']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'path': serializer.toJson<String>(path),
      'kind': serializer.toJson<String>(kind),
    };
  }

  DbPendingFileDeletions copyWith({String? path, String? kind}) =>
      DbPendingFileDeletions(path: path ?? this.path, kind: kind ?? this.kind);
  DbPendingFileDeletions copyWithCompanion(PendingFileDeletionsCompanion data) {
    return DbPendingFileDeletions(
      path: data.path.present ? data.path.value : this.path,
      kind: data.kind.present ? data.kind.value : this.kind,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DbPendingFileDeletions(')
          ..write('path: $path, ')
          ..write('kind: $kind')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(path, kind);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DbPendingFileDeletions &&
          other.path == this.path &&
          other.kind == this.kind);
}

class PendingFileDeletionsCompanion
    extends UpdateCompanion<DbPendingFileDeletions> {
  final Value<String> path;
  final Value<String> kind;
  final Value<int> rowid;
  const PendingFileDeletionsCompanion({
    this.path = const Value.absent(),
    this.kind = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PendingFileDeletionsCompanion.insert({
    required String path,
    required String kind,
    this.rowid = const Value.absent(),
  }) : path = Value(path),
       kind = Value(kind);
  static Insertable<DbPendingFileDeletions> custom({
    Expression<String>? path,
    Expression<String>? kind,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (path != null) 'path': path,
      if (kind != null) 'kind': kind,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PendingFileDeletionsCompanion copyWith({
    Value<String>? path,
    Value<String>? kind,
    Value<int>? rowid,
  }) {
    return PendingFileDeletionsCompanion(
      path: path ?? this.path,
      kind: kind ?? this.kind,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (path.present) {
      map['path'] = Variable<String>(path.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PendingFileDeletionsCompanion(')
          ..write('path: $path, ')
          ..write('kind: $kind, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AppMetadataTable extends AppMetadata
    with TableInfo<$AppMetadataTable, DbAppMetadata> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AppMetadataTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [key, value];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'app_metadata';
  @override
  VerificationContext validateIntegrity(
    Insertable<DbAppMetadata> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  DbAppMetadata map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DbAppMetadata(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      )!,
    );
  }

  @override
  $AppMetadataTable createAlias(String alias) {
    return $AppMetadataTable(attachedDatabase, alias);
  }
}

class DbAppMetadata extends DataClass implements Insertable<DbAppMetadata> {
  final String key;
  final String value;
  const DbAppMetadata({required this.key, required this.value});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    return map;
  }

  AppMetadataCompanion toCompanion(bool nullToAbsent) {
    return AppMetadataCompanion(key: Value(key), value: Value(value));
  }

  factory DbAppMetadata.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DbAppMetadata(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
    };
  }

  DbAppMetadata copyWith({String? key, String? value}) =>
      DbAppMetadata(key: key ?? this.key, value: value ?? this.value);
  DbAppMetadata copyWithCompanion(AppMetadataCompanion data) {
    return DbAppMetadata(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DbAppMetadata(')
          ..write('key: $key, ')
          ..write('value: $value')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DbAppMetadata &&
          other.key == this.key &&
          other.value == this.value);
}

class AppMetadataCompanion extends UpdateCompanion<DbAppMetadata> {
  final Value<String> key;
  final Value<String> value;
  final Value<int> rowid;
  const AppMetadataCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AppMetadataCompanion.insert({
    required String key,
    required String value,
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       value = Value(value);
  static Insertable<DbAppMetadata> custom({
    Expression<String>? key,
    Expression<String>? value,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AppMetadataCompanion copyWith({
    Value<String>? key,
    Value<String>? value,
    Value<int>? rowid,
  }) {
    return AppMetadataCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AppMetadataCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  late final $AssistantsTable assistants = $AssistantsTable(this);
  late final $AiConnectionsTable aiConnections = $AiConnectionsTable(this);
  late final $SkillsTable skills = $SkillsTable(this);
  late final $McpServersTable mcpServers = $McpServersTable(this);
  late final $ConversationsTable conversations = $ConversationsTable(this);
  late final $MessagesTable messages = $MessagesTable(this);
  late final $GenerationRunsTable generationRuns = $GenerationRunsTable(this);
  late final $MessageRevisionsTable messageRevisions = $MessageRevisionsTable(
    this,
  );
  late final $RevisionAttachmentsTable revisionAttachments =
      $RevisionAttachmentsTable(this);
  late final $ToolInvocationsTable toolInvocations = $ToolInvocationsTable(
    this,
  );
  late final $ChatDraftsTable chatDrafts = $ChatDraftsTable(this);
  late final $ModelAssetsTable modelAssets = $ModelAssetsTable(this);
  late final $SpeechJobsTable speechJobs = $SpeechJobsTable(this);
  late final $VoiceProfilesTable voiceProfiles = $VoiceProfilesTable(this);
  late final $DownloadTasksTable downloadTasks = $DownloadTasksTable(this);
  late final $PendingFileDeletionsTable pendingFileDeletions =
      $PendingFileDeletionsTable(this);
  late final $AppMetadataTable appMetadata = $AppMetadataTable(this);
  late final Index conversationsRecent = Index(
    'conversations_recent',
    'CREATE INDEX conversations_recent ON conversations (updated_at DESC, id)',
  );
  late final Index conversationsAssistant = Index(
    'conversations_assistant',
    'CREATE INDEX conversations_assistant ON conversations (assistant_id, updated_at DESC)',
  );
  late final Index revisionsRun = Index(
    'revisions_run',
    'CREATE INDEX revisions_run ON message_revisions (run_id)',
  );
  late final Index revisionsSelected = Index(
    'revisions_selected',
    'CREATE UNIQUE INDEX revisions_selected ON message_revisions (message_id) WHERE is_selected = 1',
  );
  late final Index attachmentsPath = Index(
    'attachments_path',
    'CREATE INDEX attachments_path ON revision_attachments (path)',
  );
  late final Index runsConversation = Index(
    'runs_conversation',
    'CREATE INDEX runs_conversation ON generation_runs (conversation_id, updated_at DESC)',
  );
  late final Index runsActive = Index(
    'runs_active',
    'CREATE INDEX runs_active ON generation_runs (state) WHERE state IN (\'running\', \'awaitingApproval\', \'cancelling\')',
  );
  late final Index invocationsRun = Index(
    'invocations_run',
    'CREATE INDEX invocations_run ON tool_invocations (run_id, created_at)',
  );
  late final Index speechJobsRecent = Index(
    'speech_jobs_recent',
    'CREATE INDEX speech_jobs_recent ON speech_jobs (created_at DESC, id)',
  );
  late final Index speechJobsAsset = Index(
    'speech_jobs_asset',
    'CREATE INDEX speech_jobs_asset ON speech_jobs (asset_id, state)',
  );
  late final Index speechJobsVoice = Index(
    'speech_jobs_voice',
    'CREATE INDEX speech_jobs_voice ON speech_jobs (voice_id, state)',
  );
  late final Index speechJobsState = Index(
    'speech_jobs_state',
    'CREATE INDEX speech_jobs_state ON speech_jobs (state)',
  );
  late final Index voicesName = Index(
    'voices_name',
    'CREATE INDEX voices_name ON voice_profiles (name, id)',
  );
  late final Index downloadsRecent = Index(
    'downloads_recent',
    'CREATE INDEX downloads_recent ON download_tasks (created_at DESC, id)',
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    assistants,
    aiConnections,
    skills,
    mcpServers,
    conversations,
    messages,
    generationRuns,
    messageRevisions,
    revisionAttachments,
    toolInvocations,
    chatDrafts,
    modelAssets,
    speechJobs,
    voiceProfiles,
    downloadTasks,
    pendingFileDeletions,
    appMetadata,
    conversationsRecent,
    conversationsAssistant,
    revisionsRun,
    revisionsSelected,
    attachmentsPath,
    runsConversation,
    runsActive,
    invocationsRun,
    speechJobsRecent,
    speechJobsAsset,
    speechJobsVoice,
    speechJobsState,
    voicesName,
    downloadsRecent,
  ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules([
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'assistants',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('conversations', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'conversations',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('messages', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'conversations',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('generation_runs', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'messages',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('message_revisions', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'message_revisions',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('revision_attachments', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'generation_runs',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('tool_invocations', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'conversations',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('chat_drafts', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'assistants',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('chat_drafts', kind: UpdateKind.delete)],
    ),
  ]);
}
