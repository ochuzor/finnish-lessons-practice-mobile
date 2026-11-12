import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../api/learner_api.dart';
import '../course/global_vocabulary_review_screen.dart';
import '../course/lesson_screen.dart';
import '../course/module_lessons_screen.dart';
import '../vocabulary/personal_vocabulary_screen.dart';
import 'auth_service.dart';

class SignedInScreen extends StatefulWidget {
  const SignedInScreen({
    required this.auth,
    required this.learnerApi,
    required this.email,
    required this.enableBackendProfile,
    super.key,
  });

  final AuthService auth;
  final LearnerApi learnerApi;
  final String? email;
  final bool enableBackendProfile;

  @override
  State<SignedInScreen> createState() => _SignedInScreenState();
}

class _SignedInScreenState extends State<SignedInScreen> {
  bool _isSigningOut = false;
  bool _isHomeLoading = false;
  BackendUser? _backendUser;
  HomeRecommendation? _recommendation;
  List<CourseModule> _modules = const [];
  List<CourseLesson> _lessons = const [];
  String? _homeError;
  String? _signOutError;

  @override
  void initState() {
    super.initState();
    if (widget.enableBackendProfile) _loadHome();
  }

  Future<void> _loadHome() async {
    setState(() {
      _isHomeLoading = true;
      _homeError = null;
    });

    try {
      final results = await Future.wait<Object>([
        widget.learnerApi.getCurrentUser(),
        widget.learnerApi.getModules(),
        widget.learnerApi.getHomeRecommendation(),
        widget.learnerApi.getLessons(),
      ]);
      if (!mounted) return;
      setState(() {
        _backendUser = results[0] as BackendUser;
        _modules = results[1] as List<CourseModule>;
        _recommendation = results[2] as HomeRecommendation;
        _lessons = results[3] as List<CourseLesson>;
      });
    } on LearnerApiException catch (error) {
      if (mounted) setState(() => _homeError = error.detail);
    } catch (_) {
      if (mounted) {
        setState(() => _homeError = 'Could not load your course overview.');
      }
    } finally {
      if (mounted) setState(() => _isHomeLoading = false);
    }
  }

  Future<void> _signOut() async {
    setState(() {
      _isSigningOut = true;
      _signOutError = null;
    });

    try {
      await widget.auth.signOut();
    } on FirebaseAuthException catch (error) {
      if (mounted) {
        setState(() {
          _signOutError =
              error.message ?? 'Could not sign out. Please try again.';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _signOutError = 'Could not sign out. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _isSigningOut = false);
    }
  }

  Future<void> _openGlobalReview() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            GlobalVocabularyReviewScreen(learnerApi: widget.learnerApi),
      ),
    );
    if (mounted) await _loadHome();
  }

  Future<void> _openPersonalVocabulary() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PersonalVocabularyScreen(learnerApi: widget.learnerApi),
      ),
    );
    if (mounted) await _loadHome();
  }

  Future<void> _openRecommendedLesson(HomeLesson recommendation) async {
    CourseLesson? lesson = _lessonById(recommendation.id);
    if (lesson == null || lesson.locked) {
      await _loadHome();
      if (!mounted) return;
      lesson = _lessonById(recommendation.id);
    }

    if (lesson == null) {
      setState(() {
        _homeError = 'The recommended lesson is no longer available.';
      });
      return;
    }
    if (lesson.locked) {
      setState(() {
        _homeError = 'The recommended lesson is not unlocked yet.';
      });
      return;
    }

    await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => UnlockedLessonScreen(
          lesson: lesson!,
          learnerApi: widget.learnerApi,
        ),
      ),
    );
    if (mounted) await _loadHome();
  }

  CourseLesson? _lessonById(String id) {
    for (final lesson in _lessons) {
      if (lesson.id == id) return lesson;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Finnish Lessons'),
        actions: [
          if (_isSigningOut)
            const Padding(
              padding: EdgeInsets.all(14),
              child: SizedBox.square(
                dimension: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            IconButton(
              onPressed: _signOut,
              tooltip: 'Sign out',
              icon: const Icon(Icons.logout_rounded),
            ),
        ],
      ),
      body: SafeArea(child: _buildBody(context)),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (!widget.enableBackendProfile) {
      return _WebBackendNotice(email: widget.email);
    }

    if (_isHomeLoading && _recommendation == null) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading your course…'),
          ],
        ),
      );
    }

    if (_homeError != null && _recommendation == null) {
      return _HomeError(message: _homeError!, onRetry: _loadHome);
    }

    final recommendation = _recommendation;
    final backendUser = _backendUser;
    if (recommendation == null || backendUser == null) {
      return const SizedBox.shrink();
    }
    final recommendedLesson = recommendation.nextLesson;

    return RefreshIndicator(
      onRefresh: _loadHome,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          _WelcomeHeader(username: backendUser.username, email: widget.email),
          if (_homeError != null) ...[
            const SizedBox(height: 16),
            _InlineError(message: _homeError!, onRetry: _loadHome),
          ],
          const SizedBox(height: 20),
          _RecommendationCard(
            recommendation: recommendation,
            onTap: recommendation.dueCount > 0
                ? _openGlobalReview
                : recommendedLesson != null
                ? () => _openRecommendedLesson(recommendedLesson)
                : null,
          ),
          const SizedBox(height: 24),
          _ProgressSection(progress: recommendation.progress),
          const SizedBox(height: 28),
          _PersonalVocabularyCard(onTap: _openPersonalVocabulary),
          const SizedBox(height: 28),
          _ModulesSection(
            modules: _modules,
            lessons: _lessons,
            onSelect: (module, lessons) async {
              await Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => ModuleLessonsScreen(
                    module: module,
                    learnerApi: widget.learnerApi,
                    initialLessons: lessons,
                  ),
                ),
              );
              if (mounted) await _loadHome();
            },
          ),
          if (_signOutError != null) ...[
            const SizedBox(height: 20),
            Text(
              _signOutError!,
              textAlign: TextAlign.center,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
        ],
      ),
    );
  }
}

class _WebBackendNotice extends StatelessWidget {
  const _WebBackendNotice({required this.email});

  final String? email;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                children: [
                  const Icon(Icons.phone_android_rounded, size: 48),
                  const SizedBox(height: 18),
                  Text(
                    'Signed in${email?.isNotEmpty == true ? ' as $email' : ''}',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Open the app on your Android device to load your course and progress. Chrome backend calls are disabled during development because of CORS.',
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _WelcomeHeader extends StatelessWidget {
  const _WelcomeHeader({required this.username, required this.email});

  final String username;
  final String? email;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Tervetuloa, $username!',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Choose a module or follow your recommended next step.',
          style: theme.textTheme.bodyLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Icon(
              Icons.cloud_done_outlined,
              size: 18,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Progress connected${email?.isNotEmpty == true ? ' · $email' : ''}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _RecommendationCard extends StatelessWidget {
  const _RecommendationCard({required this.recommendation, this.onTap});

  final HomeRecommendation recommendation;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (icon, title, message) = _content();
    return Card(
      color: theme.colorScheme.primaryContainer,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 32, color: theme.colorScheme.onPrimaryContainer),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Recommended next',
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: theme.colorScheme.onPrimaryContainer,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      title,
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: theme.colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      message,
                      style: TextStyle(
                        color: theme.colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ],
                ),
              ),
              if (onTap != null) ...[
                const SizedBox(width: 8),
                Icon(
                  Icons.chevron_right_rounded,
                  color: theme.colorScheme.onPrimaryContainer,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  (IconData, String, String) _content() {
    if (recommendation.dueCount > 0) {
      final count = recommendation.dueCount;
      return (
        Icons.replay_circle_filled_rounded,
        'Review vocabulary',
        '$count ${count == 1 ? 'word is' : 'words are'} ready to review.',
      );
    }
    if (recommendation.courseComplete) {
      return (
        Icons.emoji_events_rounded,
        'Course complete',
        'Excellent work—keep your Finnish fresh with regular review.',
      );
    }
    final lesson = recommendation.nextLesson;
    if (lesson != null) {
      return (
        Icons.play_lesson_rounded,
        lesson.title,
        'Continue with your next available lesson.',
      );
    }
    return (
      Icons.check_circle_rounded,
      'You are all caught up',
      'There is nothing due right now. Explore a module when you are ready.',
    );
  }
}

class _ProgressSection extends StatelessWidget {
  const _ProgressSection({required this.progress});

  final CourseProgress progress;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Your progress',
          style: Theme.of(context).textTheme.titleLarge
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            const gap = 6.0;
            final tileWidth = (constraints.maxWidth - gap) / 2;
            return Wrap(
              spacing: gap,
              runSpacing: gap,
              children: [
                _ProgressTile(
                  width: tileWidth,
                  value:
                      '${progress.completedModules}/${progress.totalModules}',
                  label: 'Modules complete',
                ),
                _ProgressTile(
                  width: tileWidth,
                  value: '${progress.lessonChecksPassed}',
                  label: 'Lesson checks passed',
                ),
                _ProgressTile(
                  width: tileWidth,
                  value: '${progress.practicingWords}',
                  label: 'Words in practice',
                ),
                _ProgressTile(
                  width: tileWidth,
                  value: '${progress.masteredWords}',
                  label: 'Words mastered',
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _ProgressTile extends StatelessWidget {
  const _ProgressTile({
    required this.width,
    required this.value,
    required this.label,
  });

  final double width;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: width,
      child: Card(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: theme.textTheme.headlineSmall?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(label, style: theme.textTheme.bodyMedium),
            ],
          ),
        ),
      ),
    );
  }
}

class _PersonalVocabularyCard extends StatelessWidget {
  const _PersonalVocabularyCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Keep learning',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        Card(
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: theme.colorScheme.secondaryContainer,
                    foregroundColor: theme.colorScheme.onSecondaryContainer,
                    child: const Icon(Icons.book_outlined),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'My vocabulary',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                        SizedBox(height: 3),
                        Text('Add and manage your own Finnish words.'),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ModulesSection extends StatelessWidget {
  const _ModulesSection({
    required this.modules,
    required this.lessons,
    required this.onSelect,
  });

  final List<CourseModule> modules;
  final List<CourseLesson> lessons;
  final void Function(CourseModule module, List<CourseLesson> lessons) onSelect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Course modules',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Complete lesson checks to unlock the next module.',
          style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 12),
        if (modules.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Text('No course modules are available yet.'),
            ),
          )
        else
          for (final module in modules)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _ModuleCard(
                module: module,
                lessons:
                    lessons
                        .where((lesson) => lesson.moduleId == module.id)
                        .toList(growable: false)
                      ..sort(
                        (left, right) =>
                            left.sectionOrder.compareTo(right.sectionOrder),
                      ),
                onSelect: onSelect,
              ),
            ),
      ],
    );
  }
}

class _ModuleCard extends StatelessWidget {
  const _ModuleCard({
    required this.module,
    required this.lessons,
    required this.onSelect,
  });

  final CourseModule module;
  final List<CourseLesson> lessons;
  final void Function(CourseModule module, List<CourseLesson> lessons) onSelect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isEmpty = lessons.isEmpty;
    final isLocked = !isEmpty && lessons.first.locked;
    final isComplete =
        !isEmpty && lessons.every((lesson) => lesson.checkpointPassed);
    final completed = lessons.where((lesson) => lesson.checkpointPassed).length;
    final canOpen = !isEmpty;

    return Card(
      color: isLocked || isEmpty
          ? theme.colorScheme.surfaceContainerHighest
          : theme.colorScheme.surface,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: canOpen ? () => onSelect(module, lessons) : null,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                backgroundColor: isLocked || isEmpty
                    ? theme.colorScheme.surfaceContainerHigh
                    : theme.colorScheme.secondaryContainer,
                foregroundColor: isLocked || isEmpty
                    ? theme.colorScheme.onSurfaceVariant
                    : theme.colorScheme.onSecondaryContainer,
                child: isLocked
                    ? const Icon(Icons.lock_outline_rounded, size: 20)
                    : isComplete
                    ? const Icon(Icons.check_rounded, size: 20)
                    : Text('${module.moduleOrder}'),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      module.title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (module.description.isNotEmpty) ...[
                      const SizedBox(height: 5),
                      Text(
                        module.description,
                        style: TextStyle(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Text(
                      isEmpty
                          ? 'No lessons available'
                          : isLocked
                          ? 'Locked · view locked lessons'
                          : isComplete
                          ? 'Module complete'
                          : '$completed/${lessons.length} lesson checks passed',
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: isLocked || isEmpty
                            ? theme.colorScheme.onSurfaceVariant
                            : theme.colorScheme.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              if (canOpen) ...[
                const SizedBox(width: 8),
                const Padding(
                  padding: EdgeInsets.only(top: 10),
                  child: Icon(Icons.chevron_right_rounded),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _HomeError extends StatelessWidget {
  const _HomeError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.cloud_off_rounded,
              size: 48,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}

class _InlineError extends StatelessWidget {
  const _InlineError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.errorContainer,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: colors.onErrorContainer),
            ),
          ),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}
