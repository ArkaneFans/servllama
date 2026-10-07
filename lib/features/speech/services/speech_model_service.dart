import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:servllama/core/logging/app_logger.dart';
import 'package:servllama/core/models/model_asset.dart';
import 'package:servllama/core/repositories/unified_model_repository.dart';
import 'package:servllama/core/services/foreground_task_service.dart';
import 'package:servllama/core/storage/bounded_archive_output.dart';
import 'package:servllama/core/storage/bounded_zip_reader.dart';
import 'package:servllama/core/runtime/resource_coordinator.dart';
import 'package:servllama/core/utils/new_id.dart';
import 'package:servllama/features/downloads/models/download_task.dart';
import 'package:servllama/features/downloads/services/download_settings_store.dart';
import 'package:servllama/features/downloads/services/hugging_face_route_resolver.dart';
import 'package:servllama/features/downloads/services/model_download_service.dart';
import 'package:servllama/features/speech/models/speech_models.dart';
import 'package:servllama/features/speech/repositories/speech_repository.dart';

class SpeechModelService extends ChangeNotifier {
  SpeechModelService(
    this.models,
    this.repository,
    this.root, {
    ModelDownloadService? downloader,
    DownloadSettingsStore? downloadSettings,
    HuggingFaceRouteResolver? routeResolver,
    this.resources,
    AppLogger? logger,
  }) : downloader = downloader ?? ModelDownloadService(),
       _downloadSettings = downloadSettings ?? DownloadSettingsStore(),
       _routeResolver = routeResolver ?? HuggingFaceRouteResolver(),
       _logger = logger ?? AppLogger.instance;
  final AppLogger _logger;
  final UnifiedModelRepository models;
  final SpeechRepository repository;
  final Directory root;
  final ModelDownloadService downloader;
  final DownloadSettingsStore _downloadSettings;
  final HuggingFaceRouteResolver _routeResolver;
  final ResourceCoordinator? resources;
  final Map<String, CancelToken> _downloads = {};
  final Set<String> _installs = {};
  String? _importingId, _importCancelPath;
  bool _picking = false, _disposed = false;
  final Map<String, double> progress = {};
  List<ModelAsset> assets = [];
  bool importing = false;
  List<SpeechPackage> catalog = [];
  void _changed() {
    if (!_disposed) notifyListeners();
  }

  void _event(
    String name,
    ModelAsset asset, {
    LogLevel level = LogLevel.info,
    Map<String, Object?> fields = const {},
  }) => _logger.event(
    name,
    channel: LogChannel.speech,
    level: level,
    fields: {
      'asset': asset.id,
      'engine': asset.engine,
      'kind': asset.kind.name,
      ...fields,
    },
  );

  ModelAsset? assetForPackage(SpeechPackage package) => assets
      .where(
        (a) =>
            a.manifest['recipe'] == package.recipe.name &&
            a.revision == package.revision,
      )
      .firstOrNull;

  bool isInstalling(SpeechPackage package) =>
      _installs.contains('${package.recipe.name}:${package.revision}');
  Future<void> load() async {
    catalog =
        (jsonDecode(await rootBundle.loadString('assets/speech/catalog.json'))
                as List)
            .map((v) => SpeechPackage.fromJson(Map<String, dynamic>.from(v)))
            .toList();
    for (final a in await models.listAssets(reconcile: false)) {
      if (a.kind == AssetKind.llm) continue;
      if (a.state == 'deleting') {
        await delete(a);
        continue;
      }
      if (['downloading', 'importing'].contains(a.state)) {
        await _state(a, 'paused');
        _event(
          'speech.model.interrupted',
          a,
          fields: {'previous_state': a.state},
        );
      }
      if (a.isReady) {
        try {
          await validate(a, hashes: false);
        } catch (error) {
          await _state(a, 'missing');
          _event(
            'speech.model.missing',
            a,
            level: LogLevel.warning,
            fields: AppLogger.errorFields(error),
          );
        }
      }
    }
    await refresh();
  }

  Future<void> refresh() async {
    assets = (await models.listAssets(
      reconcile: false,
    )).where((a) => a.kind != AssetKind.llm).toList();
    _changed();
  }

  Future<void> _state(ModelAsset a, String state) async {
    await models.saveAsset(
      ModelAsset(
        id: a.id,
        kind: a.kind,
        engine: a.engine,
        runtimeId: a.runtimeId,
        storageOwner: a.storageOwner,
        path: a.path,
        name: a.name,
        revision: a.revision,
        state: state,
        manifest: a.manifest,
      ),
    );
  }

  Directory _folder(String id) {
    if (!RegExp(r'^[a-f0-9-]{36}$').hasMatch(id)) {
      throw const FormatException('Invalid speech asset ID');
    }
    return Directory(p.join(root.path, 'speech', 'models', id));
  }

  Future<ModelAsset> createAsset(
    SpeechPackage package, {
    String state = 'paused',
  }) async {
    package.validate();
    final id = newId();
    // Use the same immutable identity for storage and the unified index.
    final destination = _folder(id);
    final asset = ModelAsset(
      id: id,
      kind: package.recipe.kind,
      engine: package.recipe.engine,
      runtimeId: id,
      storageOwner: 'app',
      path: destination.path,
      name: package.name,
      revision: package.revision,
      state: state,
      manifest: package.toJson(),
    );
    await destination.create(recursive: true);
    await File(
      p.join(destination.path, 'speech-package.json'),
    ).writeAsString(jsonEncode(package.toJson()), flush: true);
    await models.saveAsset(asset);
    await refresh();
    _event('speech.model.registered', asset, fields: {'state': state});
    return asset;
  }

  Future<void> install(SpeechPackage package) async {
    final key = '${package.recipe.name}:${package.revision}';
    if (!_installs.add(key)) return;
    _changed();
    try {
      final existing = assetForPackage(package);
      if (existing?.isReady == true) {
        throw StateError('This model package is already installed');
      }
      final asset = existing ?? await createAsset(package);
      await resume(asset);
    } finally {
      _installs.remove(key);
      _changed();
    }
  }

  void pause(String id) {
    final token = _downloads[id];
    if (token == null || token.isCancelled) return;
    _logger.event(
      'speech.download.pause_requested',
      channel: LogChannel.speech,
      fields: {'asset': id},
    );
    token.cancel('pause');
  }

  Future<void> resume(ModelAsset asset) async {
    if (_downloads.containsKey(asset.id)) return;
    if (_importingId == asset.id) {
      throw StateError('Model import is still active');
    }
    final package = SpeechPackage.fromJson(asset.manifest);
    final folder = _folder(asset.id);
    final token = CancelToken();
    _downloads[asset.id] = token;
    progress[asset.id] = 0;
    final foreground = ForegroundTaskService()..init();
    final watch = Stopwatch()..start();
    var stage = 'storage';
    _event(
      'speech.download.started',
      asset,
      fields: {'files': package.files.length, 'bytes': package.totalBytes},
    );
    try {
      final route = await _downloadSettings.loadHuggingFaceRoute();
      final free = await const MethodChannel(
        'com.arkanefans.servllama/download_environment',
      ).invokeMethod<int>('availableStorageBytes');
      var existing = 0;
      for (final f in package.files) {
        for (final suffix in ['', ModelDownloadService.partSuffix]) {
          final disk = File(p.join(folder.path, f.path + suffix));
          if (await disk.exists()) existing += await disk.length();
        }
      }
      if (free != null &&
          free < package.totalBytes - existing + 128 * 1024 * 1024) {
        throw StateError('Not enough free storage');
      }
      await _state(asset, 'downloading');
      await refresh();
      await foreground.acquire(
        owner: 'speech-download-${asset.id}',
        notificationTitle: asset.name,
        notificationText: 'ServLlama',
      );
      var completed = 0;
      stage = 'transfer';
      var last = DateTime.now();
      for (final file in package.files) {
        if (token.isCancelled) throw token.cancelError!;
        if (file.url == null) {
          throw const FormatException(
            'An imported package must be reselected or deleted; no download URL',
          );
        }
        final url = await _routeResolver.resolveFileUrl(file.url!, route);
        if (token.isCancelled) throw token.cancelError!;
        await downloader.downloadFile(
          url: url,
          file: DownloadFileRecord(
            remotePath: file.path,
            fileName: file.path,
            totalBytes: file.bytes,
            sha256: file.sha256,
          ),
          targetDirectory: folder,
          cancelToken: token,
          onProgress: (record, delta) {
            progress[asset.id] =
                (completed + record.receivedBytes) / package.totalBytes;
            if (DateTime.now().difference(last).inMilliseconds > 250) {
              last = DateTime.now();
              _changed();
            }
          },
        );
        completed += file.bytes;
      }
      stage = 'validation';
      await validate(asset);
      if (token.isCancelled) throw token.cancelError!;
      stage = 'commit';
      await _state(asset, 'ready');
      _event(
        'speech.download.completed',
        asset,
        fields: {'elapsed_ms': watch.elapsedMilliseconds},
      );
    } catch (error) {
      _event(
        token.isCancelled ? 'speech.download.paused' : 'speech.download.failed',
        asset,
        level: token.isCancelled ? LogLevel.info : LogLevel.error,
        fields: {
          'elapsed_ms': watch.elapsedMilliseconds,
          'stage': stage,
          if (!token.isCancelled) ...AppLogger.errorFields(error),
        },
      );
      await _state(asset, 'paused');
      if (!token.isCancelled) rethrow;
    } finally {
      _downloads.remove(asset.id);
      progress.remove(asset.id);
      await foreground.release('speech-download-${asset.id}');
      await refresh();
    }
  }

  Future<void> validate(ModelAsset asset, {bool hashes = true}) async {
    final folder = _folder(asset.id);
    if (p.normalize(asset.path) != p.normalize(folder.path)) {
      throw StateError('Model storage identity mismatch');
    }
    final manifest = SpeechPackage.fromJson(asset.manifest);
    await Isolate.run(() async {
      if (!await folder.exists()) {
        throw StateError('Model directory is missing');
      }
      final canonical = await folder.resolveSymbolicLinks();
      if (p.normalize(canonical) != p.normalize(folder.absolute.path)) {
        throw StateError('Model links are not supported');
      }
      for (final spec in manifest.files) {
        final file = File(p.join(folder.path, spec.path));
        if (!await file.exists() ||
            await file.length() != spec.bytes ||
            !p.isWithin(canonical, await file.resolveSymbolicLinks())) {
          throw StateError('Model dependency missing or changed: ${spec.path}');
        }
        if (manifest.recipe.engine == 'crispasr' &&
            manifest.recipe.requiredRoles.any(
              (role) => manifest.config[role] == spec.path,
            )) {
          final handle = await file.open();
          try {
            final magic = String.fromCharCodes(await handle.read(4));
            final expected = manifest.recipe == SpeechRecipe.crispWhisper
                ? 'lmgg'
                : 'GGUF';
            if (magic != expected) {
              throw const FormatException('Unsupported native model format');
            }
          } finally {
            await handle.close();
          }
        }
        if (hashes &&
            (await sha256.bind(file.openRead()).first)
                    .toString()
                    .toLowerCase() !=
                spec.sha256.toLowerCase()) {
          throw StateError('Model checksum mismatch: ${spec.path}');
        }
      }
    });
  }

  Future<void> importZip() async {
    if (importing || _picking) return;
    _picking = true;
    try {
      final choice = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['zip'],
      );
      final path = choice?.files.single.path;
      if (path == null) return;
      await importArchive(path);
    } finally {
      _picking = false;
    }
  }

  Future<void> cancelImport() async {
    final path = _importCancelPath;
    if (path != null) {
      final marker = File(path);
      if (marker.existsSync()) return;
      marker.parent.createSync(recursive: true);
      marker.writeAsStringSync('cancel', flush: true);
      _logger.event(
        'speech.import.cancel_requested',
        channel: LogChannel.speech,
        fields: {'asset': _importingId},
      );
    }
  }

  Future<ModelAsset> importArchive(
    String path, [
    SpeechPackage? package,
  ]) async {
    if (importing) throw StateError('Another model import is active');
    importing = true;
    _changed();
    ModelAsset? a;
    final marker = File(p.join(root.path, 'speech', 'cancel-${newId()}'));
    _importCancelPath = marker.path;
    final watch = Stopwatch()..start();
    var stage = 'manifest';
    _logger.event('speech.import.started', channel: LogChannel.speech);
    try {
      await marker.parent.create(recursive: true);
      final SpeechPackage manifest =
          package ??
          await Isolate.run<SpeechPackage>(() => readArchiveManifest(path));
      stage = 'storage';
      final free = await const MethodChannel(
        'com.arkanefans.servllama/download_environment',
      ).invokeMethod<int>('availableStorageBytes');
      if (free != null && free < manifest.totalBytes + 128 * 1024 * 1024) {
        throw StateError('Not enough free storage');
      }
      if (await marker.exists()) throw StateError('Model import cancelled');
      a = await createAsset(manifest, state: 'importing');
      _importingId = a.id;
      final destination = a.path;
      final cancelPath = marker.path;
      stage = 'extraction';
      await Isolate.run(
        () => _extract(path, destination, manifest, cancelPath),
      );
      stage = 'validation';
      await validate(a);
      if (await marker.exists()) throw StateError('Model import cancelled');
      stage = 'commit';
      await _state(a, 'ready');
      await refresh();
      _event(
        'speech.import.completed',
        a,
        fields: {
          'elapsed_ms': watch.elapsedMilliseconds,
          'files': manifest.files.length,
        },
      );
      return (await models.asset(a.id))!;
    } catch (error) {
      final cancelled = await marker.exists();
      _logger.event(
        cancelled ? 'speech.import.cancelled' : 'speech.import.failed',
        channel: LogChannel.speech,
        level: cancelled ? LogLevel.info : LogLevel.error,
        fields: {
          'asset': a?.id,
          'stage': stage,
          'elapsed_ms': watch.elapsedMilliseconds,
          if (!cancelled) ...AppLogger.errorFields(error),
        },
      );
      if (a != null) {
        if (cancelled) {
          await _folder(a.id).delete(recursive: true);
          await repository.db.execute('DELETE FROM model_assets WHERE id=?', [
            a.id,
          ]);
        } else {
          await _state(a, 'missing');
        }
      }
      await refresh();
      rethrow;
    } finally {
      if (await marker.exists()) await marker.delete();
      _importingId = _importCancelPath = null;
      importing = false;
      _changed();
    }
  }

  static SpeechPackage readArchiveManifest(String path) {
    final input = InputFileStream(path);
    try {
      final archive = readBoundedZip(
        input,
        maxEntries: 512,
        maxExpandedBytes: 12 * 1024 * 1024 * 1024 + 1024 * 1024,
      );
      final entry = archive.findFile('speech-package.json');
      if (entry == null || entry.size > 1024 * 1024) {
        throw const FormatException(
          'ZIP needs speech-package.json at its root',
        );
      }
      if (entry.isSymbolicLink || !entry.isFile) {
        throw const FormatException('Manifest must be a regular file');
      }
      final buffer = OutputMemoryStream();
      entry.writeContent(BoundedArchiveOutput(buffer, 1024 * 1024));
      return SpeechPackage.fromJson(jsonDecode(utf8.decode(buffer.getBytes())));
    } finally {
      input.closeSync();
    }
  }

  static void _extract(
    String path,
    String destination,
    SpeechPackage manifest,
    String cancelPath,
  ) {
    final input = InputFileStream(path);
    try {
      final archive = readBoundedZip(
        input,
        maxEntries: 512,
        maxExpandedBytes: 12 * 1024 * 1024 * 1024 + 1024 * 1024,
      );
      final expected = {for (final f in manifest.files) f.path: f};
      final found = <String>{};
      if (archive.length > 512) {
        throw const FormatException('Too many ZIP entries');
      }
      for (final entry in archive) {
        void checkCancelled() {
          if (File(cancelPath).existsSync()) {
            throw StateError('Model import cancelled');
          }
        }

        checkCancelled();
        if (entry.isSymbolicLink) {
          throw const FormatException('Model package links are not allowed');
        }
        if (!entry.isFile) continue;
        if (!SpeechPackage.safePath(entry.name) ||
            !found.add(entry.name.toLowerCase())) {
          throw const FormatException('Unsafe or duplicate ZIP path');
        }
        if (entry.name == 'speech-package.json') continue;
        final spec = expected[entry.name];
        if (spec == null || entry.size != spec.bytes) {
          throw const FormatException('Unexpected or wrong-size model file');
        }
        final target = File(p.join(destination, entry.name));
        target.parent.createSync(recursive: true);
        final output = BoundedArchiveOutput(
          OutputFileStream(target.path),
          spec.bytes,
          checkCancelled: checkCancelled,
        );
        try {
          entry.writeContent(output);
          if (output.length != spec.bytes) {
            throw const FormatException('Truncated model file');
          }
        } finally {
          output.closeSync();
        }
      }
      if (!found.containsAll(expected.keys.map((v) => v.toLowerCase()))) {
        throw const FormatException('Model dependencies are missing');
      }
    } finally {
      input.closeSync();
    }
  }

  Future<void> delete(ModelAsset a) async {
    try {
      await _delete(a);
      _event('speech.model.deleted', a);
    } catch (error) {
      _event(
        'speech.model.delete_failed',
        a,
        level: LogLevel.error,
        fields: AppLogger.errorFields(error),
      );
      rethrow;
    }
  }

  Future<void> _delete(ModelAsset a) async {
    if (resources?.leaseFor(LocalResourceDomain.speech)?.assetId == a.id) {
      throw StateError('The model is still resident; wait for native cleanup');
    }
    if (_importingId == a.id) throw StateError('Cancel the model import first');
    if (_downloads.containsKey(a.id)) {
      throw StateError('Pause the download before deleting');
    }
    await repository.db.transaction(() async {
      if (await repository.usesAsset(a.id)) {
        throw StateError('Cancel or finish jobs using this model first');
      }
      await _state(a, 'deleting');
    });
    final folder = _folder(a.id);
    if (await folder.exists()) {
      if (p.normalize(await folder.resolveSymbolicLinks()) !=
          p.normalize(folder.absolute.path)) {
        throw StateError('Unexpected model storage link');
      }
      await folder.delete(recursive: true);
    }
    await repository.db.execute('DELETE FROM model_assets WHERE id=?', [a.id]);
    await refresh();
  }

  @override
  void dispose() {
    _disposed = true;
    for (final token in _downloads.values) {
      token.cancel('disposed');
    }
    super.dispose();
  }
}
