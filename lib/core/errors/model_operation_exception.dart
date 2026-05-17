enum ModelOperationErrorCode {
  unsupportedGgufFile,
  selectedModelFileMissing,
  invalidModelName,
  duplicateModelName,
  modelNotFound,
  selectedMmprojFileMissing,
  unsupportedMmprojFile,
  mmprojSameAsModelFile,
  emptyModelName,
  modelNameExists,
  modelDirectoryExists,
  modelNotFoundOrDeleted,
  selectedFilePathUnavailable,
}

class ModelOperationException implements Exception {
  const ModelOperationException(this.code);

  final ModelOperationErrorCode code;

  @override
  String toString() => 'ModelOperationException($code)';
}
