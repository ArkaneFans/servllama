import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';

const bingSearchFixture = '''
<html><body><ol id="b_results">
<li class="b_algo"><h2><a href="https://docs.example/guide">Guide &amp; reference</a></h2>
<div class="b_caption"><p>Example documentation excerpt.</p></div></li>
</ol></body></html>
''';

Dio searchTestDio(
  FutureOr<ResponseBody> Function(RequestOptions, Future<void>?) respond,
) => Dio()..httpClientAdapter = _SearchAdapter(respond);

ResponseBody searchHtml(
  String html, {
  int status = 200,
  Map<String, List<String>> headers = const {},
}) => ResponseBody.fromString(
  html,
  status,
  headers: {
    'content-type': ['text/html; charset=utf-8'],
    ...headers,
  },
);

class _SearchAdapter implements HttpClientAdapter {
  _SearchAdapter(this.respond);
  final FutureOr<ResponseBody> Function(RequestOptions, Future<void>?) respond;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async => respond(options, cancelFuture);
  @override
  void close({bool force = false}) {}
}
