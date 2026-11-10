import 'dart:convert';

import 'package:http/http.dart' as http;

typedef IdTokenProvider = Future<String?> Function();

class BackendUser {
  const BackendUser({
    required this.id,
    required this.username,
    required this.isOwner,
  });

  factory BackendUser.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final username = json['username'];
    final isOwner = json['is_owner'];

    if (id is! int || username is! String || isOwner is! bool) {
      throw const FormatException(
        'The server returned an invalid user profile.',
      );
    }

    return BackendUser(id: id, username: username, isOwner: isOwner);
  }

  final int id;
  final String username;
  final bool isOwner;
}

class CourseModule {
  const CourseModule({
    required this.id,
    required this.title,
    required this.fileName,
    required this.moduleOrder,
    required this.description,
  });

  factory CourseModule.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final title = json['title'];
    final fileName = json['file_name'];
    final moduleOrder = json['module_order'];
    final description = json['description'];
    if (id is! String ||
        title is! String ||
        fileName is! String ||
        moduleOrder is! int ||
        description is! String) {
      throw const FormatException('The server returned an invalid module.');
    }

    return CourseModule(
      id: id,
      title: title,
      fileName: fileName,
      moduleOrder: moduleOrder,
      description: description,
    );
  }

  final String id;
  final String title;
  final String fileName;
  final int moduleOrder;
  final String description;
}

class HomeLesson {
  const HomeLesson({
    required this.id,
    required this.moduleId,
    required this.title,
  });

  factory HomeLesson.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final moduleId = json['module_id'];
    final title = json['title'];
    if (id is! String ||
        (moduleId != null && moduleId is! String) ||
        title is! String) {
      throw const FormatException(
        'The server returned an invalid lesson recommendation.',
      );
    }

    return HomeLesson(id: id, moduleId: moduleId as String?, title: title);
  }

  final String id;
  final String? moduleId;
  final String title;
}

class CourseProgress {
  const CourseProgress({
    required this.totalModules,
    required this.completedModules,
    required this.lessonChecksPassed,
    required this.practicingWords,
    required this.masteredWords,
  });

  factory CourseProgress.fromJson(Map<String, dynamic> json) {
    final values = [
      json['total_modules'],
      json['completed_modules'],
      json['lesson_checks_passed'],
      json['practicing_words'],
      json['mastered_words'],
    ];
    if (values.any((value) => value is! int)) {
      throw const FormatException(
        'The server returned an invalid progress summary.',
      );
    }

    return CourseProgress(
      totalModules: values[0]! as int,
      completedModules: values[1]! as int,
      lessonChecksPassed: values[2]! as int,
      practicingWords: values[3]! as int,
      masteredWords: values[4]! as int,
    );
  }

  final int totalModules;
  final int completedModules;
  final int lessonChecksPassed;
  final int practicingWords;
  final int masteredWords;
}

class HomeRecommendation {
  const HomeRecommendation({
    required this.dueCount,
    required this.nextLesson,
    required this.courseComplete,
    required this.progress,
  });

  factory HomeRecommendation.fromJson(Map<String, dynamic> json) {
    final dueCount = json['due_count'];
    final nextLesson = json['next_lesson'];
    final courseComplete = json['course_complete'];
    final progress = json['progress'];
    if (dueCount is! int ||
        (nextLesson != null && nextLesson is! Map<String, dynamic>) ||
        courseComplete is! bool ||
        progress is! Map<String, dynamic>) {
      throw const FormatException(
        'The server returned an invalid home recommendation.',
      );
    }

    return HomeRecommendation(
      dueCount: dueCount,
      nextLesson: nextLesson == null ? null : HomeLesson.fromJson(nextLesson),
      courseComplete: courseComplete,
      progress: CourseProgress.fromJson(progress),
    );
  }

  final int dueCount;
  final HomeLesson? nextLesson;
  final bool courseComplete;
  final CourseProgress progress;
}

class LessonSection {
  const LessonSection({
    required this.heading,
    required this.content,
    required this.sectionOrder,
  });

  factory LessonSection.fromJson(Map<String, dynamic> json) {
    final heading = json['heading'];
    final content = json['content'];
    final sectionOrder = json['section_order'];
    if (heading is! String || content is! String || sectionOrder is! int) {
      throw const FormatException(
        'The server returned an invalid lesson section.',
      );
    }
    return LessonSection(
      heading: heading,
      content: content,
      sectionOrder: sectionOrder,
    );
  }

  final String heading;
  final String content;
  final int sectionOrder;
}

class CourseLesson {
  const CourseLesson({
    required this.id,
    required this.moduleId,
    required this.title,
    required this.fileName,
    required this.heading,
    required this.sectionOrder,
    required this.description,
    required this.totalWords,
    required this.newWords,
    required this.practicingWords,
    required this.masteredWords,
    required this.sections,
    required this.locked,
    required this.checkpointPassed,
  });

  factory CourseLesson.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final moduleId = json['module_id'];
    final title = json['title'];
    final fileName = json['file_name'];
    final heading = json['heading'];
    final sectionOrder = json['section_order'];
    final description = json['description'];
    final totalWords = json['total_words'];
    final newWords = json['new_words'];
    final practicingWords = json['practicing_words'];
    final masteredWords = json['mastered_words'];
    final sections = json['sections'];
    final locked = json['locked'];
    final checkpointPassed = json['checkpoint_passed'];
    if (id is! String ||
        (moduleId != null && moduleId is! String) ||
        title is! String ||
        fileName is! String ||
        heading is! String ||
        sectionOrder is! int ||
        description is! String ||
        totalWords is! int ||
        newWords is! int ||
        practicingWords is! int ||
        masteredWords is! int ||
        sections is! List<dynamic> ||
        locked is! bool ||
        checkpointPassed is! bool) {
      throw const FormatException('The server returned an invalid lesson.');
    }

    return CourseLesson(
      id: id,
      moduleId: moduleId as String?,
      title: title,
      fileName: fileName,
      heading: heading,
      sectionOrder: sectionOrder,
      description: description,
      totalWords: totalWords,
      newWords: newWords,
      practicingWords: practicingWords,
      masteredWords: masteredWords,
      sections: sections
          .map((section) {
            if (section is! Map<String, dynamic>) {
              throw const FormatException(
                'The server returned an invalid lesson section.',
              );
            }
            return LessonSection.fromJson(section);
          })
          .toList(growable: false),
      locked: locked,
      checkpointPassed: checkpointPassed,
    );
  }

  final String id;
  final String? moduleId;
  final String title;
  final String fileName;
  final String heading;
  final int sectionOrder;
  final String description;
  final int totalWords;
  final int newWords;
  final int practicingWords;
  final int masteredWords;
  final List<LessonSection> sections;
  final bool locked;
  final bool checkpointPassed;
}

class LessonWord {
  const LessonWord({
    required this.word,
    required this.translations,
    required this.score,
    required this.sourceLessonId,
    required this.isPersonal,
  });

  factory LessonWord.fromJson(Map<String, dynamic> json) {
    final word = json['word'];
    final translations = json['translations'];
    final score = json['score'];
    final sourceLessonId = json['source_lesson_id'];
    final isPersonal = json['is_personal'];
    if (word is! String ||
        translations is! List<dynamic> ||
        translations.any((translation) => translation is! String) ||
        score is! int ||
        score < 0 ||
        score > 3 ||
        (sourceLessonId != null && sourceLessonId is! String) ||
        isPersonal is! bool) {
      throw const FormatException(
        'The server returned an invalid lesson word.',
      );
    }

    return LessonWord(
      word: word,
      translations: translations.cast<String>().toList(growable: false),
      score: score,
      sourceLessonId: sourceLessonId as String?,
      isPersonal: isPersonal,
    );
  }

  final String word;
  final List<String> translations;
  final int score;
  final String? sourceLessonId;
  final bool isPersonal;
}

abstract interface class LearnerApi {
  Future<BackendUser> getCurrentUser();
  Future<List<CourseModule>> getModules();
  Future<HomeRecommendation> getHomeRecommendation();
  Future<List<CourseLesson>> getLessons();
  Future<List<LessonWord>> getLessonWords(String lessonId);
}

class LearnerApiException implements Exception {
  const LearnerApiException(this.detail, {this.statusCode});

  final String detail;
  final int? statusCode;

  @override
  String toString() => detail;
}

class HttpLearnerApi implements LearnerApi {
  HttpLearnerApi({
    required String baseUrl,
    required this.idTokenProvider,
    http.Client? client,
  }) : _baseUrl = baseUrl.replaceAll(RegExp(r'/+$'), ''),
       _client = client ?? http.Client();

  final String _baseUrl;
  final IdTokenProvider idTokenProvider;
  final http.Client _client;

  @override
  Future<BackendUser> getCurrentUser() async {
    final response = await _get('/api/auth/me');
    if (response is! Map<String, dynamic>) {
      throw const LearnerApiException(
        'The server returned an invalid account response.',
      );
    }
    final user = response['user'];
    if (user is! Map<String, dynamic>) {
      throw const LearnerApiException(
        'The server returned an invalid account response.',
      );
    }

    try {
      return BackendUser.fromJson(user);
    } on FormatException catch (error) {
      throw LearnerApiException(error.message);
    }
  }

  @override
  Future<List<CourseModule>> getModules() async {
    final response = await _get('/api/modules');
    if (response is! List<dynamic>) {
      throw const LearnerApiException(
        'The server returned an invalid module list.',
      );
    }

    try {
      return response
          .map((item) {
            if (item is! Map<String, dynamic>) {
              throw const FormatException(
                'The server returned an invalid module.',
              );
            }
            return CourseModule.fromJson(item);
          })
          .toList(growable: false);
    } on FormatException catch (error) {
      throw LearnerApiException(error.message);
    }
  }

  @override
  Future<HomeRecommendation> getHomeRecommendation() async {
    final response = await _get('/api/home/recommendation');
    if (response is! Map<String, dynamic>) {
      throw const LearnerApiException(
        'The server returned an invalid home recommendation.',
      );
    }

    try {
      return HomeRecommendation.fromJson(response);
    } on FormatException catch (error) {
      throw LearnerApiException(error.message);
    }
  }

  @override
  Future<List<CourseLesson>> getLessons() async {
    final response = await _get('/api/lessons');
    if (response is! List<dynamic>) {
      throw const LearnerApiException(
        'The server returned an invalid lesson list.',
      );
    }

    try {
      return response
          .map((item) {
            if (item is! Map<String, dynamic>) {
              throw const FormatException(
                'The server returned an invalid lesson.',
              );
            }
            return CourseLesson.fromJson(item);
          })
          .toList(growable: false);
    } on FormatException catch (error) {
      throw LearnerApiException(error.message);
    }
  }

  @override
  Future<List<LessonWord>> getLessonWords(String lessonId) async {
    final encodedLessonId = Uri.encodeComponent(lessonId);
    final response = await _get('/api/lessons/$encodedLessonId/words');
    if (response is! List<dynamic>) {
      throw const LearnerApiException(
        'The server returned an invalid vocabulary list.',
      );
    }

    try {
      return response
          .map((item) {
            if (item is! Map<String, dynamic>) {
              throw const FormatException(
                'The server returned an invalid lesson word.',
              );
            }
            return LessonWord.fromJson(item);
          })
          .toList(growable: false);
    } on FormatException catch (error) {
      throw LearnerApiException(error.message);
    }
  }

  Future<Object?> _get(String path) async {
    if (_baseUrl.isEmpty) {
      throw const LearnerApiException(
        'API_BASE_URL is missing. Start the app with the production API URL.',
      );
    }

    final token = await idTokenProvider();
    if (token == null || token.isEmpty) {
      throw const LearnerApiException(
        'Your sign-in session is unavailable. Sign out and sign in again.',
      );
    }

    late http.Response response;
    try {
      response = await _client.get(
        Uri.parse('$_baseUrl$path'),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
    } on Exception {
      throw const LearnerApiException(
        'Could not reach the Finnish Lessons server. Check your connection and try again.',
      );
    }

    final body = _decodeJson(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final detail = body is Map<String, dynamic> ? body['detail'] : null;
      throw LearnerApiException(
        detail is String && detail.isNotEmpty
            ? detail
            : 'The server could not complete the request.',
        statusCode: response.statusCode,
      );
    }

    return body;
  }

  Object? _decodeJson(String source) {
    if (source.isEmpty) return const <String, dynamic>{};

    try {
      return jsonDecode(source);
    } on FormatException {
      throw const LearnerApiException(
        'The server returned an unreadable response.',
      );
    }
  }
}
