import 'dart:convert';
import 'package:servllama/core/models/model_asset.dart';

enum SpeechRecipe { sherpaWhisper, sherpaVits, crispWhisper, crispQwenTts }

extension SpeechRecipeInfo on SpeechRecipe {
  AssetKind get kind => switch (this) {
    SpeechRecipe.sherpaWhisper || SpeechRecipe.crispWhisper => AssetKind.asr,
    _ => AssetKind.tts,
  };
  String get engine => name.startsWith('sherpa') ? 'sherpa_onnx' : 'crispasr';
  bool get canClone => this == SpeechRecipe.crispQwenTts;
  bool get synthesisSpeed => this == SpeechRecipe.sherpaVits;
  List<String> get requiredRoles => switch (this) {
    SpeechRecipe.sherpaWhisper => ['encoder', 'decoder', 'tokens'],
    SpeechRecipe.sherpaVits => ['model', 'tokens', 'lexicon'],
    SpeechRecipe.crispWhisper => ['model'],
    SpeechRecipe.crispQwenTts => ['model', 'codec', 'voice'],
  };
}

class SpeechFile {
  const SpeechFile({
    required this.path,
    required this.bytes,
    required this.sha256,
    this.url,
  });
  final String path, sha256;
  final int bytes;
  final String? url;
  Map<String, dynamic> toJson() => {
    'path': path,
    'bytes': bytes,
    'sha256': sha256,
    if (url != null) 'url': url,
  };
  factory SpeechFile.fromJson(Map<String, dynamic> j) => SpeechFile(
    path: j['path'],
    bytes: j['bytes'],
    sha256: j['sha256'],
    url: j['url'],
  );
}

class SpeechPackage {
  SpeechPackage({
    required this.recipe,
    required this.name,
    required this.revision,
    required List<SpeechFile> files,
    required Map<String, dynamic> config,
    this.sourceUrl = '',
    this.license = '',
  }) : files = List.unmodifiable(files),
       config = SpeechJob.freeze(config);
  final SpeechRecipe recipe;
  final String name, revision, sourceUrl, license;
  final List<SpeechFile> files;
  final Map<String, dynamic> config;
  int get totalBytes => files.fold(0, (a, b) => a + b.bytes);
  Map<String, dynamic> toJson() => {
    'schemaVersion': 1,
    'recipe': recipe.name,
    'name': name,
    'revision': revision,
    'sourceUrl': sourceUrl,
    'license': license,
    'files': files.map((f) => f.toJson()).toList(),
    'config': config,
  };
  factory SpeechPackage.fromJson(Map<String, dynamic> j) {
    if (j['schemaVersion'] != 1) {
      throw const FormatException('Unsupported speech package schema');
    }
    final p = SpeechPackage(
      recipe: SpeechRecipe.values.byName(j['recipe']),
      name: j['name'],
      revision: j['revision'],
      sourceUrl: j['sourceUrl'] ?? '',
      license: j['license'] ?? '',
      files: (j['files'] as List)
          .map((f) => SpeechFile.fromJson(Map<String, dynamic>.from(f)))
          .toList(),
      config: Map<String, dynamic>.from(j['config']),
    );
    p.validate();
    return p;
  }
  void validate() {
    if (name.trim().isEmpty ||
        name.length > 120 ||
        revision.isEmpty ||
        revision.length > 256 ||
        files.isEmpty ||
        files.length > 256 ||
        totalBytes > 12 * 1024 * 1024 * 1024) {
      throw const FormatException('Invalid speech package');
    }
    final names = <String>{};
    final exactNames = files.map((f) => f.path).toSet();
    for (final f in files) {
      if (!safePath(f.path) ||
          f.path.toLowerCase() == 'speech-package.json' ||
          f.path.endsWith('.part') ||
          !names.add(f.path.toLowerCase()) ||
          f.bytes <= 0 ||
          !RegExp(r'^[a-fA-F0-9]{64}$').hasMatch(f.sha256)) {
        throw const FormatException('Invalid or duplicate model file');
      }
      if (f.url != null) {
        final u = Uri.parse(f.url!);
        if (!['https', 'http'].contains(u.scheme) ||
            u.host.isEmpty ||
            u.userInfo.isNotEmpty) {
          throw const FormatException('Invalid model download URL');
        }
      }
    }
    for (final role in recipe.requiredRoles) {
      if (config[role] is! String || !exactNames.contains(config[role])) {
        throw FormatException('Missing model dependency: $role');
      }
    }
    for (final rule in config['rules'] as List? ?? []) {
      if (rule is! String || !exactNames.contains(rule)) {
        throw const FormatException('Missing text normalization rule');
      }
    }
  }

  static bool safePath(String s) =>
      s.isNotEmpty &&
      s.length <= 200 &&
      !s.contains('\\') &&
      !s.startsWith('/') &&
      !s.contains(':') &&
      s
          .split('/')
          .every(
            (p) =>
                p.isNotEmpty &&
                p != '.' &&
                p != '..' &&
                !p.contains(RegExp(r'[\x00-\x1f]')),
          );
}

enum SpeechJobState {
  queued,
  waiting,
  running,
  cancelling,
  completed,
  cancelled,
  failed,
  interrupted,
}

extension SpeechJobStateInfo on SpeechJobState {
  bool get active => [
    SpeechJobState.queued,
    SpeechJobState.waiting,
    SpeechJobState.running,
    SpeechJobState.cancelling,
  ].contains(this);
}

class SpeechJob {
  SpeechJob({
    required this.id,
    required this.state,
    required Map<String, dynamic> snapshot,
    required this.createdAt,
    Map<String, dynamic> result = const {},
    this.progress = 0,
    this.error,
  }) : snapshot = freeze(snapshot),
       result = freeze(result);
  final String id;
  final SpeechJobState state;
  final Map<String, dynamic> snapshot, result;
  final DateTime createdAt;
  final double progress;
  final String? error;
  String get assetId => snapshot['assetId'] as String;
  AssetKind get kind => AssetKind.values.byName(snapshot['kind']);
  String get text =>
      result['editedText'] as String? ?? result['text'] as String? ?? '';
  SpeechJob copyWith({
    SpeechJobState? state,
    Map<String, dynamic>? result,
    double? progress,
    String? error,
  }) => SpeechJob(
    id: id,
    state: state ?? this.state,
    snapshot: snapshot,
    createdAt: createdAt,
    result: result ?? this.result,
    progress: progress ?? this.progress,
    error: error ?? this.error,
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'state': state.name,
    'snapshot': snapshot,
    'result': result,
    'createdAt': createdAt.millisecondsSinceEpoch,
    'progress': progress,
    'error': error,
  };
  factory SpeechJob.fromJson(Map<String, dynamic> j) => SpeechJob(
    id: j['id'],
    state: SpeechJobState.values.byName(j['state']),
    snapshot: Map<String, dynamic>.from(j['snapshot']),
    result: Map<String, dynamic>.from(j['result'] ?? {}),
    createdAt: DateTime.fromMillisecondsSinceEpoch(j['createdAt']),
    progress: (j['progress'] as num? ?? 0).toDouble(),
    error: j['error'],
  );

  /// Copies JSON data and makes every nested container immutable.
  static Map<String, dynamic> freeze(Map<String, dynamic> j) {
    Object? immutable(Object? value) => switch (value) {
      Map value => Map<String, dynamic>.unmodifiable(
        value.map((key, item) => MapEntry(key as String, immutable(item))),
      ),
      List value => List<dynamic>.unmodifiable(value.map(immutable)),
      _ => value,
    };
    return immutable(jsonDecode(jsonEncode(j)))! as Map<String, dynamic>;
  }
}

class VoiceProfile {
  const VoiceProfile({
    required this.id,
    required this.name,
    required this.assetId,
    required this.revision,
    required this.path,
    required this.hash,
    required this.referenceText,
    required this.durationSeconds,
  });
  final String id, name, assetId, revision, path, hash, referenceText;
  final double durationSeconds;
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'assetId': assetId,
    'revision': revision,
    'path': path,
    'hash': hash,
    'referenceText': referenceText,
    'durationSeconds': durationSeconds,
    'rightsConfirmed': true,
  };
  factory VoiceProfile.fromJson(Map<String, dynamic> j) => VoiceProfile(
    id: j['id'],
    name: j['name'],
    assetId: j['assetId'],
    revision: j['revision'],
    path: j['path'],
    hash: j['hash'],
    referenceText: j['referenceText'],
    durationSeconds: (j['durationSeconds'] as num).toDouble(),
  );
}
