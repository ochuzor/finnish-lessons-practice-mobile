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

  test('modules and home recommendation match the mobile contract', () async {
    final requestedPaths = <String>[];
    final api = HttpLearnerApi(
      baseUrl: 'https://finnish.ochuzor.com/',
      idTokenProvider: () async => 'firebase-token',
      client: MockClient((request) async {
        requestedPaths.add(request.url.path);
        if (request.url.path == '/api/modules') {
          return http.Response(
            '[{"id":"01_first_conversations","title":"First Conversations","file_name":"01.md","module_order":1,"description":"Start here."}]',
            200,
          );
        }
        if (request.url.path == '/api/lessons') {
          return http.Response(
            '[{"id":"lesson-1","module_id":"01_first_conversations","title":"Greetings","file_name":"lesson-1.md","heading":"Greetings","section_order":1,"description":"Say hello.","total_words":4,"new_words":2,"practicing_words":1,"mastered_words":1,"sections":[{"heading":"Hello","content":"Hei!","section_order":1}],"locked":false,"checkpoint_passed":false}]',
            200,
          );
        }
        return http.Response(
          '{"due_count":3,"next_lesson":{"id":"lesson-1","module_id":"01_first_conversations","title":"Greetings"},"course_complete":false,"progress":{"total_modules":8,"completed_modules":1,"lesson_checks_passed":4,"practicing_words":12,"mastered_words":7}}',
          200,
        );
      }),
    );

    final modules = await api.getModules();
    final recommendation = await api.getHomeRecommendation();
    final lessons = await api.getLessons();

    expect(requestedPaths, [
      '/api/modules',
      '/api/home/recommendation',
      '/api/lessons',
    ]);
    expect(modules.single.title, 'First Conversations');
    expect(modules.single.moduleOrder, 1);
    expect(recommendation.dueCount, 3);
    expect(recommendation.nextLesson?.title, 'Greetings');
    expect(recommendation.progress.completedModules, 1);
    expect(recommendation.progress.masteredWords, 7);
    expect(lessons.single.title, 'Greetings');
    expect(lessons.single.sections.single.content, 'Hei!');
    expect(lessons.single.locked, isFalse);
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

  test('lesson vocabulary preserves authored order and progress', () async {
    late http.Request capturedRequest;
    final api = HttpLearnerApi(
      baseUrl: 'https://finnish.ochuzor.com',
      idTokenProvider: () async => 'firebase-token',
      client: MockClient((request) async {
        capturedRequest = request;
        return http.Response(
          '[{"word":"kauppa","translations":["shop","store"],"score":0,"source_lesson_id":null,"is_personal":false},{"word":"leipä","translations":["bread"],"score":3,"source_lesson_id":null,"is_personal":false}]',
          200,
        );
      }),
    );

    final words = await api.getLessonWords('lesson one');

    expect(capturedRequest.url.path, '/api/lessons/lesson%20one/words');
    expect(words.map((word) => word.word), ['kauppa', 'leipä']);
    expect(words.first.translations, ['shop', 'store']);
    expect(words.last.score, 3);
    expect(words.last.isPersonal, isFalse);
  });

  test(
    'quiz batch and review use the authenticated practice contract',
    () async {
      final requests = <http.Request>[];
      final api = HttpLearnerApi(
        baseUrl: 'https://finnish.ochuzor.com',
        idTokenProvider: () async => 'firebase-token',
        client: MockClient((request) async {
          requests.add(request);
          if (request.method == 'GET') {
            return http.Response(
              '[{"word":"leipää","translations":["bread"],"score":2,"source_lesson_id":"lesson one","is_personal":false}]',
              200,
            );
          }
          return http.Response(
            '{"word":"leipää","correct":true,"score":3,"score_increased":true,"last_increased_at":"2026-11-10T15:20:00+00:00","due_at":"2026-11-14T15:20:00+00:00"}',
            200,
          );
        }),
      );

      final batch = await api.getLessonQuizBatch('lesson one');
      final result = await api.reviewLessonWord(
        lessonId: 'lesson one',
        word: 'leipää',
        correct: true,
      );

      expect(requests[0].url.path, '/api/lessons/lesson%20one/quiz-batch');
      expect(
        requests[1].url.path,
        '/api/lessons/lesson%20one/words/leip%C3%A4%C3%A4/review',
      );
      expect(requests[1].headers['authorization'], 'Bearer firebase-token');
      expect(requests[1].headers['content-type'], 'application/json');
      expect(requests[1].body, '{"correct":true}');
      expect(batch.single.score, 2);
      expect(result.score, 3);
      expect(result.scoreIncreased, isTrue);
      expect(result.dueAt, DateTime.parse('2026-11-14T15:20:00+00:00'));
    },
  );

  test('lesson check sends exact choices and parses server scoring', () async {
    final requests = <http.Request>[];
    final api = HttpLearnerApi(
      baseUrl: 'https://finnish.ochuzor.com',
      idTokenProvider: () async => 'firebase-token',
      client: MockClient((request) async {
        requests.add(request);
        if (request.url.path.endsWith('/checkpoint/start')) {
          return http.Response(
            '{"session_id":"session-1","required_correct":2,"questions":[{"id":"1","prompt":"kauppa","options":["shop","bread"],"translation":""},{"id":"2","prompt":"Tarvitsen ___.","options":["leipää","pussi"],"translation":"I need bread."}]}',
            200,
          );
        }
        return http.Response(
          '{"passed":true,"correct":2,"total":2,"required_correct":2,"missed":[],"unlocked_message":"Lesson unlocked: About You"}',
          200,
        );
      }),
    );

    final session = await api.startCheckpoint('lesson one');
    final result = await api.submitCheckpoint(
      lessonId: 'lesson one',
      sessionId: session.sessionId,
      answers: const {'1': 'shop', '2': 'leipää'},
    );

    expect(requests[0].url.path, '/api/lessons/lesson%20one/checkpoint/start');
    expect(requests[0].body, isEmpty);
    expect(requests[1].url.path, '/api/lessons/lesson%20one/checkpoint/submit');
    expect(
      requests[1].body,
      '{"session_id":"session-1","answers":{"1":"shop","2":"leipää"}}',
    );
    expect(session.questions.last.translation, 'I need bread.');
    expect(session.requiredCorrect, 2);
    expect(result.passed, isTrue);
    expect(result.unlockedMessage, 'Lesson unlocked: About You');
  });
}
