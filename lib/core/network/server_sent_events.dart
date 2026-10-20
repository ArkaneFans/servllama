import 'dart:convert';

class ServerEvent {
  const ServerEvent(this.data, {this.event = '', this.id = ''});
  final String data, event, id;
}

/// UTF-8 and event boundaries can both span arbitrary transport chunks.
Stream<ServerEvent> decodeServerEvents(Stream<List<int>> stream) async* {
  var data = <String>[], event = '', id = '', size = 0;
  await for (final line
      in stream
          .cast<List<int>>()
          .transform(const Utf8Decoder())
          .transform(const LineSplitter())) {
    size += line.length;
    if (size > 1024 * 1024) {
      throw const FormatException('SSE event exceeds 1 MiB');
    }
    if (line.isEmpty) {
      if (data.isNotEmpty) {
        yield ServerEvent(data.join('\n'), event: event, id: id);
      }
      data = [];
      event = '';
      id = '';
      size = 0;
    } else if (!line.startsWith(':')) {
      final split = line.indexOf(':');
      final field = split < 0 ? line : line.substring(0, split);
      var value = split < 0 ? '' : line.substring(split + 1);
      if (value.startsWith(' ')) value = value.substring(1);
      switch (field) {
        case 'data':
          data.add(value);
        case 'event':
          event = value;
        case 'id':
          id = value;
      }
    }
  }
  if (data.isNotEmpty) yield ServerEvent(data.join('\n'), event: event, id: id);
}
