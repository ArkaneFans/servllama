enum ChatModelStatus { loaded, loading, unloaded, failed }

class ChatModelOption {
  const ChatModelOption({
    required this.id,
    required this.displayName,
    required this.status,
  });

  final String id;
  final String displayName;
  final ChatModelStatus status;

  bool get isLoaded => status == ChatModelStatus.loaded;
}
