import 'dart:convert';

import 'package:flutter/material.dart';

import '../../services/api_session.dart';

typedef AdminContentRequest =
    Future<Map<String, dynamic>> Function(
      String path, {
      String? method,
      Map<String, dynamic>? data,
    });

const _exerciseNames = <String, String>{
  'singleChoice': 'Single choice',
  'multipleSelect': 'Multiple select',
  'shortAnswer': 'Short answer',
  'orderSteps': 'Order steps',
  'matching': 'Matching',
  'fillInTheBlank': 'Fill in the blank',
  'trueFalse': 'True / false',
  'spotTheMistake': 'Spot the mistake',
  'categorization': 'Categorization',
  'causeAndEffect': 'Cause and effect',
  'compareAndContrast': 'Compare and contrast',
  'buildTheProcess': 'Build the process',
};

class ContentAdminSection extends StatefulWidget {
  const ContentAdminSection({required this.onRequest, super.key});
  final AdminContentRequest onRequest;

  @override
  State<ContentAdminSection> createState() => _ContentAdminSectionState();
}

class _ContentAdminSectionState extends State<ContentAdminSection> {
  static const _languages = ['en', 'fr', 'es', 'hi', 'ru'];
  final _lessonTitle = TextEditingController();
  final _lessonContent = TextEditingController();
  final _prompt = TextEditingController();
  final _explanation = TextEditingController();
  final _options = TextEditingController();
  final _answers = TextEditingController();
  final _order = TextEditingController();
  final _pairs = TextEditingController();
  final _paragraph = TextEditingController();
  final _categories = TextEditingController();
  final _rawJson = TextEditingController();
  Map<String, dynamic>? _state;
  List<Map<String, dynamic>> _topics = [];
  List<Map<String, dynamic>> _lessons = [];
  Map<String, dynamic>? _lesson;
  String? _topicId;
  String? _lessonId;
  String? _exerciseId;
  String _language = 'en';
  String _exerciseType = 'singleChoice';
  bool _busy = false;
  bool _rawMode = false;
  String? _error;
  String? _notice;

  @override
  void initState() {
    super.initState();
    _loadState();
  }

  @override
  void dispose() {
    _lessonTitle.dispose();
    _lessonContent.dispose();
    _prompt.dispose();
    _explanation.dispose();
    _options.dispose();
    _answers.dispose();
    _order.dispose();
    _pairs.dispose();
    _paragraph.dispose();
    _categories.dispose();
    _rawJson.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() work) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
      _notice = null;
    });
    try {
      await work();
    } on ApiSessionException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error.toString().replaceFirst('Exception: ', ''),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _loadState() => _run(() async {
    _state = await widget.onRequest('/admin/content/state');
    if (_state?['ready'] == true) await _loadTopics();
    if (mounted) setState(() {});
  });

  Future<void> _loadTopics() async {
    final result = await widget.onRequest(
      '/admin/content/topics?language=$_language',
    );
    _topics = (result['topics'] as List<dynamic>).cast<Map<String, dynamic>>();
    final visibleIds = _topics.map((topic) => topic['id']).toSet();
    if (!visibleIds.contains(_topicId)) {
      _topicId = _topics.isEmpty ? null : _topics.first['id'] as String;
    }
    await _loadLessons();
  }

  Future<void> _loadLessons() async {
    _lesson = null;
    _lessonId = null;
    _clearExercise();
    if (_topicId == null) {
      _lessons = [];
      return;
    }
    final result = await widget.onRequest(
      '/admin/content/lessons?topicId=${Uri.encodeQueryComponent(_topicId!)}&language=$_language',
    );
    _lessons = (result['lessons'] as List<dynamic>)
        .cast<Map<String, dynamic>>();
    if (_lessons.isNotEmpty) {
      _lessonId = _lessons.first['id'] as String;
      await _loadLesson();
    }
  }

  Future<void> _loadLesson() async {
    if (_lessonId == null) return;
    final result = await widget.onRequest(
      '/admin/content/lessons/$_lessonId?language=$_language',
    );
    _lesson = result['lesson'] as Map<String, dynamic>;
    _lessonTitle.text = _lesson?['title']?.toString() ?? '';
    _lessonContent.text = _lesson?['content']?.toString() ?? '';
    _clearExercise();
  }

  void _clearExercise() {
    _exerciseId = null;
    _exerciseType = 'singleChoice';
    _prompt.clear();
    _explanation.clear();
    _options.clear();
    _answers.clear();
    _order.clear();
    _pairs.clear();
    _paragraph.clear();
    _categories.clear();
    _rawMode = false;
    _rawJson.text = const JsonEncoder.withIndent(
      '  ',
    ).convert(_exercisePayload());
  }

  List<String> _lines(String value) => value
      .split('\n')
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty)
      .toList();

  List<Map<String, String>> _pairValues() => _lines(_pairs.text).map((line) {
    final split = line.split('=>');
    if (split.length < 2 ||
        split.first.trim().isEmpty ||
        split.skip(1).join('=>').trim().isEmpty) {
      throw Exception('Write each pair as left side => right side.');
    }
    return {
      'left': split.first.trim(),
      'right': split.skip(1).join('=>').trim(),
    };
  }).toList();

  Map<String, dynamic> _exercisePayload() {
    final type = _exerciseType;
    final options = _lines(_options.text);
    final answers = _lines(_answers.text);
    final order = _lines(_order.text);
    final pairs = _pairValues();
    final categories = _lines(_categories.text);
    final paragraphParts = _paragraph.text
        .split('|')
        .map((part) => part.trim())
        .toList();
    return {
      'type': type,
      'prompt': _prompt.text.trim(),
      'options': options,
      'correctAnswers': answers,
      'correctOrder': order,
      'pairs': pairs,
      'paragraphParts': paragraphParts,
      'consequences': <String, String>{},
      'categories': categories,
      'visualStages': <String>[],
      'explanation': _explanation.text.trim(),
    };
  }

  Future<void> _createLesson() async {
    if (_topicId == null) return;
    final title = TextEditingController();
    final content = TextEditingController();
    final allLanguages = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Add a lesson'),
        content: SizedBox(
          width: 520,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: title,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Lesson title'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: content,
                minLines: 3,
                maxLines: 7,
                decoration: const InputDecoration(labelText: 'Lesson content'),
              ),
              const SizedBox(height: 10),
              const Text(
                'Translate the selected language into the other four before publishing.',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          OutlinedButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text('Publish only ${_language.toUpperCase()}'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Translate + publish all 5'),
          ),
        ],
      ),
    );
    if (allLanguages == null) {
      title.dispose();
      content.dispose();
      return;
    }
    await _run(() async {
      final result = await widget.onRequest(
        '/admin/content/lessons',
        method: 'POST',
        data: {
          'topicId': _topicId,
          'language': _language,
          'allLanguages': allLanguages,
          'title': title.text,
          'content': content.text,
        },
      );
      await _loadLessons();
      _lessonId = result['id'] as String;
      await _loadLesson();
      if (mounted)
        setState(
          () => _notice = allLanguages
              ? 'Translated and published in all five languages.'
              : 'Lesson published for ${_language.toUpperCase()}. Add its exercises.',
        );
    });
    title.dispose();
    content.dispose();
  }

  Future<void> _saveLesson({required bool allLanguages}) async {
    if (_lessonId == null) return;
    await _run(() async {
      final savedLessonId = _lessonId;
      await widget.onRequest(
        '/admin/content/lessons/$savedLessonId/publish',
        method: 'POST',
        data: {
          'language': _language,
          'allLanguages': allLanguages,
          'title': _lessonTitle.text,
          'content': _lessonContent.text,
        },
      );
      await _loadLessons();
      if (_lessons.any((item) => item['id'] == savedLessonId)) {
        _lessonId = savedLessonId;
        await _loadLesson();
      }
      if (mounted)
        setState(
          () => _notice = allLanguages
              ? 'Translated and published in all five languages.'
              : 'Lesson published for ${_language.toUpperCase()}.',
        );
    });
  }

  void _selectExercise(Map<String, dynamic> exercise) {
    final payload = exercise['payload'] is Map<String, dynamic>
        ? exercise['payload'] as Map<String, dynamic>
        : <String, dynamic>{};
    setState(() {
      _exerciseId = exercise['id']?.toString();
      _exerciseType = exercise['type']?.toString() ?? 'singleChoice';
      _rawMode = false;
      _populateExerciseFields(payload);
    });
  }

  void _populateExerciseFields(Map<String, dynamic> payload) {
    _exerciseType = payload['type']?.toString() ?? _exerciseType;
    _prompt.text = payload['prompt']?.toString() ?? '';
    _explanation.text = payload['explanation']?.toString() ?? '';
    _options.text = _asLines(payload['options']);
    _answers.text = _asLines(payload['correctAnswers']);
    _order.text = _asLines(payload['correctOrder']);
    _pairs.text = (payload['pairs'] as List<dynamic>? ?? [])
        .map((pair) => '${pair['left']} => ${pair['right']}')
        .join('\n');
    _paragraph.text = (payload['paragraphParts'] as List<dynamic>? ?? []).join(
      ' | ',
    );
    _categories.text = _asLines(payload['categories']);
    _rawJson.text = const JsonEncoder.withIndent('  ').convert(payload);
  }

  Map<String, dynamic> _parseRawExercise() {
    final decoded = jsonDecode(_rawJson.text);
    if (decoded is! Map)
      throw const FormatException('Exercise JSON must be an object.');
    final payload = Map<String, dynamic>.from(decoded);
    if (payload['type'] is! String)
      throw const FormatException('Add a string "type" field to the JSON.');
    return payload;
  }

  void _toggleRawMode(bool value) {
    if (value == _rawMode) return;
    try {
      if (value) {
        _rawJson.text = const JsonEncoder.withIndent(
          '  ',
        ).convert(_exercisePayload());
      } else {
        _populateExerciseFields(_parseRawExercise());
      }
      setState(() => _rawMode = value);
    } catch (error) {
      setState(
        () => _error = error.toString().replaceFirst('FormatException: ', ''),
      );
    }
  }

  Future<void> _verifyRawExercise() async {
    await _run(() async {
      final payload = _parseRawExercise();
      final type = payload['type'].toString();
      final result = await widget.onRequest(
        '/admin/content/exercises/validate',
        method: 'POST',
        data: {'exerciseType': type, 'payload': payload},
      );
      if (mounted)
        setState(
          () => _notice =
              'JSON is valid for ${_exerciseNames[result['exerciseType']] ?? type}.',
        );
    });
  }

  String _asLines(dynamic value) =>
      value is List ? value.map((item) => item.toString()).join('\n') : '';

  Future<void> _saveExercise({required bool allLanguages}) async {
    if (_lessonId == null) return;
    await _run(() async {
      final payload = _rawMode ? _parseRawExercise() : _exercisePayload();
      final exerciseType = payload['type']?.toString() ?? _exerciseType;
      final result = await widget.onRequest(
        '/admin/content/exercises/save',
        method: 'POST',
        data: {
          'lessonId': _lessonId,
          if (_exerciseId != null) 'exerciseId': _exerciseId,
          'language': _language,
          'exerciseType': exerciseType,
          'payload': payload,
          'allLanguages': allLanguages,
        },
      );
      _exerciseId = result['id']?.toString();
      await _loadLesson();
      final exercises = (_lesson?['exercises'] as List<dynamic>? ?? [])
          .cast<Map<String, dynamic>>();
      final matching = exercises.where((item) => item['id'] == _exerciseId);
      final saved = matching.isEmpty ? null : matching.first;
      if (saved != null) _selectExercise(saved);
      if (mounted)
        setState(
          () => _notice = allLanguages
              ? 'Translated and published in all five languages.'
              : 'Exercise published for ${_language.toUpperCase()}.',
        );
    });
  }

  Future<bool> _confirmAllLanguages() async =>
      await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Translate and publish to all five languages?'),
          content: const Text(
            'Google Cloud Translation will translate learner-facing text from the selected language into the other four. Exercise types and JSON structure are kept. Review translations before learners use them.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Translate + publish'),
            ),
          ],
        ),
      ) ??
      false;

  Future<void> _deleteLesson(String id) async {
    final ok = await _confirmDelete('lesson');
    if (!ok) return;
    await _run(() async {
      await widget.onRequest('/admin/content/lessons/$id', method: 'DELETE');
      await _loadLessons();
      _state = await widget.onRequest('/admin/content/state');
      if (mounted)
        setState(() => _notice = 'Lesson and its exercises deleted.');
    });
  }

  Future<void> _deleteExercise(String id) async {
    final ok = await _confirmDelete('exercise');
    if (!ok || _lessonId == null) return;
    await _run(() async {
      await widget.onRequest(
        '/admin/content/lessons/$_lessonId/exercises/$id',
        method: 'DELETE',
      );
      await _loadLesson();
      if (mounted) setState(() => _notice = 'Exercise deleted.');
    });
  }

  Future<bool> _confirmDelete(String item) async =>
      await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text('Delete this $item?'),
          content: Text(
            'This permanently deletes the $item and its saved history.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Delete'),
            ),
          ],
        ),
      ) ??
      false;

  Future<void> _showRevisions(String entityType, String entityId) async {
    try {
      final result = await widget.onRequest(
        '/admin/content/revisions?entityType=$entityType&entityId=${Uri.encodeQueryComponent(entityId)}&language=$_language',
      );
      final revisions = (result['revisions'] as List<dynamic>)
          .cast<Map<String, dynamic>>();
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Published versions'),
          content: SizedBox(
            width: 520,
            child: revisions.isEmpty
                ? const Text('No published versions have been recorded yet.')
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: revisions.length,
                    itemBuilder: (context, index) {
                      final revision = revisions[index];
                      final snapshot =
                          revision['snapshot'] as Map<String, dynamic>? ?? {};
                      final summary = entityType == 'exercise'
                          ? snapshot['prompt']?.toString() ?? 'Exercise version'
                          : snapshot['title']?.toString() ?? 'Lesson version';
                      return ListTile(
                        title: Text(
                          'Version ${revision['number']} · $summary',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text('${revision['createdAt'] ?? ''}'),
                        trailing: IconButton(
                          tooltip: 'Publish this version',
                          icon: const Icon(Icons.restore_rounded),
                          onPressed: _busy
                              ? null
                              : () async {
                                  Navigator.pop(dialogContext);
                                  await _restoreRevision(
                                    entityType,
                                    entityId,
                                    revision['id'].toString(),
                                  );
                                },
                        ),
                      );
                    },
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    } catch (error) {
      if (mounted)
        setState(
          () => _error = error.toString().replaceFirst('Exception: ', ''),
        );
    }
  }

  Future<void> _restoreRevision(
    String entityType,
    String entityId,
    String revisionId,
  ) => _run(() async {
    await widget.onRequest(
      '/admin/content/revisions/restore',
      method: 'POST',
      data: {
        'entityType': entityType,
        'entityId': entityId,
        'revisionId': revisionId,
        'language': _language,
      },
    );
    await _loadLesson();
    if (_exerciseId != null) {
      final exercises = (_lesson?['exercises'] as List<dynamic>? ?? [])
          .cast<Map<String, dynamic>>();
      final matching = exercises.where((item) => item['id'] == _exerciseId);
      if (matching.isNotEmpty) _selectExercise(matching.first);
    }
    if (mounted) setState(() => _notice = 'Saved version published.');
  });

  Future<void> _changeTopic(String? value) => _run(() async {
    _topicId = value;
    await _loadLessons();
    if (mounted) setState(() {});
  });

  Future<void> _translateWholeTopic() async {
    final topicId = _topicId;
    if (topicId == null || _state?['translationConfigured'] != true) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Translate this whole topic?'),
        content: Text(
          'Use ${_language.toUpperCase()} as the source. Google Cloud Translation will translate the topic question and all published lessons and exercises into the other four languages. Matching translations will be replaced, and lesson or exercise translations that exist only in another language will be deleted. Revision snapshots are retained. Review the results before learners use them.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(dialogContext, true),
            icon: const Icon(Icons.translate_rounded),
            label: const Text('Translate whole topic'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _run(() async {
      await widget.onRequest(
        '/admin/content/topics/${Uri.encodeComponent(topicId)}/translate',
        method: 'POST',
        data: {'language': _language},
      );
      await _loadTopics();
      if (mounted) {
        setState(
          () => _notice =
              'Topic and its published lessons translated into all five languages.',
        );
      }
    });
  }

  Future<void> _changeLesson(String? value) => _run(() async {
    _lessonId = value;
    await _loadLesson();
    if (mounted) setState(() {});
  });

  Future<void> _changeLanguage(String? value) => _run(() async {
    if (value == null) return;
    _language = value;
    await _loadTopics();
    if (mounted) setState(() {});
  });

  @override
  Widget build(BuildContext context) {
    if (_state == null && _busy) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_state?['ready'] != true) {
      return const Center(
        child: Text('No normalized lesson content was found in the database.'),
      );
    }
    final selectedLesson = _lesson;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _toolbar(),
        if (_error != null) _message(_error!, isError: true),
        if (_notice != null) _message(_notice!),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth < 900) {
                return ListView(
                  padding: const EdgeInsets.all(18),
                  children: [
                    _lessonPane(selectedLesson),
                    const SizedBox(height: 16),
                    _exercisePane(selectedLesson),
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(width: 440, child: _lessonPane(selectedLesson)),
                  const VerticalDivider(width: 1),
                  Expanded(child: _exercisePane(selectedLesson)),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _toolbar() => Container(
    padding: const EdgeInsets.fromLTRB(18, 12, 18, 12),
    color: Colors.white,
    child: Wrap(
      spacing: 12,
      runSpacing: 10,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        const Text(
          'Content studio',
          style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
        ),
        if (_state?['translationConfigured'] != true)
          const Tooltip(
            message:
                'Set GOOGLE_TRANSLATE_API_KEY on the API service to enable translation.',
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.translate_rounded,
                  color: Color(0xFFB7791F),
                  size: 18,
                ),
                SizedBox(width: 4),
                Text(
                  'Translation not configured',
                  style: TextStyle(fontSize: 12, color: Color(0xFF8A5A13)),
                ),
              ],
            ),
          ),
        SizedBox(
          width: 170,
          child: DropdownButtonFormField<String>(
            initialValue: _language,
            decoration: const InputDecoration(
              labelText: 'Editing language',
              isDense: true,
            ),
            items: _languages
                .map(
                  (code) => DropdownMenuItem(
                    value: code,
                    child: Text(code.toUpperCase()),
                  ),
                )
                .toList(),
            onChanged: _busy ? null : _changeLanguage,
          ),
        ),
        OutlinedButton.icon(
          onPressed: _busy ? null : _loadState,
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('Refresh'),
        ),
      ],
    ),
  );

  Widget _lessonPane(Map<String, dynamic>? lesson) => Container(
    color: const Color(0xFFF8F9FC),
    padding: const EdgeInsets.all(18),
    child: ListView(
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Lessons',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
            ),
            IconButton(
              onPressed: _busy ? null : _createLesson,
              tooltip: 'Add lesson',
              icon: const Icon(Icons.add_circle_outline),
            ),
          ],
        ),
        DropdownButtonFormField<String>(
          initialValue: _topicId,
          decoration: const InputDecoration(labelText: 'Topic'),
          isExpanded: true,
          items: _topics
              .map(
                (topic) => DropdownMenuItem(
                  value: topic['id'] as String,
                  child: Text(
                    '${List.filled(((topic['level'] as num?)?.toInt() ?? 1) - 1, '›').join(' ')} ${topic['question']}',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              )
              .toList(),
          onChanged: _busy ? null : _changeTopic,
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            onPressed:
                _busy ||
                    _topicId == null ||
                    _state?['translationConfigured'] != true
                ? null
                : _translateWholeTopic,
            icon: const Icon(Icons.translate_rounded),
            label: const Text('Translate whole topic to all 5'),
          ),
        ),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(
          initialValue: _lessonId,
          decoration: const InputDecoration(labelText: 'Lesson'),
          isExpanded: true,
          items: _lessons
              .map(
                (item) => DropdownMenuItem(
                  value: item['id'] as String,
                  child: Text(
                    'Lesson ${item['lessonNumber']} · ${item['title']} · ${item['status']}',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              )
              .toList(),
          onChanged: _busy ? null : _changeLesson,
        ),
        if (_lessonId != null)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: _busy ? null : () => _deleteLesson(_lessonId!),
              icon: const Icon(Icons.delete_outline_rounded, color: Colors.red),
              label: const Text(
                'Delete lesson',
                style: TextStyle(color: Colors.red),
              ),
            ),
          ),
        const SizedBox(height: 16),
        TextField(
          controller: _lessonTitle,
          decoration: const InputDecoration(labelText: 'Lesson title'),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _lessonContent,
          minLines: 5,
          maxLines: 12,
          decoration: const InputDecoration(
            labelText: 'Lesson content',
            alignLabelWithHint: true,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          children: [
            FilledButton(
              onPressed: _busy || lesson == null
                  ? null
                  : () => _saveLesson(allLanguages: false),
              child: Text('Publish only ${_language.toUpperCase()}'),
            ),
            OutlinedButton(
              onPressed: _busy || lesson == null
                  ? null
                  : () async {
                      if (await _confirmAllLanguages()) {
                        await _saveLesson(allLanguages: true);
                      }
                    },
              child: const Text('Translate + publish all 5'),
            ),
            if (_lessonId != null)
              IconButton(
                onPressed: _busy
                    ? null
                    : () => _showRevisions('lesson', _lessonId!),
                tooltip: 'Lesson versions',
                icon: const Icon(Icons.history_rounded),
              ),
          ],
        ),
        const Divider(height: 28),
        Row(
          children: [
            const Expanded(
              child: Text(
                'Exercises',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
            Text('${(lesson?['exercises'] as List<dynamic>? ?? []).length}'),
          ],
        ),
        for (final item
            in (lesson?['exercises'] as List<dynamic>? ?? [])
                .cast<Map<String, dynamic>>())
          Card(
            child: ListTile(
              dense: true,
              title: Text(
                item['payload']?['prompt']?.toString() ??
                    _exerciseNames[item['type']] ??
                    'Exercise',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                '${_exerciseNames[item['type']]} · ${item['isFallback'] == true ? 'English source · add translation' : item['status']}',
              ),
              onTap: () => _selectExercise(item),
              trailing: IconButton(
                tooltip: item['isFallback'] == true
                    ? 'Switch to English to delete this source exercise'
                    : 'Delete exercise',
                icon: const Icon(
                  Icons.delete_outline_rounded,
                  color: Colors.red,
                ),
                onPressed: _busy || item['isFallback'] == true
                    ? null
                    : () => _deleteExercise(item['id'].toString()),
              ),
            ),
          ),
        OutlinedButton.icon(
          onPressed: _busy || lesson == null
              ? null
              : () => setState(_clearExercise),
          icon: const Icon(Icons.add_rounded),
          label: const Text('Add exercise'),
        ),
      ],
    ),
  );

  Widget _exercisePane(Map<String, dynamic>? lesson) {
    final type = _exerciseType;
    final needsOptions = const {
      'singleChoice',
      'multipleSelect',
      'orderSteps',
      'matching',
      'trueFalse',
      'spotTheMistake',
      'categorization',
      'causeAndEffect',
      'buildTheProcess',
    }.contains(type);
    final needsAnswers = const {
      'singleChoice',
      'multipleSelect',
      'shortAnswer',
      'trueFalse',
      'spotTheMistake',
    }.contains(type);
    final needsOrder = const {
      'orderSteps',
      'fillInTheBlank',
      'buildTheProcess',
    }.contains(type);
    final needsPairs = const {
      'matching',
      'categorization',
      'causeAndEffect',
      'compareAndContrast',
    }.contains(type);
    return Container(
      padding: const EdgeInsets.all(20),
      color: Colors.white,
      child: ListView(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _exerciseId == null ? 'New exercise' : 'Edit exercise',
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const Text('Raw JSON', style: TextStyle(fontSize: 13)),
              Switch(value: _rawMode, onChanged: _busy ? null : _toggleRawMode),
            ],
          ),
          if (_rawMode) ...[
            const SizedBox(height: 12),
            TextField(
              controller: _rawJson,
              minLines: 16,
              maxLines: 32,
              keyboardType: TextInputType.multiline,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
              decoration: const InputDecoration(
                labelText: 'Exercise JSON',
                alignLabelWithHint: true,
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: _busy ? null : _verifyRawExercise,
              icon: const Icon(Icons.fact_check_outlined),
              label: const Text('Verify JSON format'),
            ),
            const Text(
              'Checks syntax, supported exercise type, and required fields before publishing.',
            ),
          ],
          if (!_rawMode) ...[
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: type,
              decoration: const InputDecoration(labelText: 'Interaction type'),
              items: _exerciseNames.entries
                  .map(
                    (entry) => DropdownMenuItem(
                      value: entry.key,
                      child: Text(entry.value),
                    ),
                  )
                  .toList(),
              onChanged: _exerciseId != null || _busy
                  ? null
                  : (value) => setState(() => _exerciseType = value ?? type),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _prompt,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Question / instruction',
              ),
            ),
            if (needsOptions) ...[
              const SizedBox(height: 10),
              _multiline(
                _options,
                type == 'orderSteps' || type == 'buildTheProcess'
                    ? 'Draggable options (one per line)'
                    : 'Choices (one per line)',
              ),
            ],
            if (needsAnswers) ...[
              const SizedBox(height: 10),
              _multiline(
                _answers,
                type == 'shortAnswer'
                    ? 'Accepted answers (one per line)'
                    : 'Correct choice(s), exact text (one per line)',
              ),
            ],
            if (needsOrder) ...[
              const SizedBox(height: 10),
              _multiline(
                _order,
                type == 'fillInTheBlank'
                    ? 'Missing words, in order (one per line)'
                    : 'Correct sequence (one per line)',
              ),
            ],
            if (needsPairs) ...[
              const SizedBox(height: 10),
              _multiline(
                _pairs,
                'Items / matches (one per line: left => right)',
              ),
            ],
            if (type == 'fillInTheBlank') ...[
              const SizedBox(height: 10),
              _multiline(
                _paragraph,
                'Paragraph segments separated by | (one segment before, between, and after each blank)',
              ),
            ],
            if (type == 'compareAndContrast') ...[
              const SizedBox(height: 10),
              _multiline(
                _categories,
                'Venn labels in order: A only, Both, B only',
              ),
            ],
            const SizedBox(height: 10),
            TextField(
              controller: _explanation,
              minLines: 2,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: 'Explanation shown after answering',
              ),
            ),
          ],
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton(
                onPressed: _busy || lesson == null
                    ? null
                    : () => _saveExercise(allLanguages: false),
                child: Text('Publish only ${_language.toUpperCase()}'),
              ),
              OutlinedButton(
                onPressed: _busy || lesson == null
                    ? null
                    : () async {
                        if (await _confirmAllLanguages()) {
                          await _saveExercise(allLanguages: true);
                        }
                      },
                child: const Text('Translate + publish all 5'),
              ),
              if (_exerciseId != null)
                IconButton(
                  onPressed: _busy
                      ? null
                      : () => _showRevisions('exercise', _exerciseId!),
                  tooltip: 'Exercise versions',
                  icon: const Icon(Icons.history_rounded),
                ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Published changes become visible in the app immediately. '
            'An exercise’s interaction type is fixed after creation so its saved answers always match the Flutter interaction.',
            style: TextStyle(color: Color(0xFF6D7584), fontSize: 12),
          ),
          if (lesson == null)
            const Padding(
              padding: EdgeInsets.only(top: 18),
              child: Text('Choose a topic and lesson to edit content.'),
            ),
        ],
      ),
    );
  }

  Widget _multiline(TextEditingController controller, String label) =>
      TextField(
        controller: controller,
        minLines: 2,
        maxLines: 6,
        decoration: InputDecoration(labelText: label, alignLabelWithHint: true),
      );

  Widget _message(String message, {bool isError = false}) => Container(
    margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: isError ? const Color(0xFFFFEDEC) : const Color(0xFFE9F7EF),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Text(
      message,
      style: TextStyle(
        color: isError ? Colors.red.shade800 : Colors.green.shade900,
      ),
    ),
  );
}
