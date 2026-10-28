import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:hello/services/api_transport.dart';

void main() {
  test('only current authenticated unauthorized responses invalidate the session', () async {
    var invalidations = 0;
    final client = ApiHttpClient(inner: MockClient((_) async => http.Response('{}', 401)),
      sessionGeneration: () => 0, onUnauthorized: () => invalidations++);
    addTearDown(client.close);
    await client.get(Uri.parse('https://example.invalid'));
    expect(invalidations, 0);
    await client.get(Uri.parse('https://example.invalid'), headers: {'Authorization': 'Bearer test'});
    expect(invalidations, 1);
  });
  test('maps non-JSON and wrong-shaped bodies without exposing proxy text', () {
    for (final body in ['<html>private proxy error</html>', '[]', 'null']) {
      expect(
        () => decodeApiBody(http.Response(body, 502)),
        throwsA(isA<ApiTransportException>()),
      );
    }
    expect(
      () => decodeApiBody(http.Response('{"message":"Please sign in."}', 401)),
      throwsA(
        isA<ApiTransportException>().having((e) => e.statusCode, 'status', 401),
      ),
    );
  });
  test('deadline includes a stalled response body', () async {
    final stream = StreamController<List<int>>();
    final client = ApiHttpClient(
      inner: MockClient.streaming(
        (_, _) async => http.StreamedResponse(stream.stream, 200),
      ),
      timeout: const Duration(milliseconds: 20),
      sessionGeneration: () => 0,
    );
    addTearDown(client.close);
    await expectLater(
      client.get(Uri.parse('https://example.invalid')),
      throwsA(
        isA<ApiTransportException>().having((e) => e.code, 'code', 'timeout'),
      ),
    );
    await stream.close();
  });
  test(
    'account switch rejects an old response and never replays a write',
    () async {
      var generation = 0;
      var calls = 0;
      final response = Completer<http.Response>();
      final client = ApiHttpClient(
        inner: MockClient((_) {
          calls++;
          return response.future;
        }),
        sessionGeneration: () => generation,
      );
      addTearDown(client.close);
      final request = client.post(Uri.parse('https://example.invalid'));
      generation++;
      response.complete(http.Response('{}', 200));
      await expectLater(
        request,
        throwsA(
          isA<ApiTransportException>().having(
            (e) => e.code,
            'code',
            'session_changed',
          ),
        ),
      );
      expect(calls, 1);
    },
  );
}
