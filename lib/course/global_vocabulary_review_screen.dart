import 'dart:math';

import 'package:flutter/material.dart';

import '../api/learner_api.dart';

class GlobalVocabularyReviewScreen extends StatefulWidget {
  const GlobalVocabularyReviewScreen({required this.learnerApi, super.key});

  final LearnerApi learnerApi;

  @override
  State<GlobalVocabularyReviewScreen> createState() =>
      _GlobalVocabularyReviewScreenState();
}

class _GlobalVocabularyReviewScreenState
    extends State<GlobalVocabularyReviewScreen> {
  bool _hasStarted = false;
  bool _isLoading = false;
  String? _loadError;
  List<LessonWord> _cards = const [];
  List<LessonWord> _wordPool = const [];
  int _index = 0;
  int _correctCount = 0;
  int _incorrectCount = 0;
  bool _showAnswer = false;
  bool _isSubmitting = false;
  bool _submissionFailed = false;
  bool _cardWasRemoved = false;
  WordReviewResult? _result;

  Future<void> _startQuiz() async {
    setState(() {
      _hasStarted = true;
      _isLoading = true;
      _loadError = null;
      _cards = const [];
      _wordPool = const [];
      _index = 0;
      _correctCount = 0;
      _incorrectCount = 0;
      _resetCardState();
    });
    try {
      final results = await Future.wait<Object>([
        widget.learnerApi.getPracticeQuizBatch(),
        widget.learnerApi.getPracticeWords(),
      ]);
      if (!mounted) return;
      setState(() {
        _cards = results[0] as List<LessonWord>;
        _wordPool = results[1] as List<LessonWord>;
      });
    } on LearnerApiException catch (error) {
      if (mounted) setState(() => _loadError = error.detail);
    } catch (_) {
      if (mounted) {
        setState(() => _loadError = 'Could not load vocabulary review.');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _resetCardState() {
    _showAnswer = false;
    _isSubmitting = false;
    _submissionFailed = false;
    _cardWasRemoved = false;
    _result = null;
  }

  Future<void> _submit(bool correct) async {
    if (_isSubmitting ||
        _result != null ||
        _submissionFailed ||
        _index >= _cards.length) {
      return;
    }
    final card = _cards[_index];
    if (!card.isPersonal && card.sourceLessonId == null) {
      setState(() {
        _submissionFailed = true;
        _loadError = 'This course word has no source lesson.';
      });
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final result = card.isPersonal
          ? await widget.learnerApi.reviewPersonalWord(
              word: card.word,
              correct: correct,
            )
          : await widget.learnerApi.reviewLessonWord(
              lessonId: card.sourceLessonId!,
              word: card.word,
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
      if (_isSelfAssessment(card)) _advance();
    } on LearnerApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _submissionFailed = true;
        _cardWasRemoved = error.statusCode == 404;
        _loadError = error.statusCode == 404
            ? 'This word is no longer available. Reload the due cards.'
            : error.detail;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _submissionFailed = true;
        _loadError = 'Could not confirm this review.';
      });
    }
  }

  void _advance() {
    if (_index >= _cards.length) return;
    setState(() {
      _index++;
      _loadError = null;
      _resetCardState();
    });
  }

  bool _isSelfAssessment(LessonWord card) =>
      card.score == 3 || card.translations.isEmpty;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Vocabulary review')),
      body: SafeArea(child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (!_hasStarted) return _buildIntro();
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_loadError != null && _cards.isEmpty) {
      return _ReviewMessage(
        icon: Icons.cloud_off_outlined,
        title: 'Review could not load',
        message: _loadError!,
        actionLabel: 'Try again',
        onAction: _startQuiz,
      );
    }
    if (_cards.isEmpty) {
      return _ReviewMessage(
        icon: Icons.task_alt_rounded,
        title: 'You’re up to date',
        message: 'There are no vocabulary cards due right now.',
        actionLabel: 'Check again',
        onAction: _startQuiz,
      );
    }
    if (_index >= _cards.length) return _buildCompletion();
    return _buildCard(_cards[_index]);
  }

  Widget _buildIntro() {
    final theme = Theme.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Icon(
                    Icons.replay_circle_filled_rounded,
                    size: 58,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Review your vocabulary',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Practise words that are due across your course and personal vocabulary.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 22),
                  FilledButton.icon(
                    onPressed: _startQuiz,
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: const Text('Start quiz'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCard(LessonWord card) {
    final theme = Theme.of(context);
    final isSelfAssessment = _isSelfAssessment(card);
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
                      : 'Choose the English meaning',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 14),
                Text(
                  card.word,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 22),
                if (isSelfAssessment)
                  _buildSelfAssessment(card)
                else
                  _buildChoices(card),
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
                  if (!_cardWasRemoved) ...[
                    const SizedBox(height: 8),
                    Text(
                      'The request may have reached the server, so it will not be submitted again automatically.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: _cardWasRemoved
                        ? _startQuiz
                        : () => Navigator.of(context).pop(true),
                    child: Text(
                      _cardWasRemoved ? 'Reload due cards' : 'End session',
                    ),
                  ),
                ],
                if (_result != null && !isSelfAssessment) ...[
                  const SizedBox(height: 18),
                  _ReviewFeedback(
                    result: _result!,
                    correctAnswer: _translationLabel(card),
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

  Widget _buildChoices(LessonWord card) {
    final correctAnswer = _translationLabel(card);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final choice in _choicesFor(card))
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
    final weightsByLabel = <String, int>{};
    for (final candidate in _wordPool) {
      if (candidate.translations.isEmpty) continue;
      final label = _translationLabel(candidate);
      if (label == correct) continue;
      final weight = switch (candidate.score) {
        3 => 6,
        1 || 2 => 3,
        _ => 1,
      };
      final currentWeight = weightsByLabel[label] ?? 0;
      if (weight > currentWeight) weightsByLabel[label] = weight;
    }

    final random = Random(card.word.hashCode);
    final distractors = <String>[];
    while (weightsByLabel.isNotEmpty && distractors.length < 3) {
      final totalWeight = weightsByLabel.values.fold<int>(0, (a, b) => a + b);
      var pick = random.nextInt(totalWeight);
      String? selected;
      for (final entry in weightsByLabel.entries) {
        pick -= entry.value;
        if (pick < 0) {
          selected = entry.key;
          break;
        }
      }
      distractors.add(selected!);
      weightsByLabel.remove(selected);
    }

    final choices = <String>[correct, ...distractors]..shuffle(random);
    return choices;
  }

  String _translationLabel(LessonWord word) => word.translations.join(' / ');

  Widget _buildCompletion() {
    final reviewed = _correctCount + _incorrectCount;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.celebration_outlined,
              size: 56,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              'Session complete',
              style: Theme.of(context).textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              '$reviewed reviewed · $_correctCount correct · $_incorrectCount incorrect',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 18),
            FilledButton(
              onPressed: _startQuiz,
              child: const Text('Check for due cards'),
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Return home'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReviewFeedback extends StatelessWidget {
  const _ReviewFeedback({required this.result, required this.correctAnswer});

  final WordReviewResult result;
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

class _ReviewMessage extends StatelessWidget {
  const _ReviewMessage({
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
