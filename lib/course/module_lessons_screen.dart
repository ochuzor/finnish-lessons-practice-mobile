import 'package:flutter/material.dart';

import '../api/learner_api.dart';
import 'lesson_screen.dart';

class ModuleLessonsScreen extends StatefulWidget {
  const ModuleLessonsScreen({
    required this.module,
    required this.learnerApi,
    required this.initialLessons,
    super.key,
  });

  final CourseModule module;
  final LearnerApi learnerApi;
  final List<CourseLesson> initialLessons;

  @override
  State<ModuleLessonsScreen> createState() => _ModuleLessonsScreenState();
}

class _ModuleLessonsScreenState extends State<ModuleLessonsScreen> {
  bool _isLoading = false;
  String? _error;
  List<CourseLesson>? _lessons;

  @override
  void initState() {
    super.initState();
    _lessons = List<CourseLesson>.of(widget.initialLessons)
      ..sort((left, right) => left.sectionOrder.compareTo(right.sectionOrder));
  }

  Future<void> _loadLessons() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final allLessons = await widget.learnerApi.getLessons();
      final moduleLessons =
          allLessons
              .where((lesson) => lesson.moduleId == widget.module.id)
              .toList(growable: false)
            ..sort(
              (left, right) => left.sectionOrder.compareTo(right.sectionOrder),
            );
      if (mounted) setState(() => _lessons = moduleLessons);
    } on LearnerApiException catch (error) {
      if (mounted) setState(() => _error = error.detail);
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not load this module.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.module.title)),
      body: SafeArea(child: _buildBody(context)),
    );
  }

  Widget _buildBody(BuildContext context) {
    final lessons = _lessons;
    if (_isLoading && lessons == null) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading lessons…'),
          ],
        ),
      );
    }

    if (_error != null && lessons == null) {
      return _ModuleError(message: _error!, onRetry: _loadLessons);
    }

    final visibleLessons = lessons ?? const <CourseLesson>[];
    return RefreshIndicator(
      onRefresh: _loadLessons,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          _ModuleHeader(module: widget.module, lessons: visibleLessons),
          if (_error != null) ...[
            const SizedBox(height: 16),
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          const SizedBox(height: 22),
          Text(
            'Lessons',
            style: Theme.of(context).textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          if (visibleLessons.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Text('No lessons are available in this module yet.'),
              ),
            )
          else
            for (var index = 0; index < visibleLessons.length; index++)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _LessonCard(
                  lesson: visibleLessons[index],
                  displayNumber: index + 1,
                  onOpen: visibleLessons[index].locked
                      ? null
                      : () async {
                          final progressChanged = await Navigator.of(context)
                              .push<bool>(
                                MaterialPageRoute<bool>(
                                  builder: (_) => UnlockedLessonScreen(
                                    lesson: visibleLessons[index],
                                    learnerApi: widget.learnerApi,
                                  ),
                                ),
                              );
                          if (progressChanged == true && mounted) {
                            await _loadLessons();
                          }
                        },
                ),
              ),
        ],
      ),
    );
  }
}

class _ModuleHeader extends StatelessWidget {
  const _ModuleHeader({required this.module, required this.lessons});

  final CourseModule module;
  final List<CourseLesson> lessons;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final completed = lessons.where((lesson) => lesson.checkpointPassed).length;
    final totalWords = lessons.fold<int>(
      0,
      (total, lesson) => total + lesson.totalWords,
    );
    final masteredWords = lessons.fold<int>(
      0,
      (total, lesson) => total + lesson.masteredWords,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Module ${module.moduleOrder}',
          style: theme.textTheme.labelLarge?.copyWith(
            color: theme.colorScheme.primary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          module.title,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        if (module.description.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            module.description,
            style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
        const SizedBox(height: 16),
        Card(
          color: theme.colorScheme.secondaryContainer,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: _SummaryValue(
                    value: '$completed/${lessons.length}',
                    label: 'Checks passed',
                  ),
                ),
                Container(
                  width: 1,
                  height: 42,
                  color: theme.colorScheme.outlineVariant,
                ),
                Expanded(
                  child: _SummaryValue(
                    value: '$masteredWords/$totalWords',
                    label: 'Words mastered',
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _SummaryValue extends StatelessWidget {
  const _SummaryValue({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      children: [
        Text(
          value,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: colors.onSecondaryContainer,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(color: colors.onSecondaryContainer),
        ),
      ],
    );
  }
}

class _LessonCard extends StatelessWidget {
  const _LessonCard({
    required this.lesson,
    required this.displayNumber,
    required this.onOpen,
  });

  final CourseLesson lesson;
  final int displayNumber;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = _lessonState();
    return Card(
      color: lesson.locked
          ? theme.colorScheme.surfaceContainerHighest
          : theme.colorScheme.surface,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                backgroundColor: state.background,
                foregroundColor: state.foreground,
                child: Icon(state.icon, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Lesson $displayNumber',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      lesson.title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (lesson.description.isNotEmpty) ...[
                      const SizedBox(height: 5),
                      Text(
                        lesson.description,
                        style: TextStyle(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                    const SizedBox(height: 10),
                    Text(
                      state.label,
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: state.foreground,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (lesson.totalWords > 0) ...[
                      const SizedBox(height: 4),
                      Text(
                        '${lesson.masteredWords} mastered · '
                        '${lesson.practicingWords} practicing · '
                        '${lesson.newWords} new',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ],
                ),
              ),
              if (onOpen != null) ...[
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

  _LessonVisualState _lessonState() {
    if (lesson.checkpointPassed) {
      return const _LessonVisualState(
        icon: Icons.check_rounded,
        label: 'Lesson check passed',
        background: Color(0xFFD8EDE5),
        foreground: Color(0xFF205B48),
      );
    }
    if (lesson.locked) {
      return const _LessonVisualState(
        icon: Icons.lock_outline_rounded,
        label: 'Locked · pass the previous lesson check',
        background: Color(0xFFE6E8E6),
        foreground: Color(0xFF5E635F),
      );
    }
    return const _LessonVisualState(
      icon: Icons.play_arrow_rounded,
      label: 'Ready to learn',
      background: Color(0xFFDCE8F6),
      foreground: Color(0xFF28537A),
    );
  }
}

class _LessonVisualState {
  const _LessonVisualState({
    required this.icon,
    required this.label,
    required this.background,
    required this.foreground,
  });

  final IconData icon;
  final String label;
  final Color background;
  final Color foreground;
}

class _ModuleError extends StatelessWidget {
  const _ModuleError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.menu_book_outlined,
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
