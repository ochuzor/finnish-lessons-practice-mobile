import 'package:flutter/material.dart';

import '../api/learner_api.dart';

class PersonalVocabularyScreen extends StatefulWidget {
  const PersonalVocabularyScreen({required this.learnerApi, super.key});

  final LearnerApi learnerApi;

  @override
  State<PersonalVocabularyScreen> createState() =>
      _PersonalVocabularyScreenState();
}

class _PersonalVocabularyScreenState extends State<PersonalVocabularyScreen> {
  bool _isLoading = true;
  String? _error;
  String? _deletingWord;
  List<LessonWord> _words = const [];

  @override
  void initState() {
    super.initState();
    _loadWords();
  }

  Future<void> _loadWords() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final words = await widget.learnerApi.getPersonalWords();
      if (mounted) setState(() => _words = words);
    } on LearnerApiException catch (error) {
      if (mounted) setState(() => _error = error.detail);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Could not load your vocabulary.');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _openForm({LessonWord? word}) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => _PersonalWordFormScreen(
          learnerApi: widget.learnerApi,
          existingWord: word,
        ),
      ),
    );
    if (saved != true || !mounted) return;
    await _loadWords();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(word == null ? 'Word added.' : 'Word updated.')),
      );
    }
  }

  Future<void> _confirmDelete(LessonWord word) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove word?'),
        content: Text('Remove ‘${word.word}’ and its practice history?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() {
      _deletingWord = word.word;
      _error = null;
    });
    try {
      await widget.learnerApi.deletePersonalWord(word.word);
      await _loadWords();
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Word removed.')));
      }
    } on LearnerApiException catch (error) {
      if (mounted) setState(() => _error = error.detail);
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not remove this word.');
    } finally {
      if (mounted) setState(() => _deletingWord = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My vocabulary')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _deletingWord == null ? () => _openForm() : null,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add word'),
      ),
      body: SafeArea(child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (_isLoading && _words.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _words.isEmpty) {
      return _VocabularyMessage(
        icon: Icons.cloud_off_outlined,
        title: 'Vocabulary could not load',
        message: _error!,
        actionLabel: 'Try again',
        onAction: _loadWords,
      );
    }
    if (_words.isEmpty) {
      return _VocabularyMessage(
        icon: Icons.book_outlined,
        title: 'Build your vocabulary',
        message: 'Add Finnish words and phrases you want to practise in vocabulary review.',
        actionLabel: 'Add your first word',
        onAction: _openForm,
      );
    }

    return RefreshIndicator(
      onRefresh: _loadWords,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
        children: [
          Text(
            'Your own Finnish words and phrases',
            style: Theme.of(context).textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            'New words join global vocabulary review immediately.',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          const SizedBox(height: 16),
          for (final word in _words)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _PersonalWordCard(
                word: word,
                isDeleting: _deletingWord == word.word,
                actionsEnabled: _deletingWord == null,
                onEdit: () => _openForm(word: word),
                onDelete: () => _confirmDelete(word),
              ),
            ),
        ],
      ),
    );
  }
}

class _PersonalWordCard extends StatelessWidget {
  const _PersonalWordCard({
    required this.word,
    required this.isDeleting,
    required this.actionsEnabled,
    required this.onEdit,
    required this.onDelete,
  });

  final LessonWord word;
  final bool isDeleting;
  final bool actionsEnabled;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 14, 8, 14),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    word.word,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(word.translations.join(', ')),
                  const SizedBox(height: 7),
                  Text(
                    _scoreLabel(word.score),
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            if (isDeleting)
              const Padding(
                padding: EdgeInsets.all(14),
                child: SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            else ...[
              IconButton(
                onPressed: actionsEnabled ? onEdit : null,
                tooltip: 'Edit ${word.word}',
                icon: const Icon(Icons.edit_outlined),
              ),
              IconButton(
                onPressed: actionsEnabled ? onDelete : null,
                tooltip: 'Remove ${word.word}',
                icon: const Icon(Icons.delete_outline_rounded),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _scoreLabel(int score) => switch (score) {
    0 => 'New',
    3 => 'Mastered',
    _ => 'Practising · score $score',
  };
}

class _PersonalWordFormScreen extends StatefulWidget {
  const _PersonalWordFormScreen({required this.learnerApi, this.existingWord});

  final LearnerApi learnerApi;
  final LessonWord? existingWord;

  @override
  State<_PersonalWordFormScreen> createState() =>
      _PersonalWordFormScreenState();
}

class _PersonalWordFormScreenState extends State<_PersonalWordFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _wordController;
  late final TextEditingController _translationsController;
  bool _isSaving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _wordController = TextEditingController(text: widget.existingWord?.word);
    _translationsController = TextEditingController(
      text: widget.existingWord?.translations.join(', '),
    );
  }

  @override
  void dispose() {
    _wordController.dispose();
    _translationsController.dispose();
    super.dispose();
  }

  List<String> _translations() {
    final unique = <String>{};
    for (final part in _translationsController.text.split(',')) {
      final translation = part.trim();
      if (translation.isNotEmpty) unique.add(translation);
    }
    return unique.toList(growable: false);
  }

  Future<void> _save() async {
    if (_isSaving || !_formKey.currentState!.validate()) return;
    final word = _wordController.text.trim();
    final translations = _translations();
    setState(() {
      _isSaving = true;
      _error = null;
    });
    try {
      final existingWord = widget.existingWord;
      if (existingWord == null) {
        await widget.learnerApi.createPersonalWord(
          word: word,
          translations: translations,
        );
      } else {
        await widget.learnerApi.updatePersonalWord(
          existingWord: existingWord.word,
          word: word,
          translations: translations,
        );
      }
      if (mounted) Navigator.of(context).pop(true);
    } on LearnerApiException catch (error) {
      if (mounted) setState(() => _error = error.detail);
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not save this word.');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.existingWord != null;
    return PopScope(
      canPop: !_isSaving,
      child: Scaffold(
        appBar: AppBar(title: Text(isEditing ? 'Edit word' : 'Add word')),
        body: SafeArea(
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
              children: [
                TextFormField(
                  controller: _wordController,
                  enabled: !_isSaving,
                  textCapitalization: TextCapitalization.none,
                  maxLength: 120,
                  decoration: const InputDecoration(
                    labelText: 'Finnish word or phrase',
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Enter a Finnish word or phrase.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _translationsController,
                  enabled: !_isSaving,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'English meanings',
                    hintText: 'library, a library',
                    helperText: 'Separate up to five meanings with commas.',
                  ),
                  validator: (_) {
                    final translations = _translations();
                    if (translations.isEmpty) {
                      return 'Enter at least one English meaning.';
                    }
                    if (translations.length > 5) {
                      return 'Enter no more than five meanings.';
                    }
                    if (translations.any(
                      (translation) => translation.length > 200,
                    )) {
                      return 'Each meaning must be 200 characters or fewer.';
                    }
                    return null;
                  },
                ),
                if (isEditing) ...[
                  const SizedBox(height: 10),
                  Text(
                    'Changing the Finnish term resets this word’s practice progress. Changing only its meanings preserves progress.',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
                if (_error != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: _isSaving ? null : _save,
                  icon: _isSaving
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save_outlined),
                  label: Text(
                    _isSaving
                        ? 'Saving…'
                        : isEditing
                        ? 'Save changes'
                        : 'Save word',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _VocabularyMessage extends StatelessWidget {
  const _VocabularyMessage({
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
