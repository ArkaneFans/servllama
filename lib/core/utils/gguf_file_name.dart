// Filename helpers for GGUF packages stored on disk or listed by a hub.

bool isGgufFileName(String fileName) {
  return _baseName(fileName).toLowerCase().endsWith('.gguf');
}

/// Projector files are identified by the substring `mmproj` in the base name,
/// not only a `mmproj-` prefix. Hub uploads often look like
/// `Qwen3.5-0.8B-mmproj-f16.gguf`.
bool isMmprojFileName(String fileName) {
  final normalized = _baseName(fileName).toLowerCase();
  return normalized.endsWith('.gguf') && normalized.contains('mmproj');
}

String _baseName(String fileName) {
  return fileName.split(RegExp(r'[\\/]')).last;
}
