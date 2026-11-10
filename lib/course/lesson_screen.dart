import 'package:flutter/material.dart';

import '../api/learner_api.dart';

class UnlockedLessonScreen extends StatefulWidget {
  UnlockedLessonScreen({
    required this.lesson,
    required this.learnerApi,
    super.key,
  }) : assert(!lesson.locked, 'Locked lessons must not be opened.');

  final CourseLesson lesson;
  final LearnerApi learnerApi;

  @override
  State<UnlockedLessonScreen> createState() => _UnlockedLessonScreenState();
}

class _UnlockedLessonScreenState extends State<UnlockedLessonScreen> {
  bool _isLoadingWords = true;
  String? _wordsError;
  List<LessonWord> _words = const [];

  @override
  void initState() {
    super.initState();
    _loadWords();
  }

  Future<void> _loadWords() async {
    setState(() {
      _isLoadingWords = true;
      _wordsError = null;
    });

    try {
      final words = await widget.learnerApi.getLessonWords(widget.lesson.id);
      if (mounted) setState(() => _words = words);
    } on LearnerApiException catch (error) {
      if (mounted) setState(() => _wordsError = error.detail);
    } catch (_) {
      if (mounted) setState(() => _wordsError = 'Could not load vocabulary.');
    } finally {
      if (mounted) setState(() => _isLoadingWords = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lesson = widget.lesson;
    return Scaffold(
      appBar: AppBar(title: Text(lesson.title)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 36),
          children: [
            _LessonHeader(lesson: lesson),
            const SizedBox(height: 28),
            _StageHeading(number: 1, title: 'Learn the pattern'),
            const SizedBox(height: 12),
            if (lesson.sections.isEmpty)
              const _EmptyCard(message: 'No learning notes are available yet.')
            else
              for (final section
                  in (List<LessonSection>.of(lesson.sections)..sort(
                    (left, right) =>
                        left.sectionOrder.compareTo(right.sectionOrder),
                  )))
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _LessonSectionCard(section: section),
                ),
            const SizedBox(height: 16),
            _StageHeading(number: 2, title: 'Learn the vocabulary'),
            const SizedBox(height: 12),
            _VocabularySummary(lesson: lesson),
            const SizedBox(height: 12),
            _buildVocabulary(),
            const SizedBox(height: 28),
            _StageHeading(number: 3, title: 'Practice and check'),
            const SizedBox(height: 12),
            _PracticeActions(lesson: lesson, hasWords: _words.isNotEmpty),
          ],
        ),
      ),
    );
  }

  Widget _buildVocabulary() {
    if (_isLoadingWords) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }
    if (_wordsError != null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Text(_wordsError!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _loadWords,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Try again'),
              ),
            ],
          ),
        ),
      );
    }
    if (_words.isEmpty) {
      return const _EmptyCard(
        message: 'This lesson does not have vocabulary words.',
      );
    }
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var index = 0; index < _words.length; index++) ...[
            _VocabularyRow(word: _words[index]),
            if (index != _words.length - 1) const Divider(height: 1),
          ],
        ],
      ),
    );
  }
}

class _LessonHeader extends StatelessWidget {
  const _LessonHeader({required this.lesson});

  final CourseLesson lesson;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          lesson.checkpointPassed ? 'LESSON CHECK PASSED' : 'READY TO LEARN',
          style: theme.textTheme.labelLarge?.copyWith(
            color: theme.colorScheme.primary,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          lesson.title,
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        if (lesson.description.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            lesson.description,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }
}

class _StageHeading extends StatelessWidget {
  const _StageHeading({required this.number, required this.title});

  final int number;
  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        CircleAvatar(
          radius: 15,
          backgroundColor: theme.colorScheme.primaryContainer,
          foregroundColor: theme.colorScheme.onPrimaryContainer,
          child: Text('$number'),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _LessonSectionCard extends StatelessWidget {
  const _LessonSectionCard({required this.section});

  final LessonSection section;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              section.heading,
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            _LightweightMarkdown(source: section.content),
          ],
        ),
      ),
    );
  }
}

class _LightweightMarkdown extends StatelessWidget {
  const _LightweightMarkdown({required this.source});

  final String source;

  @override
  Widget build(BuildContext context) {
    final normalized = source.replaceAll('\r\n', '\n').trim();
    if (normalized.isEmpty) return const SizedBox.shrink();
    final blocks = normalized.split(RegExp(r'\n\s*\n'));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var index = 0; index < blocks.length; index++) ...[
          _MarkdownBlock(source: blocks[index]),
          if (index != blocks.length - 1) const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class _MarkdownBlock extends StatelessWidget {
  const _MarkdownBlock({required this.source});

  final String source;

  @override
  Widget build(BuildContext context) {
    final lines = source.split('\n').map((line) => line.trim()).toList();
    if (lines.every((line) => line.startsWith('- '))) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final line in lines)
            Padding(
              padding: const EdgeInsets.only(bottom: 5),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('•  '),
                  Expanded(child: _RichMarkdownText(source: line.substring(2))),
                ],
              ),
            ),
        ],
      );
    }
    if (_isTable(lines)) return _MarkdownTable(lines: lines);
    return _RichMarkdownText(source: lines.join('\n'));
  }

  bool _isTable(List<String> lines) {
    if (lines.length < 2 || !lines.first.contains('|')) return false;
    final divider = _tableCells(lines[1]);
    return divider.isNotEmpty &&
        divider.every((cell) => RegExp(r'^:?-{3,}:?$').hasMatch(cell));
  }
}

class _RichMarkdownText extends StatelessWidget {
  const _RichMarkdownText({required this.source});

  final String source;

  @override
  Widget build(BuildContext context) {
    final baseStyle = Theme.of(context).textTheme.bodyMedium;
    final matches = RegExp(r'\*\*(.+?)\*\*').allMatches(source);
    final spans = <InlineSpan>[];
    var cursor = 0;
    for (final match in matches) {
      if (match.start > cursor) {
        spans.add(TextSpan(text: source.substring(cursor, match.start)));
      }
      spans.add(
        TextSpan(
          text: match.group(1),
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      );
      cursor = match.end;
    }
    if (cursor < source.length) {
      spans.add(TextSpan(text: source.substring(cursor)));
    }
    return Text.rich(TextSpan(style: baseStyle, children: spans));
  }
}

class _MarkdownTable extends StatelessWidget {
  const _MarkdownTable({required this.lines});

  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    final rows = [lines.first, ...lines.skip(2)].map(_tableCells).toList();
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Table(
        defaultColumnWidth: const IntrinsicColumnWidth(),
        border: TableBorder.all(
          color: Theme.of(context).colorScheme.outlineVariant,
        ),
        children: [
          for (var rowIndex = 0; rowIndex < rows.length; rowIndex++)
            TableRow(
              decoration: rowIndex == 0
                  ? BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerHigh,
                    )
                  : null,
              children: [
                for (final cell in rows[rowIndex])
                  Padding(
                    padding: const EdgeInsets.all(9),
                    child: _RichMarkdownText(source: cell),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

List<String> _tableCells(String line) {
  var value = line.trim();
  if (value.startsWith('|')) value = value.substring(1);
  if (value.endsWith('|')) value = value.substring(0, value.length - 1);
  return value.split('|').map((cell) => cell.trim()).toList();
}

class _VocabularySummary extends StatelessWidget {
  const _VocabularySummary({required this.lesson});

  final CourseLesson lesson;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      color: theme.colorScheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Wrap(
          spacing: 18,
          runSpacing: 8,
          children: [
            Text('${lesson.newWords} new'),
            Text('${lesson.practicingWords} practicing'),
            Text('${lesson.masteredWords} mastered'),
          ],
        ),
      ),
    );
  }
}

class _VocabularyRow extends StatelessWidget {
  const _VocabularyRow({required this.word});

  final LessonWord word;

  @override
  Widget build(BuildContext context) {
    final state = _WordState.fromScore(word.score);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: state.background,
            foregroundColor: state.foreground,
            child: Icon(state.icon, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  word.word,
                  style: Theme.of(context).textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                Text(
                  word.translations.isEmpty
                      ? 'No translation provided'
                      : word.translations.join(', '),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            state.label,
            style: TextStyle(
              color: state.foreground,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _WordState {
  const _WordState({
    required this.label,
    required this.icon,
    required this.background,
    required this.foreground,
  });

  factory _WordState.fromScore(int score) {
    if (score == 3) {
      return const _WordState(
        label: 'Mastered',
        icon: Icons.check_rounded,
        background: Color(0xFFD8EDE5),
        foreground: Color(0xFF205B48),
      );
    }
    if (score > 0) {
      return const _WordState(
        label: 'Practicing',
        icon: Icons.autorenew_rounded,
        background: Color(0xFFFFE9C7),
        foreground: Color(0xFF795315),
      );
    }
    return const _WordState(
      label: 'New',
      icon: Icons.fiber_new_rounded,
      background: Color(0xFFDCE8F6),
      foreground: Color(0xFF28537A),
    );
  }

  final String label;
  final IconData icon;
  final Color background;
  final Color foreground;
}

class _PracticeActions extends StatelessWidget {
  const _PracticeActions({required this.lesson, required this.hasWords});

  final CourseLesson lesson;
  final bool hasWords;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FilledButton.icon(
              onPressed: null,
              icon: const Icon(Icons.school_outlined),
              label: const Text('Practice vocabulary'),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: null,
              icon: const Icon(Icons.fact_check_outlined),
              label: Text(
                lesson.checkpointPassed
                    ? 'Retake lesson check'
                    : 'Take lesson check',
              ),
            ),
            const SizedBox(height: 10),
            Text(
              hasWords ? 'Practice activities are coming next.' : 'Vocabulary practice needs at least one lesson word. Lesson Check is coming next.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(padding: const EdgeInsets.all(18), child: Text(message)),
    );
  }
}
