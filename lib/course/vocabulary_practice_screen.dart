import 'dart:math';

import 'package:flutter/material.dart';

import '../api/learner_api.dart';

class VocabularyPracticeScreen extends StatefulWidget {
  VocabularyPracticeScreen({
    required this.lesson,
    required this.lessonWords,
    required this.learnerApi,
    super.key,
  }) : assert(!lesson.locked, 'Locked lessons must not be practised.');

  final CourseLesson lesson;
  final List<LessonWord> lessonWords;
  final LearnerApi learnerApi;

  @override
  State<VocabularyPracticeScreen> createState() =>
      _VocabularyPracticeScreenState();
}

class _VocabularyPracticeScreenState extends State<VocabularyPracticeScreen> {
  bool _isLoading = true;
  String? _loadError;
  List<LessonWord> _cards = const [];
  Map<String, LessonExercise> _exercisesByAnswer = const {};
  int _index = 0;
  int _correctCount = 0;
  int _incorrectCount = 0;
  bool _showAnswer = false;
  bool _isSubmitting = false;
  bool _submissionFailed = false;
  WordReviewResult? _result;

  @override
  void initState() {
    super.initState();
    _loadBatch();
  }

  Future<void> _loadBatch() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
      _cards = const [];
      _exercisesByAnswer = const {};
      _index = 0;
      _correctCount = 0;
      _incorrectCount = 0;
      _resetCardState();
    });
    try {
      final results = await Future.wait<Object>([
        widget.learnerApi.getLessonQuizBatch(widget.lesson.id),
        widget.learnerApi.getLessonExercises(widget.lesson.id),
      ]);
      final cards = results[0] as List<LessonWord>;
      final exercises =
          List<LessonExercise>.of(results[1] as List<LessonExercise>)..sort(
            (left, right) => left.exerciseOrder.compareTo(right.exerciseOrder),
          );
      final exercisesByAnswer = <String, LessonExercise>{};
      for (final exercise in exercises) {
        if (exercise.exerciseType == 'fill_in_blank') {
          exercisesByAnswer.putIfAbsent(exercise.answer, () => exercise);
        }
      }
      if (mounted) {
        setState(() {
          _cards = cards;
          _exercisesByAnswer = exercisesByAnswer;
        });
      }
    } on LearnerApiException catch (error) {
      if (mounted) setState(() => _loadError = error.detail);
    } catch (_) {
      if (mounted) setState(() => _loadError = 'Could not load practice.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _resetCardState() {
    _showAnswer = false;
    _isSubmitting = false;
    _submissionFailed = false;
    _result = null;
  }

  Future<void> _submit(bool correct) async {
    if (_isSubmitting ||
        _result != null ||
        _submissionFailed ||
        _index >= _cards.length) {
      return;
    }
    setState(() {
      _isSubmitting = true;
    });
    try {
      final result = await widget.learnerApi.reviewLessonWord(
        lessonId: widget.lesson.id,
        word: _cards[_index].word,
        correct: correct,
      );
      if (!mounted) return;
      setState(() {
        _result = result;
        _isSubmitting = false;
        if (correct) {
          _correctCount++;
        } else {
          _incorrectCount++;
        }
      });
      if (_isSelfAssessment(_cards[_index])) _advance();
    } on LearnerApiException catch (error) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _submissionFailed = true;
          _loadError = error.detail;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _submissionFailed = true;
          _loadError = 'Could not confirm this review.';
        });
      }
    }
  }

  void _advance() {
    if (_index >= _cards.length) return;
    setState(() {
      _index++;
      _resetCardState();
      _loadError = null;
    });
  }

  bool _isSelfAssessment(LessonWord card) =>
      card.score == 3 ||
      (card.translations.isEmpty && _exerciseFor(card) == null);

  LessonExercise? _exerciseFor(LessonWord card) =>
      card.score < 3 ? _exercisesByAnswer[card.word] : null;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Practice vocabulary')),
      body: SafeArea(child: _buildBody(context)),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_loadError != null && _cards.isEmpty && !_submissionFailed) {
      return _PracticeMessage(
        icon: Icons.cloud_off_outlined,
        title: 'Practice could not load',
        message: _loadError!,
        actionLabel: 'Try again',
        onAction: _loadBatch,
      );
    }
    if (_cards.isEmpty) {
      return _PracticeMessage(
        icon: Icons.task_alt_rounded,
        title: 'You’re up to date',
        message: 'There are no vocabulary cards due for this lesson.',
        actionLabel: 'Check again',
        onAction: _loadBatch,
      );
    }
    if (_index >= _cards.length) return _buildCompletion();
    return _buildCard(_cards[_index]);
  }

  Widget _buildCard(LessonWord card) {
    final theme = Theme.of(context);
    final isSelfAssessment = _isSelfAssessment(card);
    final exercise = _exerciseFor(card);
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      children: [
        Row(
          children: [
            Expanded(
              child: LinearProgressIndicator(
                value: _index / _cards.length,
                minHeight: 8,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            const SizedBox(width: 12),
            Text('${_index + 1}/${_cards.length}'),
          ],
        ),
        const SizedBox(height: 28),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  isSelfAssessment
                      ? 'Do you remember this word?'
                      : exercise != null
                      ? 'Choose the missing Finnish word'
                      : 'Choose the English meaning',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 14),
                Text(
                  exercise?.prompt ?? card.word,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (exercise != null && exercise.translation.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    exercise.translation,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ],
                const SizedBox(height: 22),
                if (isSelfAssessment)
                  _buildSelfAssessment(card)
                else
                  _buildChoices(card, exercise: exercise),
                if (_isSubmitting) ...[
                  const SizedBox(height: 18),
                  const Center(child: CircularProgressIndicator()),
                ],
                if (_submissionFailed) ...[
                  const SizedBox(height: 18),
                  Text(
                    _loadError ?? 'Could not confirm this review.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'The request may have reached the server, so it will not be submitted again automatically.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    child: const Text('End session'),
                  ),
                ],
                if (_result != null && !isSelfAssessment) ...[
                  const SizedBox(height: 18),
                  _ReviewFeedback(
                    result: _result!,
                    card: card,
                    correctAnswer: exercise?.answer ?? _translationLabel(card),
                  ),
                  const SizedBox(height: 14),
                  FilledButton(
                    onPressed: _advance,
                    child: Text(
                      _index == _cards.length - 1
                          ? 'View summary'
                          : 'Next card',
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildChoices(LessonWord card, {LessonExercise? exercise}) {
    final correctAnswer = exercise?.answer ?? _translationLabel(card);
    final choices = exercise?.options ?? _choicesFor(card);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final choice in choices)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: OutlinedButton(
              onPressed: _result == null && !_isSubmitting && !_submissionFailed
                  ? () => _submit(choice == correctAnswer)
                  : null,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 15,
                ),
              ),
              child: Text(choice),
            ),
          ),
      ],
    );
  }

  Widget _buildSelfAssessment(LessonWord card) {
    if (!_showAnswer) {
      return FilledButton(
        onPressed: _submissionFailed
            ? null
            : () => setState(() => _showAnswer = true),
        child: const Text('Show answer'),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          card.translations.isEmpty
              ? 'No translation provided'
              : _translationLabel(card),
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleLarge
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 18),
        FilledButton.icon(
          onPressed: _isSubmitting || _submissionFailed
              ? null
              : () => _submit(true),
          icon: const Icon(Icons.check_rounded),
          label: const Text('Recalled it'),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: _isSubmitting || _submissionFailed
              ? null
              : () => _submit(false),
          icon: const Icon(Icons.close_rounded),
          label: const Text('Didn’t recall'),
        ),
      ],
    );
  }

  List<String> _choicesFor(LessonWord card) {
    final correct = _translationLabel(card);
    final distractors = <String>{};
    for (final word in widget.lessonWords) {
      if (word.word == card.word || word.translations.isEmpty) continue;
      final label = _translationLabel(word);
      if (label != correct) distractors.add(label);
    }
    final choices = <String>[correct, ...distractors.take(3)];
    choices.shuffle(Random(card.word.hashCode));
    return choices;
  }

  String _translationLabel(LessonWord word) => word.translations.join(', ');

  Widget _buildCompletion() {
    final reviewed = _correctCount + _incorrectCount;
    return _PracticeMessage(
      icon: Icons.celebration_outlined,
      title: 'Session complete',
      message:
          '$reviewed reviewed · $_correctCount correct · $_incorrectCount incorrect',
      actionLabel: 'Return to lesson',
      onAction: () => Navigator.of(context).pop(true),
    );
  }
}

class _ReviewFeedback extends StatelessWidget {
  const _ReviewFeedback({
    required this.result,
    required this.card,
    required this.correctAnswer,
  });

  final WordReviewResult result;
  final LessonWord card;
  final String correctAnswer;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: result.correct ? const Color(0xFFD8EDE5) : colors.errorContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            result.correct ? 'Correct!' : 'Not quite',
            style: Theme.of(context).textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          if (!result.correct) Text('Answer: $correctAnswer'),
          const SizedBox(height: 4),
          Text(
            result.score == 3
                ? 'Mastered'
                : result.scoreIncreased
                ? 'Progressed to score ${result.score}'
                : 'Current score: ${result.score}',
          ),
        ],
      ),
    );
  }
}

class _PracticeMessage extends StatelessWidget {
  const _PracticeMessage({
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
            const SizedBox(height: 16),
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
