import 'dart:async';

import 'package:finnishlessons/api/learner_api.dart';
import 'package:finnishlessons/app.dart';
import 'package:finnishlessons/auth/auth_service.dart';
import 'package:finnishlessons/course/lesson_checkpoint_screen.dart';
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
    expect(find.text('Review vocabulary'), findsOneWidget);
    expect(find.text('2 words are ready to review.'), findsOneWidget);
    final modulesTile = tester.getTopLeft(find.text('Modules complete'));
    final checksTile = tester.getTopLeft(find.text('Lesson checks passed'));
    final practisingTile = tester.getTopLeft(find.text('Words in practice'));
    final masteredTile = tester.getTopLeft(find.text('Words mastered'));
    expect(checksTile.dx, greaterThan(modulesTile.dx));
    expect((checksTile.dy - modulesTile.dy).abs(), lessThan(2));
    expect(masteredTile.dx, greaterThan(practisingTile.dx));
    expect((masteredTile.dy - practisingTile.dy).abs(), lessThan(2));
    expect(practisingTile.dy, greaterThan(modulesTile.dy));
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

    await tester.ensureVisible(find.text('Everyday Essentials'));
    await tester.pumpAndSettle();
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

    expect(find.text('Choose the missing Finnish word'), findsOneWidget);
    expect(find.text('Olen ___.'), findsOneWidget);
    expect(find.text('I am in the shop.'), findsOneWidget);
    expect(find.text('1/2'), findsOneWidget);
    expect(learnerApi.quizBatchCallCount, 1);
    expect(learnerApi.lessonExercisesCallCount, 1);
    await tester.tap(find.text('kauppa'));
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
    await tester.drag(find.byType(Scrollable).last, const Offset(0, -120));
    await tester.pumpAndSettle();
    await tester.tap(find.text('leipää'));
    await tester.pump();
    await tester.scrollUntilVisible(
      find.text('Submit lesson check'),
      250,
      scrollable: find.byType(Scrollable).last,
    );
    final modulesBeforeCheckpointSubmit = learnerApi.modulesCallCount;
    final recommendationBeforeCheckpointSubmit =
        learnerApi.recommendationCallCount;
    await tester.tap(find.text('Submit lesson check'));
    await tester.pumpAndSettle();

    expect(find.text('Lesson unlocked!'), findsOneWidget);
    expect(
      find.text('You got 2 of 2 correct (100%).\nYou need 2 to pass.'),
      findsOneWidget,
    );
    expect(find.text('Lesson unlocked: Introducing yourself'), findsOneWidget);
    expect(learnerApi.checkpointSubmitCallCount, 1);
    expect(learnerApi.modulesCallCount, modulesBeforeCheckpointSubmit + 1);
    expect(
      learnerApi.recommendationCallCount,
      recommendationBeforeCheckpointSubmit + 1,
    );
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

  testWidgets('home recommendation runs global vocabulary review', (
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

    await tester.tap(find.text('Review vocabulary'));
    await tester.pumpAndSettle();

    expect(find.text('Review your vocabulary'), findsOneWidget);
    expect(learnerApi.practiceBatchCallCount, 0);
    await tester.tap(find.text('Start quiz'));
    await tester.pumpAndSettle();

    expect(find.text('Choose the English meaning'), findsOneWidget);
    expect(find.text('kauppa'), findsOneWidget);
    expect(learnerApi.practiceBatchCallCount, 1);
    expect(learnerApi.practiceWordsCallCount, 1);
    await tester.tap(find.text('shop / store'));
    await tester.pumpAndSettle();

    expect(find.text('Correct!'), findsOneWidget);
    expect(learnerApi.reviewCallCount, 1);
    await tester.tap(find.text('Next card'));
    await tester.pumpAndSettle();

    expect(find.text('Do you remember this word?'), findsOneWidget);
    expect(find.text('hei'), findsOneWidget);
    await tester.tap(find.text('Show answer'));
    await tester.pump();
    expect(find.text('hello'), findsOneWidget);
    await tester.tap(find.text('Recalled it'));
    await tester.pumpAndSettle();

    expect(find.text('Session complete'), findsOneWidget);
    expect(find.text('2 reviewed · 2 correct · 0 incorrect'), findsOneWidget);
    expect(learnerApi.personalReviewCallCount, 1);
    await tester.tap(find.text('Return home'));
    await tester.pumpAndSettle();

    expect(find.text('Review vocabulary'), findsOneWidget);
    expect(learnerApi.recommendationCallCount, 2);
  });

  testWidgets('home recommendation opens the next lesson when none are due', (
    tester,
  ) async {
    final auth = FakeAuthService(
      initialUser: const AppUser(email: 'me@example.com'),
    );
    addTearDown(auth.dispose);
    final learnerApi = FakeLearnerApi(homeDueCount: 0);

    await tester.pumpWidget(
      FinnishLessonsApp(auth: auth, learnerApi: learnerApi),
    );
    await tester.pumpAndSettle();

    expect(find.text('Greetings'), findsOneWidget);
    expect(
      find.text('Continue with your next available lesson.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Greetings'));
    await tester.pumpAndSettle();

    expect(find.text('Learn the pattern'), findsOneWidget);
    expect(find.text('Useful phrases'), findsOneWidget);
    expect(learnerApi.lessonWordsCallCount, 1);

    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();

    expect(find.text('Greetings'), findsOneWidget);
    expect(learnerApi.recommendationCallCount, 2);
  });

  testWidgets('personal vocabulary supports add, edit, and confirmed delete', (
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
    await tester.scrollUntilVisible(
      find.text('My vocabulary'),
      300,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.text('My vocabulary'));
    await tester.pumpAndSettle();

    expect(find.text('kirjasto'), findsOneWidget);
    expect(find.text('library'), findsOneWidget);
    expect(learnerApi.personalWordsCallCount, 1);

    await tester.tap(find.text('Add word'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Finnish word or phrase'),
      'sauna',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'English meanings'),
      'sauna, steam bath, sauna',
    );
    await tester.tap(find.text('Save word'));
    await tester.pumpAndSettle();

    expect(find.text('sauna'), findsOneWidget);
    expect(find.text('sauna, steam bath'), findsOneWidget);
    expect(learnerApi.createPersonalWordCallCount, 1);
    expect(learnerApi.lastPersonalTranslations, ['sauna', 'steam bath']);

    await tester.tap(find.byTooltip('Edit sauna'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Finnish word or phrase'),
      'saunat',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'English meanings'),
      'saunas',
    );
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();

    expect(find.text('saunat'), findsOneWidget);
    expect(find.text('saunas'), findsOneWidget);
    expect(learnerApi.updatePersonalWordCallCount, 1);

    await tester.tap(find.byTooltip('Remove saunat'));
    await tester.pumpAndSettle();
    expect(
      find.text('Remove ‘saunat’ and its practice history?'),
      findsOneWidget,
    );
    await tester.tap(find.text('Remove'));
    await tester.pumpAndSettle();

    expect(find.text('saunat'), findsNothing);
    expect(learnerApi.deletePersonalWordCallCount, 1);
    expect(learnerApi.personalWordsCallCount, 4);
  });

  testWidgets('lesson check requires every answer and shows failed review', (
    tester,
  ) async {
    final learnerApi = FakeLearnerApi(checkpointShouldPass: false);
    final lesson = (await learnerApi.getLessons()).first;

    await tester.pumpWidget(
      MaterialApp(
        home: LessonCheckpointScreen(lesson: lesson, learnerApi: learnerApi),
      ),
    );
    await tester.pumpAndSettle();

    ButtonStyleButton submitButton() => tester.widget<ButtonStyleButton>(
      find.ancestor(
        of: find.text('Submit lesson check'),
        matching: find.bySubtype<ButtonStyleButton>(),
      ),
    );

    await tester.scrollUntilVisible(
      find.text('Submit lesson check'),
      250,
      scrollable: find.byType(Scrollable),
    );
    expect(submitButton().onPressed, isNull);
    await tester.ensureVisible(find.text('shop / store'));
    await tester.tap(find.text('shop / store'));
    await tester.pump();
    await tester.ensureVisible(find.text('Submit lesson check'));
    expect(submitButton().onPressed, isNull);

    await tester.ensureVisible(find.text('pussi'));
    await tester.tap(find.text('pussi'));
    await tester.pump();
    await tester.ensureVisible(find.text('Submit lesson check'));
    expect(submitButton().onPressed, isNotNull);

    await tester.ensureVisible(find.text('Submit lesson check'));
    await tester.tap(find.text('Submit lesson check'));
    await tester.pumpAndSettle();

    expect(find.text('Keep practising'), findsOneWidget);
    expect(
      find.text('You got 1 of 2 correct (50%).\nYou need 2 to pass.'),
      findsOneWidget,
    );
    expect(find.text('Your answer: pussi'), findsOneWidget);
    expect(find.text('Correct answer: leipää'), findsOneWidget);
    expect(find.text('Practise this lesson'), findsOneWidget);
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
  FakeLearnerApi({this.checkpointShouldPass = true, this.homeDueCount = 2});

  final bool checkpointShouldPass;
  final int homeDueCount;
  int profileCallCount = 0;
  int modulesCallCount = 0;
  int recommendationCallCount = 0;
  int lessonsCallCount = 0;
  int lessonWordsCallCount = 0;
  int quizBatchCallCount = 0;
  int lessonExercisesCallCount = 0;
  int practiceBatchCallCount = 0;
  int practiceWordsCallCount = 0;
  int personalWordsCallCount = 0;
  int createPersonalWordCallCount = 0;
  int updatePersonalWordCallCount = 0;
  int deletePersonalWordCallCount = 0;
  int reviewCallCount = 0;
  int personalReviewCallCount = 0;
  int checkpointStartCallCount = 0;
  int checkpointSubmitCallCount = 0;
  bool checkpointPassed = false;
  List<String>? lastPersonalTranslations;
  final List<LessonWord> personalWords = [
    const LessonWord(
      word: 'kirjasto',
      translations: ['library'],
      score: 1,
      sourceLessonId: null,
      isPersonal: true,
    ),
  ];

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
      dueCount: homeDueCount,
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
  Future<List<LessonExercise>> getLessonExercises(String lessonId) async {
    lessonExercisesCallCount++;
    return const [
      LessonExercise(
        id: 'lesson-1-exercise-1',
        exerciseType: 'fill_in_blank',
        prompt: 'Olen ___.',
        answer: 'kauppa',
        options: ['kauppa', 'leipä'],
        translation: 'I am in the shop.',
        exerciseOrder: 1,
      ),
    ];
  }

  @override
  Future<List<LessonWord>> getPracticeQuizBatch() async {
    practiceBatchCallCount++;
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
        sourceLessonId: null,
        isPersonal: true,
      ),
    ];
  }

  @override
  Future<List<LessonWord>> getPracticeWords() async {
    practiceWordsCallCount++;
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
        sourceLessonId: null,
        isPersonal: true,
      ),
      LessonWord(
        word: 'leipä',
        translations: ['bread'],
        score: 2,
        sourceLessonId: 'lesson-1',
        isPersonal: false,
      ),
    ];
  }

  @override
  Future<List<LessonWord>> getPersonalWords() async {
    personalWordsCallCount++;
    return List<LessonWord>.of(personalWords);
  }

  @override
  Future<LessonWord> createPersonalWord({
    required String word,
    required List<String> translations,
  }) async {
    createPersonalWordCallCount++;
    lastPersonalTranslations = List<String>.of(translations);
    final created = LessonWord(
      word: word,
      translations: translations,
      score: 0,
      sourceLessonId: null,
      isPersonal: true,
    );
    personalWords.add(created);
    return created;
  }

  @override
  Future<LessonWord> updatePersonalWord({
    required String existingWord,
    required String word,
    required List<String> translations,
  }) async {
    updatePersonalWordCallCount++;
    final index = personalWords.indexWhere(
      (candidate) => candidate.word == existingWord,
    );
    final updated = LessonWord(
      word: word,
      translations: translations,
      score: existingWord == word ? personalWords[index].score : 0,
      sourceLessonId: null,
      isPersonal: true,
    );
    personalWords[index] = updated;
    return updated;
  }

  @override
  Future<void> deletePersonalWord(String word) async {
    deletePersonalWordCallCount++;
    personalWords.removeWhere((candidate) => candidate.word == word);
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
  Future<WordReviewResult> reviewPersonalWord({
    required String word,
    required bool correct,
  }) async {
    personalReviewCallCount++;
    return WordReviewResult(
      word: word,
      correct: correct,
      score: 3,
      scoreIncreased: false,
      lastIncreasedAt: DateTime.utc(2026, 11, 10, 15, 20),
      dueAt: DateTime.utc(2026, 11, 24, 15, 20),
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
    checkpointPassed = checkpointShouldPass;
    return CheckpointResult(
      passed: checkpointShouldPass,
      correct: checkpointShouldPass ? 2 : 1,
      total: 2,
      requiredCorrect: 2,
      missed: checkpointShouldPass
          ? const []
          : const [
              MissedCheckpointAnswer(
                prompt: 'Tarvitsen ___.',
                selected: 'pussi',
                correct: 'leipää',
              ),
            ],
      unlockedMessage: checkpointShouldPass
          ? 'Lesson unlocked: Introducing yourself'
          : null,
    );
  }
}
