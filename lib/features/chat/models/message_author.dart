/// Display attribution, independent of the current assistant and model.
class MessageAuthor {
  const MessageAuthor({required this.assistantId, required this.name});
  final String assistantId, name;

  Map<String, dynamic> toJson() => {'assistantId': assistantId, 'name': name};

  factory MessageAuthor.fromJson(Map<String, dynamic> json) => MessageAuthor(
    assistantId: json['assistantId'] as String,
    name: json['name'] as String,
  );
}
