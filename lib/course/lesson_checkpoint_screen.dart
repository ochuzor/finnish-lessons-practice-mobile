import 'package:flutter/material.dart';

import '../api/learner_api.dart';

class LessonCheckpointScreen extends StatefulWidget {
  LessonCheckpointScreen({
    required this.lesson,
    required this.learnerApi,
    super.key,
  }) : assert(!lesson.locked, 'Locked lessons cannot start a Lesson Check.');

  final CourseLesson lesson;
  final LearnerApi learnerApi;

  @override
  State<LessonCheckpointScreen> createState() => _LessonCheckpointScreenState();
}

class _LessonCheckpointScreenState extends State<LessonCheckpointScreen> {
  bool _isLoading = true;
  bool _isSubmitting = false;
  bool _submissionFailed = false;
  bool _canRetryStart = true;
  bool _lessonNowPassed = false;
  String? _error;
  String? _refreshWarning;
  CheckpointSession? _session;
  CheckpointResult? _result;
  final Map<String, String> _answers = {};

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    setState(() {
      _isLoading = true;
      _error = null;
      _session = null;
      _result = null;
      _answers.clear();
      _submissionFailed = false;
      _canRetryStart = true;
      _lessonNowPassed = false;
      _refreshWarning = null;
    });
    try {
      final session = await widget.learnerApi.startCheckpoint(widget.lesson.id);
      if (mounted) setState(() => _session = session);
    } on LearnerApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _canRetryStart = error.statusCode != 400 && error.statusCode != 403;
        _error = error.statusCode == 400
            ? 'This lesson does not have any Lesson Check questions yet.'
            : error.detail;
      });
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Could not prepare the Lesson Check.');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _submit() async {
    final session = _session;
    if (session == null ||
        _isSubmitting ||
        _submissionFailed ||
        _answers.length != session.questions.length) {
      return;
    }
    setState(() {
      _isSubmitting = true;
      _error = null;
    });
    try {
      final result = await widget.learnerApi.submitCheckpoint(
        lessonId: widget.lesson.id,
        sessionId: session.sessionId,
        answers: Map<String, String>.of(_answers),
      );
      String? refreshWarning;
      try {
        await Future.wait([
          widget.learnerApi.getLessons(),
          widget.learnerApi.getModules(),
          widget.learnerApi.getHomeRecommendation(),
        ]);
      } catch (_) {
        refreshWarning =
            'Your result was saved, but progress could not be refreshed yet.';
      }
      if (mounted) {
        setState(() {
          _result = result;
          _refreshWarning = refreshWarning;
          _isSubmitting = false;
        });
      }
    } on LearnerApiException catch (error) {
      await _handleSubmitFailure(error.detail);
    } catch (_) {
      await _handleSubmitFailure('Could not confirm your Lesson Check result.');
    }
  }

  Future<void> _handleSubmitFailure(String message) async {
    var lessonNowPassed = false;
    try {
      final lessons = await widget.learnerApi.getLessons();
      lessonNowPassed = lessons.any(
        (lesson) => lesson.id == widget.lesson.id && lesson.checkpointPassed,
      );
      await Future.wait([
        widget.learnerApi.getModules(),
        widget.learnerApi.getHomeRecommendation(),
      ]);
    } catch (_) {
      // The original submit error remains the most useful message.
    }
    if (!mounted) return;
    setState(() {
      _error = message;
      _isSubmitting = false;
      _submissionFailed = true;
      _lessonNowPassed = lessonNowPassed;
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_isSubmitting,
      child: Scaffold(
        appBar: AppBar(title: const Text('Lesson Check')),
        body: SafeArea(child: _buildBody(context)),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Preparing lesson check…'),
          ],
        ),
      );
    }
    if (_result != null) {
      return _ResultView(result: _result!, refreshWarning: _refreshWarning);
    }
    if (_session == null) {
      return _CheckpointMessage(
        icon: Icons.fact_check_outlined,
        title: 'Lesson Check unavailable',
        message: _error ?? 'Could not prepare the Lesson Check.',
        actionLabel: _canRetryStart ? 'Try again' : 'Return to lesson',
        onAction: _canRetryStart
            ? _start
            : () => Navigator.of(context).pop(false),
      );
    }
    if (_submissionFailed) {
      if (_lessonNowPassed) {
        return _CheckpointMessage(
          icon: Icons.celebration_outlined,
          title: 'Lesson unlocked!',
          message: 'The submission response was interrupted, but refreshed course progress confirms that this Lesson Check was passed.',
          actionLabel: 'Continue to module',
          onAction: () => Navigator.of(context).pop(true),
        );
      }
      return _CheckpointMessage(
        icon: Icons.cloud_off_outlined,
        title: 'Result could not be confirmed',
        message:
            '${_error ?? 'The submission could not be confirmed.'}\n\nThe server may have processed it, so this attempt will not be submitted again.',
        actionLabel: 'Start a new attempt',
        onAction: _start,
      );
    }
    return _buildQuestions(_session!);
  }

  Widget _buildQuestions(CheckpointSession session) {
    final answered = _answers.length;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      children: [
        Text(
          widget.lesson.title,
          style: Theme.of(context).textTheme.headlineSmall
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        Text(
          'Answer all ${session.questions.length} questions. '
          '${session.requiredCorrect} correct answers are required to pass.',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 16),
        LinearProgressIndicator(
          value: answered / session.questions.length,
          minHeight: 8,
          borderRadius: BorderRadius.circular(99),
        ),
        const SizedBox(height: 6),
        Text('$answered/${session.questions.length} answered'),
        const SizedBox(height: 20),
        for (var index = 0; index < session.questions.length; index++)
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: _QuestionCard(
              number: index + 1,
              question: session.questions[index],
              selected: _answers[session.questions[index].id],
              enabled: !_isSubmitting,
              onSelected: (option) {
                setState(() => _answers[session.questions[index].id] = option);
              },
            ),
          ),
        FilledButton.icon(
          onPressed: answered == session.questions.length && !_isSubmitting
              ? _submit
              : null,
          icon: _isSubmitting
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.fact_check_outlined),
          label: Text(_isSubmitting ? 'Submitting…' : 'Submit lesson check'),
        ),
      ],
    );
  }
}

class _QuestionCard extends StatelessWidget {
  const _QuestionCard({
    required this.number,
    required this.question,
    required this.selected,
    required this.enabled,
    required this.onSelected,
  });

  final int number;
  final CheckpointQuestion question;
  final String? selected;
  final bool enabled;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Question $number',
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              question.prompt,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            if (question.translation.isNotEmpty) ...[
              const SizedBox(height: 5),
              Text(
                question.translation,
                style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
              ),
            ],
            const SizedBox(height: 16),
            for (final option in question.options)
              Padding(
                padding: const EdgeInsets.only(bottom: 9),
                child: OutlinedButton.icon(
                  onPressed: enabled ? () => onSelected(option) : null,
                  icon: Icon(
                    selected == option
                        ? Icons.radio_button_checked_rounded
                        : Icons.radio_button_unchecked_rounded,
                  ),
                  label: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(option),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 13,
                    ),
                    backgroundColor: selected == option
                        ? theme.colorScheme.primaryContainer
                        : null,
                    foregroundColor: selected == option
                        ? theme.colorScheme.onPrimaryContainer
                        : null,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ResultView extends StatelessWidget {
  const _ResultView({required this.result, required this.refreshWarning});

  final CheckpointResult result;
  final String? refreshWarning;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final percent = (result.correct / result.total * 100).round();
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 36),
      children: [
        Icon(
          result.passed ? Icons.celebration_outlined : Icons.school_outlined,
          size: 58,
          color: result.passed
              ? const Color(0xFF205B48)
              : theme.colorScheme.primary,
        ),
        const SizedBox(height: 12),
        Text(
          result.passed ? 'Lesson unlocked!' : 'Keep practising',
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'You got ${result.correct} of ${result.total} correct ($percent%).\n'
          'You need ${result.requiredCorrect} to pass.',
          textAlign: TextAlign.center,
        ),
        if (result.unlockedMessage != null &&
            result.unlockedMessage!.isNotEmpty) ...[
          const SizedBox(height: 14),
          Card(
            color: theme.colorScheme.secondaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                result.unlockedMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
        if (refreshWarning != null) ...[
          const SizedBox(height: 12),
          Text(
            refreshWarning!,
            textAlign: TextAlign.center,
            style: TextStyle(color: theme.colorScheme.error),
          ),
        ],
        if (result.missed.isNotEmpty) ...[
          const SizedBox(height: 24),
          Text(
            'Review missed answers',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          for (final missed in result.missed)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      missed.prompt,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 7),
                    Text('Your answer: ${missed.selected}'),
                    Text('Correct answer: ${missed.correct}'),
                  ],
                ),
              ),
            ),
        ],
        const SizedBox(height: 20),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(result.passed),
          child: Text(
            result.passed ? 'Continue to module' : 'Practise this lesson',
          ),
        ),
      ],
    );
  }
}

class _CheckpointMessage extends StatelessWidget {
  const _CheckpointMessage({
    required this.icon,
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 18),
            FilledButton(onPressed: onAction, child: Text(actionLabel)),
          ],
        ),
      ),
    );
  }
}
