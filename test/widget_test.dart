import 'dart:async';

import 'package:finnishlessons/api/learner_api.dart';
import 'package:finnishlessons/app.dart';
import 'package:finnishlessons/auth/auth_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('signed-out screen submits credentials and sends reset email', (
    tester,
  ) async {
    final auth = FakeAuthService();
    addTearDown(auth.dispose);

    await tester.pumpWidget(
      FinnishLessonsApp(auth: auth, learnerApi: FakeLearnerApi()),
    );
    await tester.pump();

    expect(find.text('Finnish Lessons'), findsOneWidget);
    expect(find.text('Sign in'), findsOneWidget);
    expect(find.text('Create account'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Email'),
      'learner@example.com',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Password'),
      'secret12',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pump();

    expect(auth.lastEmail, 'learner@example.com');
    expect(auth.lastPassword, 'secret12');

    await tester.tap(find.text('Forgot password?'));
    await tester.pump();

    expect(auth.passwordResetEmail, 'learner@example.com');
    expect(
      find.text('Password reset email sent. Check your inbox.'),
      findsOneWidget,
    );
  });

  testWidgets('signed-in home shows recommendation, progress, and modules', (
    tester,
  ) async {
    final auth = FakeAuthService(
      initialUser: const AppUser(email: 'me@example.com'),
    );
    addTearDown(auth.dispose);

    final learnerApi = FakeLearnerApi();
    await tester.pumpWidget(
      FinnishLessonsApp(auth: auth, learnerApi: learnerApi),
    );
    await tester.pumpAndSettle();

    expect(find.text('Tervetuloa, test-learner!'), findsOneWidget);
    expect(find.textContaining('me@example.com'), findsOneWidget);
    expect(find.text('Vocabulary review'), findsOneWidget);
    expect(find.text('2 words are ready to review.'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('First Conversations'),
      300,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('First Conversations'), findsOneWidget);
    expect(learnerApi.profileCallCount, 1);
    expect(learnerApi.modulesCallCount, 1);
    expect(learnerApi.recommendationCallCount, 1);
    expect(learnerApi.lessonsCallCount, 1);

    await tester.scrollUntilVisible(
      find.text('Locked · view locked lessons'),
      300,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('Locked · view locked lessons'), findsOneWidget);
    expect(find.byIcon(Icons.lock_outline_rounded), findsOneWidget);

    await tester.tap(find.text('Everyday Essentials'));
    await tester.pumpAndSettle();

    expect(find.text('Numbers'), findsOneWidget);
    expect(
      find.text('Locked · pass the previous lesson check'),
      findsOneWidget,
    );
    await tester.tap(find.text('Numbers'));
    await tester.pumpAndSettle();
    expect(find.text('Module 2'), findsOneWidget);
    expect(learnerApi.lessonWordsCallCount, 0);

    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('First Conversations'),
      -300,
      scrollable: find.byType(Scrollable).last,
    );

    await tester.tap(find.text('First Conversations'));
    await tester.pumpAndSettle();

    expect(find.text('Greetings'), findsOneWidget);
    expect(find.text('Ready to learn'), findsOneWidget);
    expect(find.text('Introducing yourself'), findsOneWidget);
    expect(
      find.text('Locked · pass the previous lesson check'),
      findsOneWidget,
    );
    expect(learnerApi.lessonsCallCount, 2);

    await tester.tap(find.text('Greetings'));
    await tester.pumpAndSettle();

    expect(find.text('Learn the pattern'), findsOneWidget);
    expect(find.text('Useful phrases'), findsOneWidget);
    expect(find.text('Learn the vocabulary'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('kauppa'),
      300,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('shop, store'), findsOneWidget);
    expect(find.text('New'), findsOneWidget);
    expect(learnerApi.lessonWordsCallCount, 1);
    await tester.scrollUntilVisible(
      find.text('Practice vocabulary'),
      300,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('Take lesson check'), findsOneWidget);
    expect(
      find.text('Pass the Lesson Check to unlock the next lesson.'),
      findsOneWidget,
    );

    await tester.tap(find.text('Practice vocabulary'));
    await tester.pumpAndSettle();

    expect(find.text('Choose the English meaning'), findsOneWidget);
    expect(find.text('1/2'), findsOneWidget);
    expect(learnerApi.quizBatchCallCount, 1);
    await tester.tap(find.text('shop, store'));
    await tester.pumpAndSettle();
    expect(find.text('Correct!'), findsOneWidget);
    expect(find.text('Progressed to score 1'), findsOneWidget);
    expect(learnerApi.reviewCallCount, 1);

    await tester.tap(find.text('Next card'));
    await tester.pumpAndSettle();
    expect(find.text('Do you remember this word?'), findsOneWidget);
    await tester.tap(find.text('Show answer'));
    await tester.pump();
    expect(find.text('hello'), findsOneWidget);
    await tester.tap(find.text('Recalled it'));
    await tester.pumpAndSettle();

    expect(find.text('Session complete'), findsOneWidget);
    expect(find.text('2 reviewed · 2 correct · 0 incorrect'), findsOneWidget);
    expect(learnerApi.reviewCallCount, 2);
    await tester.tap(find.text('Return to lesson'));
    await tester.pumpAndSettle();
    expect(find.text('Learn the vocabulary'), findsOneWidget);
    expect(learnerApi.lessonsCallCount, 3);
    expect(learnerApi.lessonWordsCallCount, 2);

    await tester.scrollUntilVisible(
      find.text('Take lesson check'),
      300,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.text('Take lesson check'));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('2 correct answers are required'),
      findsOneWidget,
    );
    expect(find.text('Tarvitsen ___.'), findsOneWidget);
    expect(learnerApi.checkpointStartCallCount, 1);
    await tester.tap(find.text('shop / store'));
    await tester.scrollUntilVisible(
      find.text('leipää'),
      250,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.drag(
      find.byType(Scrollable).last,
      const Offset(0, -120),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('leipää'));
    await tester.pump();
    await tester.scrollUntilVisible(
      find.text('Submit lesson check'),
      250,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.text('Submit lesson check'));
    await tester.pumpAndSettle();

    expect(find.text('Lesson check passed!'), findsOneWidget);
    expect(find.text('2/2 correct · 100%\n2 required to pass'), findsOneWidget);
    expect(find.text('Lesson unlocked: Introducing yourself'), findsOneWidget);
    expect(learnerApi.checkpointSubmitCallCount, 1);
    await tester.tap(find.text('Continue to module'));
    await tester.pumpAndSettle();

    expect(find.text('Introducing yourself'), findsOneWidget);
    expect(find.text('Ready to learn'), findsOneWidget);

    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Sign out'));
    await tester.pump();

    expect(auth.didSignOut, isTrue);
  });
}

class FakeAuthService implements AuthService {
  FakeAuthService({AppUser? initialUser}) {
    _controller.add(initialUser);
  }

  final _controller = StreamController<AppUser?>();

  String? lastEmail;
  String? lastPassword;
  String? passwordResetEmail;
  bool didSignOut = false;

  @override
  Stream<AppUser?> authStateChanges() => _controller.stream;

  @override
  Future<String?> getIdToken() async => 'test-token';

  @override
  Future<void> createAccount({
    required String email,
    required String password,
  }) async {
    lastEmail = email;
    lastPassword = password;
  }

  @override
  Future<void> sendPasswordResetEmail({required String email}) async {
    passwordResetEmail = email;
  }

  @override
  Future<void> signIn({required String email, required String password}) async {
    lastEmail = email;
    lastPassword = password;
  }

  @override
  Future<void> signOut() async {
    didSignOut = true;
    _controller.add(null);
  }

  Future<void> dispose() => _controller.close();
}

class FakeLearnerApi implements LearnerApi {
  int profileCallCount = 0;
  int modulesCallCount = 0;
  int recommendationCallCount = 0;
  int lessonsCallCount = 0;
  int lessonWordsCallCount = 0;
  int quizBatchCallCount = 0;
  int reviewCallCount = 0;
  int checkpointStartCallCount = 0;
  int checkpointSubmitCallCount = 0;
  bool checkpointPassed = false;

  @override
  Future<BackendUser> getCurrentUser() async {
    profileCallCount++;
    return const BackendUser(id: 1, username: 'test-learner', isOwner: false);
  }

  @override
  Future<List<CourseModule>> getModules() async {
    modulesCallCount++;
    return const [
      CourseModule(
        id: '01_first_conversations',
        title: 'First Conversations',
        fileName: '01_first_conversations.md',
        moduleOrder: 1,
        description: 'Start speaking Finnish.',
      ),
      CourseModule(
        id: '02_everyday_essentials',
        title: 'Everyday Essentials',
        fileName: '02_everyday_essentials.md',
        moduleOrder: 2,
        description: 'Useful everyday Finnish.',
      ),
    ];
  }

  @override
  Future<HomeRecommendation> getHomeRecommendation() async {
    recommendationCallCount++;
    return HomeRecommendation(
      dueCount: 2,
      nextLesson: HomeLesson(
        id: checkpointPassed ? 'lesson-2' : 'lesson-1',
        moduleId: '01_first_conversations',
        title: checkpointPassed ? 'Introducing yourself' : 'Greetings',
      ),
      courseComplete: false,
      progress: CourseProgress(
        totalModules: 8,
        completedModules: 1,
        lessonChecksPassed: checkpointPassed ? 5 : 4,
        practicingWords: 12,
        masteredWords: 7,
      ),
    );
  }

  @override
  Future<List<CourseLesson>> getLessons() async {
    lessonsCallCount++;
    return [
      CourseLesson(
        id: 'lesson-1',
        moduleId: '01_first_conversations',
        title: 'Greetings',
        fileName: 'lesson-1.md',
        heading: 'Greetings',
        sectionOrder: 1,
        description: 'Say hello in Finnish.',
        totalWords: 4,
        newWords: 2,
        practicingWords: 1,
        masteredWords: 1,
        sections: [
          LessonSection(
            heading: 'Useful phrases',
            content: '**Hei!**\n\n- Say hello\n- Introduce yourself',
            sectionOrder: 1,
          ),
        ],
        locked: false,
        checkpointPassed: checkpointPassed,
      ),
      CourseLesson(
        id: 'lesson-2',
        moduleId: '01_first_conversations',
        title: 'Introducing yourself',
        fileName: 'lesson-2.md',
        heading: 'Introducing yourself',
        sectionOrder: 2,
        description: 'Share your name.',
        totalWords: 3,
        newWords: 3,
        practicingWords: 0,
        masteredWords: 0,
        sections: [],
        locked: !checkpointPassed,
        checkpointPassed: false,
      ),
      CourseLesson(
        id: 'lesson-3',
        moduleId: '02_everyday_essentials',
        title: 'Numbers',
        fileName: 'lesson-3.md',
        heading: 'Numbers',
        sectionOrder: 3,
        description: 'Count in Finnish.',
        totalWords: 5,
        newWords: 5,
        practicingWords: 0,
        masteredWords: 0,
        sections: [],
        locked: true,
        checkpointPassed: false,
      ),
    ];
  }

  @override
  Future<List<LessonWord>> getLessonWords(String lessonId) async {
    lessonWordsCallCount++;
    return const [
      LessonWord(
        word: 'kauppa',
        translations: ['shop', 'store'],
        score: 0,
        sourceLessonId: null,
        isPersonal: false,
      ),
      LessonWord(
        word: 'hei',
        translations: ['hello'],
        score: 3,
        sourceLessonId: null,
        isPersonal: false,
      ),
    ];
  }

  @override
  Future<List<LessonWord>> getLessonQuizBatch(String lessonId) async {
    quizBatchCallCount++;
    return const [
      LessonWord(
        word: 'kauppa',
        translations: ['shop', 'store'],
        score: 0,
        sourceLessonId: 'lesson-1',
        isPersonal: false,
      ),
      LessonWord(
        word: 'hei',
        translations: ['hello'],
        score: 3,
        sourceLessonId: 'lesson-1',
        isPersonal: false,
      ),
    ];
  }

  @override
  Future<WordReviewResult> reviewLessonWord({
    required String lessonId,
    required String word,
    required bool correct,
  }) async {
    reviewCallCount++;
    return WordReviewResult(
      word: word,
      correct: correct,
      score: correct ? 1 : 0,
      scoreIncreased: correct,
      lastIncreasedAt: correct ? DateTime.utc(2026, 11, 10, 15, 20) : null,
      dueAt: DateTime.utc(2026, 11, 10, 15, 30),
    );
  }

  @override
  Future<CheckpointSession> startCheckpoint(String lessonId) async {
    checkpointStartCallCount++;
    return const CheckpointSession(
      sessionId: 'checkpoint-session',
      requiredCorrect: 2,
      questions: [
        CheckpointQuestion(
          id: '1',
          prompt: 'kauppa',
          options: ['shop / store', 'bread'],
          translation: '',
        ),
        CheckpointQuestion(
          id: '2',
          prompt: 'Tarvitsen ___.',
          options: ['leipää', 'pussi'],
          translation: 'I need bread.',
        ),
      ],
    );
  }

  @override
  Future<CheckpointResult> submitCheckpoint({
    required String lessonId,
    required String sessionId,
    required Map<String, String> answers,
  }) async {
    checkpointSubmitCallCount++;
    checkpointPassed = true;
    return const CheckpointResult(
      passed: true,
      correct: 2,
      total: 2,
      requiredCorrect: 2,
      missed: [],
      unlockedMessage: 'Lesson unlocked: Introducing yourself',
    );
  }
}
