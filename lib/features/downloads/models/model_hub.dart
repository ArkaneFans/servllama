import 'package:servllama/core/models/inference_engine.dart';

/// Where a model can be fetched from. Both hubs expose the same three
/// capabilities the app needs: search, list repo files, download by path.
enum ModelHubSource {
  huggingFace,
  modelScope;

  static ModelHubSource fromStorageValue(String? value) {
    for (final source in ModelHubSource.values) {
      if (source.storageValue == value) {
        return source;
      }
    }
    return ModelHubSource.huggingFace;
  }

  String get storageValue {
    switch (this) {
      case ModelHubSource.huggingFace:
        return 'huggingface';
      case ModelHubSource.modelScope:
        return 'modelscope';
    }
  }

  /// Brand names, identical in every locale — deliberately not in the ARBs.
  String get displayName {
    switch (this) {
      case ModelHubSource.huggingFace:
        return 'Hugging Face';
      case ModelHubSource.modelScope:
        return '魔搭 ModelScope';
    }
  }
}

/// A repository as it appears in search results.
class HubRepoSummary {
  const HubRepoSummary({
    required this.source,
    required this.repoId,
    required this.owner,
    required this.name,
    this.downloads = 0,
    this.likes = 0,
    this.lastModified,
    this.fileCount,
    this.tags = const <String>[],
  });

  final ModelHubSource source;

  /// `owner/name`, the form both hubs use in their file and download APIs.
  final String repoId;
  final String owner;
  final String name;
  final int downloads;
  final int likes;
  final DateTime? lastModified;
  final int? fileCount;
  final List<String> tags;

  /// Repos whose files are MNN model directories rather than GGUF blobs.
  bool get looksLikeMnn {
    final haystack = '$repoId ${tags.join(' ')}'.toLowerCase();
    return haystack.contains('mnn');
  }

  InferenceEngine get likelyEngine =>
      looksLikeMnn ? InferenceEngine.mnn : InferenceEngine.llamaCpp;
}

/// One downloadable file inside a repository.
class HubRepoFile {
  const HubRepoFile({required this.path, required this.sizeBytes, this.sha256});

  final String path;
  final int sizeBytes;
  final String? sha256;

  String get fileName => path.split('/').last;

  bool get isGguf => fileName.toLowerCase().endsWith('.gguf');

  bool get isMmproj {
    final normalized = fileName.toLowerCase();
    return normalized.startsWith('mmproj') && normalized.endsWith('.gguf');
  }

  /// Quantization tag parsed out of a GGUF filename (`Q4_K_M`, `IQ2_M`, …).
  /// Null for files that do not follow the convention.
  String? get quantLabel {
    final match = RegExp(
      r'[.-]((?:I?Q\d+(?:_[A-Z0-9]+)*)|F16|F32|BF16)\.gguf$',
      caseSensitive: false,
    ).firstMatch(fileName);
    return match?.group(1)?.toUpperCase();
  }
}

/// A repository plus its file listing.
class HubRepoDetail {
  const HubRepoDetail({
    required this.summary,
    required this.files,
    this.revision = 'main',
  });

  final HubRepoSummary summary;
  final List<HubRepoFile> files;
  final String revision;

  List<HubRepoFile> get ggufFiles => files
      .where((file) => file.isGguf && !file.isMmproj)
      .toList(growable: false);

  HubRepoFile? get mmprojFile {
    for (final file in files) {
      if (file.isMmproj) {
        return file;
      }
    }
    return null;
  }
}
