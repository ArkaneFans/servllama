class ChatStreamDelta {
  const ChatStreamDelta({this.content = '', this.reasoningContent = ''});

  final String content;
  final String reasoningContent;

  bool get isEmpty => content.isEmpty && reasoningContent.isEmpty;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChatStreamDelta &&
          runtimeType == other.runtimeType &&
          content == other.content &&
          reasoningContent == other.reasoningContent;

  @override
  int get hashCode => Object.hash(content, reasoningContent);
}
