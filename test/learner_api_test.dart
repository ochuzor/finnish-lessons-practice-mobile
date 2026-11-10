import 'package:finnishlessons/api/learner_api.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test(
    'getCurrentUser sends the Firebase bearer token and parses user',
    () async {
      late http.Request capturedRequest;
      final client = MockClient((request) async {
        capturedRequest = request;
        return http.Response(
          '{"user":{"id":42,"username":"oppija","is_owner":false}}',
          200,
          headers: {'content-type': 'application/json'},
        );
      });
      final api = HttpLearnerApi(
        baseUrl: 'https://finnish.ochuzor.com',
        idTokenProvider: () async => 'firebase-token',
        client: client,
      );

      final user = await api.getCurrentUser();

      expect(
        capturedRequest.url.toString(),
        'https://finnish.ochuzor.com/api/auth/me',
      );
      expect(capturedRequest.headers['authorization'], 'Bearer firebase-token');
      expect(user.id, 42);
      expect(user.username, 'oppija');
      expect(user.isOwner, isFalse);
    },
  );

  test('API errors expose the backend detail message', () async {
    final api = HttpLearnerApi(
      baseUrl: 'https://finnish.ochuzor.com',
      idTokenProvider: () async => 'firebase-token',
      client: MockClient(
        (_) async => http.Response('{"detail":"Account is not allowed."}', 403),
      ),
    );

    expect(
      api.getCurrentUser(),
      throwsA(
        isA<LearnerApiException>()
            .having((error) => error.statusCode, 'statusCode', 403)
            .having(
              (error) => error.detail,
              'detail',
              'Account is not allowed.',
            ),
      ),
    );
  });

  test('a missing Firebase token stops before the network request', () async {
    var requestWasSent = false;
    final api = HttpLearnerApi(
      baseUrl: 'https://finnish.ochuzor.com',
      idTokenProvider: () async => null,
      client: MockClient((_) async {
        requestWasSent = true;
        return http.Response('{}', 200);
      }),
    );

    await expectLater(
      api.getCurrentUser(),
      throwsA(
        isA<LearnerApiException>().having(
          (error) => error.detail,
          'detail',
          contains('sign-in session'),
        ),
      ),
    );
    expect(requestWasSent, isFalse);
  });
}
