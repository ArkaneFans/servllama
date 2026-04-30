import 'dart:io';

import 'package:path_provider/path_provider.dart';

class ModelStoragePaths {
  ModelStoragePaths({Directory? appSupportDirectory})
    : _appSupportDirectory = appSupportDirectory;

  static const String modelsFolderName = 'models';

  final Directory? _appSupportDirectory;

  Future<Directory> getAppSupportDirectory() async {
    if (_appSupportDirectory != null) {
      return _appSupportDirectory;
    }
    return getApplicationSupportDirectory();
  }

  Future<Directory> getModelsDirectory() async {
    final appSupportDirectory = await getAppSupportDirectory();
    final modelsDirectory = Directory(
      _joinPath(appSupportDirectory.path, modelsFolderName),
    );
    if (!await modelsDirectory.exists()) {
      await modelsDirectory.create(recursive: true);
    }
    return modelsDirectory;
  }

  Future<String> getModelsDirectoryPath() async {
    final modelsDirectory = await getModelsDirectory();
    return modelsDirectory.path;
  }

  Future<Directory> getModelDirectory(String modelName) async {
    final trimmedModelName = modelName.trim();
    if (trimmedModelName.isEmpty) {
      throw ArgumentError.value(modelName, 'modelName', 'must not be empty');
    }

    final modelsDirectory = await getModelsDirectory();
    return Directory(_joinPath(modelsDirectory.path, trimmedModelName));
  }

  String _joinPath(String left, String right) {
    final needsSeparator =
        !left.endsWith(Platform.pathSeparator) &&
        !right.startsWith(Platform.pathSeparator);
    if (needsSeparator) {
      return '$left${Platform.pathSeparator}$right';
    }
    return '$left$right';
  }
}
