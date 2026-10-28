import 'lesson_session_controller.dart';
import 'package:flutter/material.dart';

import '../../app_style.dart';
import '../../models/app_models.dart';
import '../../services/auth_api.dart';
import '../../services/bobo_api.dart';
import '../../services/ui_translations.dart';
import 'exercise_interactions.dart';
import 'lesson_exercises.dart';
import '../../services/theme_preferences.dart';
import 'bobo_chat.dart';

class LessonPage extends StatefulWidget {
  const LessonPage({
    this.controller,
    required this.sessionId,
    required this.accountId,
    required this.topicId,
    required this.level,
    super.key,
  });

  final String accountId;
  final LessonSessionController? controller;
  final String sessionId;
  final String topicId;
  final LessonLevel level;

  @override
  State<LessonPage> createState() => _LessonPageState();
}

class _LessonPageState extends State<LessonPage> {
  final _answerController = TextEditingController();
  late final LessonSessionController _session;
  List<LessonExercise> get _exercises => _session.lesson?.exercises ?? const [];
  String get _lessonContent => _session.lesson?.content ?? '';
  int get _correctAnswers => _session.correctCount;
  Map<int, bool?> get _attemptedExerciseResults => _session.attemptedResults;
  bool get _isCheckingAnswer => _session.isChecking;
  bool get _isCompleting => _session.isCompleting;
  int? get _earnedXp => _session.completion?.earnedXp;
  bool get _isLoadingExercises => _session.loading;
  String? get _exerciseLoadError =>
      _session.loadError == null ? null : uiText(context, _session.loadError!);
  final Set<String> _selectedAnswers = <String>{};
  final Map<String, String> _selectedMatches = <String, String>{};
  List<String> _orderedAnswers = <String>[];
  List<String> _blankAnswers = <String>[];
  List<String?> _flowchartSlots = <String?>[];
  int _exerciseIndex = 0;
  bool? _answerWasCorrect;
  @override
  void initState() {
    super.initState();
    _session =
        (widget.controller ??
              LessonSessionController(
                loadContent: () => AuthApi().fetchLessonExercises(
                  topicId: widget.topicId,
                  lessonId: widget.level.id,
                ),
                loadAttempts: () => BoboTutorApi().getAttemptedExercises(
                  topicId: widget.topicId,
                  lessonId: widget.level.id,
                ),
                recordAttempt: (index, answer) => BoboTutorApi().recordAttempt(
                  sessionId: widget.sessionId,
                  topicId: widget.topicId,
                  lessonId: widget.level.id,
                  exerciseIndex: index,
                  studentAnswer: answer,
                  response: _responseForExercise(index),
                ),
                complete: (correct, count, duration) =>
                    AuthApi().completeLesson(
                      completionId: widget.sessionId,
                      accountId: widget.accountId,
                      topicId: widget.topicId,
                      lessonId: widget.level.id,
                      correctAnswers: correct,
                      exerciseCount: count,
                      durationSeconds: duration,
                    ),
              ))
          ..addListener(_sessionChanged);
    _fetchExercises();
  }

  @override
  void dispose() {
    _session.removeListener(_sessionChanged);
    if (widget.controller == null) _session.dispose();
    _answerController.dispose();
    super.dispose();
  }

  void _sessionChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _fetchExercises() async {
    final loaded = await _session.load();
    if (!loaded || !mounted) return;
    setState(() {
      final first = _exercises.first;
      _orderedAnswers = first.type == LessonExerciseType.orderSteps
          ? List.from(first.options)
          : [];
      _flowchartSlots = _usesFlowchart(first.type)
          ? List<String?>.filled(first.correctOrder.length, null)
          : [];
    });
  }

  void _retryLoadingExercises() => _fetchExercises();
  bool get _isSummary =>
      _exercises.isNotEmpty && _exerciseIndex >= _exercises.length;

  bool get _hasAnswer {
    if (_isSummary) {
      return false;
    }
    final type = _exercises[_exerciseIndex].type;
    if (type == LessonExerciseType.shortAnswer) {
      return _answerController.text.trim().isNotEmpty;
    }
    if (type == LessonExerciseType.fillInTheBlank) {
      return _blankAnswers.length ==
              _exercises[_exerciseIndex].correctOrder.length &&
          _blankAnswers.every((answer) => answer.trim().isNotEmpty);
    }
    if (type == LessonExerciseType.orderSteps) {
      return _orderedAnswers.isNotEmpty;
    }
    if (type == LessonExerciseType.buildTheProcess) {
      return _flowchartSlots.isNotEmpty &&
          _flowchartSlots.every((slot) => slot != null);
    }
    if (type == LessonExerciseType.matching ||
        type == LessonExerciseType.categorization ||
        type == LessonExerciseType.causeAndEffect ||
        type == LessonExerciseType.compareAndContrast) {
      return _selectedMatches.length == _exercises[_exerciseIndex].pairs.length;
    }
    return _selectedAnswers.isNotEmpty;
  }

  void _selectSingleAnswer(String answer) {
    if (_answerWasCorrect != null) {
      return;
    }
    setState(() {
      _selectedAnswers
        ..clear()
        ..add(answer);
    });
  }

  void _toggleAnswer(String answer, bool selected) {
    if (_answerWasCorrect != null) {
      return;
    }
    setState(() {
      if (selected) {
        _selectedAnswers.add(answer);
      } else {
        _selectedAnswers.remove(answer);
      }
    });
  }

  Future<void> _checkAnswer() async {
    if (!_hasAnswer || _isSummary || _isCheckingAnswer) return;
    try {
      final correct = await _session.submit(_exerciseIndex, _answerForBobo());
      if (mounted && correct != null) {
        setState(() => _answerWasCorrect = correct);
      }
    } catch (_) {
      if (!mounted) return;
      _showMessage(
        uiText(
          context,
          'Could not save this answer. Check your connection and try again.',
        ),
      );
    }
  }

  void _continueLesson() {
    final nextIndex = _exerciseIndex + 1;
    setState(() {
      _exerciseIndex = nextIndex;
      _selectedAnswers.clear();
      _selectedMatches.clear();
      _blankAnswers = <String>[];
      _orderedAnswers =
          nextIndex < _exercises.length &&
              _exercises[nextIndex].type == LessonExerciseType.orderSteps
          ? List<String>.from(_exercises[nextIndex].options)
          : <String>[];
      _flowchartSlots =
          nextIndex < _exercises.length &&
              _usesFlowchart(_exercises[nextIndex].type)
          ? List<String?>.filled(
              _exercises[nextIndex].correctOrder.length,
              null,
            )
          : <String?>[];
      _answerController.clear();
      _answerWasCorrect = null;
    });
  }

  Future<void> _finishLesson() async {
    if (_earnedXp != null) {
      Navigator.of(context).pop(widget.level.id);
      return;
    }
    try {
      final result = await _session.finish();
      if (!mounted || result == null) return;
      if (result.streakFreezesAwarded > 0) {
        await _showStreakFreezeReward(result.streakFreezesAwarded);
      }
    } on AuthException catch (error) {
      if (mounted) _showMessage(error.message);
    } catch (_) {
      if (mounted) {
        _showMessage(
          uiText(
            context,
            'Could not save your lesson progress. Please try again.',
          ),
        );
      }
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(uiText(context, message))));
  }

  Future<void> _showStreakFreezeReward(int awarded) => showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      icon: Icon(Icons.ac_unit_rounded, color: AppColors.primary, size: 36),
      title: Text(
        awarded == 1
            ? uiText(context, 'You earned a Streak Freeze!')
            : uiText(
                context,
                '{count} Streak Freezes earned!',
                args: {'count': '$awarded'},
              ),
      ),
      content: Text(
        uiText(
          context,
          'A Streak Freeze automatically protects your streak if you miss a day.',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: Text(uiText(context, 'Continue')),
        ),
      ],
    ),
  );

  bool _usesFlowchart(LessonExerciseType type) =>
      type == LessonExerciseType.buildTheProcess;

  String _answerForBobo() {
    if (_isSummary || _exercises.isEmpty) {
      return '';
    }
    final type = _exercises[_exerciseIndex].type;
    if (type == LessonExerciseType.shortAnswer) return _answerController.text;
    if (type == LessonExerciseType.fillInTheBlank) {
      return _blankAnswers.join(' | ');
    }
    if (type == LessonExerciseType.orderSteps) {
      return _orderedAnswers.join(' → ');
    }
    if (type == LessonExerciseType.buildTheProcess) {
      return _flowchartSlots.whereType<String>().join(' → ');
    }
    if (type == LessonExerciseType.matching ||
        type == LessonExerciseType.categorization ||
        type == LessonExerciseType.causeAndEffect ||
        type == LessonExerciseType.compareAndContrast) {
      return _selectedMatches.entries
          .map((entry) => '${entry.key}: ${entry.value}')
          .join('; ');
    }
    return _selectedAnswers.join(', ');
  }

  Object _responseForExercise(int index) => switch (_exercises[index].type) {
    LessonExerciseType.shortAnswer => _answerController.text,
    LessonExerciseType.multipleSelect => _selectedAnswers.toList(),
    LessonExerciseType.fillInTheBlank => List<String>.from(_blankAnswers),
    LessonExerciseType.orderSteps => List<String>.from(_orderedAnswers),
    LessonExerciseType.buildTheProcess =>
      _flowchartSlots.whereType<String>().toList(),
    LessonExerciseType.matching ||
    LessonExerciseType.categorization ||
    LessonExerciseType.causeAndEffect ||
    LessonExerciseType.compareAndContrast => Map<String, String>.from(
      _selectedMatches,
    ),
    _ => _selectedAnswers.firstOrNull ?? '',
  };

  void _openBobo() {
    final hasActiveExercise = !_isSummary && _exercises.isNotEmpty;
    final exerciseIndex = hasActiveExercise ? _exerciseIndex : null;
    if (hasActiveExercise &&
        !_attemptedExerciseResults.containsKey(_exerciseIndex)) {
      _showBoboLockedDialog();
      return;
    }
    _openBoboChat(exerciseIndex: exerciseIndex);
  }

  void _openBoboChat({required int? exerciseIndex}) {
    final api = BoboTutorApi();
    showBoboChatSheet(
      context,
      lessonTitle: widget.level.title,
      exerciseIndex: exerciseIndex,
      answerSubmitted:
          exerciseIndex != null &&
          _attemptedExerciseResults.containsKey(exerciseIndex),
      answerCorrect: exerciseIndex == null
          ? null
          : _answerWasCorrect ?? _attemptedExerciseResults[exerciseIndex],
      onOpen: () => api.openConversation(
        topicId: widget.topicId,
        lessonId: widget.level.id,
      ),
      onSend: (conversationId, message, teachingAction) => api.sendMessage(
        conversationId: conversationId,
        topicId: widget.topicId,
        lessonId: widget.level.id,
        exerciseIndex: exerciseIndex,
        teachingAction: teachingAction,
        message: message,
      ),
      onClear: (conversationId) async {
        await api.clearConversation(conversationId);
        return api.openConversation(
          topicId: widget.topicId,
          lessonId: widget.level.id,
        );
      },
    );
  }

  Future<void> _showBoboLockedDialog() async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(uiText(context, 'Bobo is locked')),
        content: Text(
          uiText(context, 'Try answering first, or get a hint! \u{1F49C}'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(uiText(context, 'Cancel')),
          ),
          FilledButton.icon(
            onPressed: () async {
              Navigator.pop(dialogContext);
              await _requestBoboHint(_exerciseIndex);
            },
            icon: const Icon(Icons.lightbulb_outline_rounded),
            label: Text(uiText(context, 'Get a hint')),
          ),
        ],
      ),
    );
  }

  Future<void> _requestBoboHint(int exerciseIndex) async {
    final api = BoboTutorApi();
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        content: Row(
          children: [
            const CircularProgressIndicator(),
            const SizedBox(width: 16),
            Expanded(child: Text(uiText(context, 'Bobo is thinking...'))),
          ],
        ),
      ),
    );
    try {
      final conversation = await api.openConversation(
        topicId: widget.topicId,
        lessonId: widget.level.id,
      );
      final hint = await api.sendMessage(
        conversationId: conversation.id,
        topicId: widget.topicId,
        lessonId: widget.level.id,
        exerciseIndex: exerciseIndex,
        teachingAction: 'giveHint',
        message: 'Give me one Socratic hint for this exercise.',
      );
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(uiText(context, "Bobo's hint")),
          content: SingleChildScrollView(child: Text(hint)),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(uiText(context, 'Back to lesson')),
            ),
          ],
        ),
      );
    } catch (_) {
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            uiText(
              context,
              'Bobo could not get a hint right now. Please try again.',
            ),
          ),
        ),
      );
    }
  }

  Widget _buildProgress() {
    final progress = _exercises.isEmpty
        ? 0.0
        : (_exerciseIndex / _exercises.length).clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Text(
                _isLoadingExercises
                    ? uiText(context, 'Loading lesson')
                    : _exerciseLoadError != null
                    ? uiText(context, 'Lesson unavailable')
                    : _isSummary
                    ? uiText(context, 'Lesson complete')
                    : uiText(
                        context,
                        'Exercise {current} of {total}',
                        args: {
                          'current': '${_exerciseIndex + 1}',
                          'total': '${_exercises.length}',
                        },
                      ),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              Text(
                '${(progress * 100).round()}%',
                style: TextStyle(color: AppColors.mutedText),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 9,
              backgroundColor: AppColors.border,
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.success),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExercise(LessonExercise exercise) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.tabPagePadding),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(
                    lessonShapeIcon(widget.level.shape),
                    color: AppColors.primary,
                    size: 30,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    widget.level.title,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: AppColors.primaryDark,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              if (_exerciseIndex == 0 && _lessonContent.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.infoBackground,
                    borderRadius: BorderRadius.circular(AppRadii.input),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Text(
                    _lessonContent,
                    style: Theme.of(
                      context,
                    ).textTheme.bodyLarge?.copyWith(height: 1.45),
                  ),
                ),
                const SizedBox(height: 22),
              ],
              Text(
                exercise.prompt,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: AppColors.text,
                  fontWeight: FontWeight.w800,
                  height: 1.25,
                ),
              ),
              const SizedBox(height: 24),
              _buildInteraction(exercise),
              if (_answerWasCorrect != null) ...[
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _answerWasCorrect!
                        ? AppColors.success.withValues(alpha: 0.12)
                        : AppColors.infoBackground,
                    borderRadius: BorderRadius.circular(AppRadii.input),
                    border: Border.all(
                      color: _answerWasCorrect!
                          ? AppColors.success.withValues(alpha: 0.6)
                          : AppColors.border,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        uiText(
                          context,
                          _answerWasCorrect! ? 'Correct!' : 'Good try!',
                        ),
                        style: TextStyle(
                          color: AppColors.primaryDark,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(exercise.explanation),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 28),
              SizedBox(
                height: AppSizes.primaryButtonHeight,
                child: FilledButton(
                  onPressed: _isCheckingAnswer
                      ? null
                      : _answerWasCorrect != null
                      ? _continueLesson
                      : _hasAnswer
                      ? _checkAnswer
                      : null,
                  child: _isCheckingAnswer
                      ? const SizedBox.square(
                          dimension: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(
                          _answerWasCorrect != null
                              ? uiText(context, 'Continue')
                              : uiText(context, 'Check answer'),
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInteraction(LessonExercise exercise) {
    final locked = _answerWasCorrect != null || _isCheckingAnswer;
    switch (exercise.type) {
      case LessonExerciseType.singleChoice:
      case LessonExerciseType.trueFalse:
        return Column(
          children: exercise.options
              .map(
                (option) => Card(
                  color: _selectedAnswers.contains(option)
                      ? AppColors.primaryLight.withValues(alpha: 0.22)
                      : null,
                  child: ListTile(
                    leading: Icon(
                      _selectedAnswers.contains(option)
                          ? Icons.radio_button_checked
                          : Icons.radio_button_off,
                    ),
                    title: Text(option),
                    onTap: locked ? null : () => _selectSingleAnswer(option),
                  ),
                ),
              )
              .toList(),
        );
      case LessonExerciseType.multipleSelect:
        return Column(
          children: exercise.options
              .map(
                (option) => Card(
                  child: CheckboxListTile(
                    value: _selectedAnswers.contains(option),
                    title: Text(option),
                    controlAffinity: ListTileControlAffinity.leading,
                    onChanged: locked
                        ? null
                        : (value) => _toggleAnswer(option, value ?? false),
                  ),
                ),
              )
              .toList(),
        );
      case LessonExerciseType.shortAnswer:
        return TextField(
          controller: _answerController,
          enabled: !locked,
          textInputAction: TextInputAction.done,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            labelText: uiText(context, 'Your answer'),
            hintText: uiText(context, 'Type your answer'),
          ),
        );
      case LessonExerciseType.orderSteps:
        return ReorderableListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          buildDefaultDragHandles: false,
          itemCount: _orderedAnswers.length,
          onReorder: locked
              ? (_, _) {}
              : (oldIndex, newIndex) {
                  setState(() {
                    if (newIndex > oldIndex) newIndex--;
                    final item = _orderedAnswers.removeAt(oldIndex);
                    _orderedAnswers.insert(newIndex, item);
                  });
                },
          itemBuilder: (context, index) => ReorderableDragStartListener(
            key: ValueKey(_orderedAnswers[index]),
            index: index,
            child: Card(
              child: ListTile(
                leading: const Icon(Icons.drag_handle_rounded),
                title: Text(_orderedAnswers[index]),
              ),
            ),
          ),
        );
      case LessonExerciseType.matching:
        return Column(
          children: exercise.pairs
              .map(
                (pair) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: DropdownButtonFormField<String>(
                    initialValue: _selectedMatches[pair.left],
                    decoration: InputDecoration(labelText: pair.left),
                    items: exercise.options
                        .map(
                          (option) => DropdownMenuItem(
                            value: option,
                            child: Text(option),
                          ),
                        )
                        .toList(),
                    onChanged: locked
                        ? null
                        : (value) => setState(() {
                            if (value == null) {
                              _selectedMatches.remove(pair.left);
                            } else {
                              _selectedMatches[pair.left] = value;
                            }
                          }),
                  ),
                ),
              )
              .toList(),
        );
      case LessonExerciseType.fillInTheBlank:
        return InlineFillBlankInteraction(
          key: ValueKey('fill-$_exerciseIndex'),
          parts: exercise.paragraphParts,
          wordLengths: exercise.correctOrder
              .map((word) => word.length)
              .toList(),
          locked: locked,
          onChanged: (answers) => setState(() => _blankAnswers = answers),
        );
      case LessonExerciseType.spotTheMistake:
        return SpotMistakeInteraction(
          tokens: exercise.options,
          selected: _selectedAnswers.firstOrNull,
          locked: locked,
          onSelect: _selectSingleAnswer,
        );
      case LessonExerciseType.categorization:
        return CategorizationInteraction(
          exercise: exercise,
          assignments: _selectedMatches,
          locked: locked,
          onAssign: (card, category) => setState(() {
            _selectedMatches[card] = category;
          }),
        );
      case LessonExerciseType.causeAndEffect:
        return CauseEffectLinesInteraction(
          exercise: exercise,
          connections: _selectedMatches,
          locked: locked,
          onConnect: (cause, effect) => setState(() {
            _selectedMatches.removeWhere((key, value) => value == effect);
            _selectedMatches[cause] = effect;
          }),
        );
      case LessonExerciseType.compareAndContrast:
        return VennDiagramInteraction(
          exercise: exercise,
          assignments: _selectedMatches,
          locked: locked,
          onAssign: (statement, region) => setState(() {
            _selectedMatches[statement] = region;
          }),
        );
      case LessonExerciseType.buildTheProcess:
        return BuildProcessInteraction(
          exercise: exercise,
          slots: _flowchartSlots,
          locked: locked,
          onPlace: (slot, component) => setState(() {
            _flowchartSlots = _flowchartSlots
                .map((value) => value == component ? null : value)
                .toList();
            _flowchartSlots[slot] = component;
          }),
        );
    }
  }

  Widget _buildSummary() {
    final accuracy = (_correctAnswers * 100 / _exercises.length).round();
    final elapsedSeconds = _session.elapsedSeconds;
    final elapsed =
        '${elapsedSeconds ~/ 60}:${(elapsedSeconds % 60).toString().padLeft(2, '0')}';

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.tabPagePadding),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(
                Icons.celebration_rounded,
                color: AppColors.success,
                size: 82,
              ),
              const SizedBox(height: 14),
              Text(
                uiText(context, 'You did great!!!'),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: AppColors.primaryDark,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                uiText(
                  context,
                  'You finished {lesson}. Keep up the great work!',
                  args: {'lesson': widget.level.title},
                ),
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(color: AppColors.mutedText),
              ),
              const SizedBox(height: 28),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.authPanelBackground,
                  borderRadius: BorderRadius.circular(AppRadii.heroImage),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  children: [
                    _statRow(
                      uiText(context, 'Exercises completed'),
                      '${_exercises.length}',
                    ),
                    const Divider(height: 24),
                    _statRow(
                      uiText(context, 'Answers correct'),
                      '$_correctAnswers / ${_exercises.length}',
                    ),
                    const Divider(height: 24),
                    _statRow(uiText(context, 'Accuracy'), '$accuracy%'),
                    const Divider(height: 24),
                    _statRow(
                      uiText(context, 'XP earned'),
                      _earnedXp == null ? '—' : '$_earnedXp XP',
                    ),
                    const Divider(height: 24),
                    _statRow(uiText(context, 'Time'), elapsed),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                height: AppSizes.primaryButtonHeight,
                child: FilledButton.icon(
                  onPressed: _isCompleting ? null : _finishLesson,
                  icon: _isCompleting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.check_circle_outline_rounded),
                  label: Text(
                    _isCompleting
                        ? uiText(context, 'Saving progress...')
                        : _earnedXp == null
                        ? uiText(context, 'Finish lesson')
                        : uiText(context, 'Back to lessons'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statRow(String label, String value) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: AppColors.mutedText,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: AppColors.primaryDark,
            fontSize: 17,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    ThemePreferencesScope.watch(context);
    final Widget lessonBody;
    if (_isLoadingExercises) {
      lessonBody = const Center(child: CircularProgressIndicator());
    } else if (_exerciseLoadError != null) {
      lessonBody = Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.tabPagePadding),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_exerciseLoadError!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _retryLoadingExercises,
                child: Text(uiText(context, 'Try again')),
              ),
            ],
          ),
        ),
      );
    } else {
      lessonBody = AnimatedSwitcher(
        duration: AppMotion.duration(context),
        child: _isSummary
            ? KeyedSubtree(
                key: const ValueKey('lesson-summary'),
                child: _buildSummary(),
              )
            : KeyedSubtree(
                key: ValueKey(_exerciseIndex),
                child: _buildExercise(_exercises[_exerciseIndex]),
              ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.level.title),
        backgroundColor: AppColors.pageBackground,
        foregroundColor: AppColors.primaryDark,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: _buildProgress(),
        ),
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          lessonBody,
          if (_exercises.isNotEmpty && _exerciseLoadError == null)
            Positioned(
              right: 18,
              bottom: 18,
              child: SafeArea(
                top: false,
                child: BoboLessonButton(
                  locked:
                      !_isSummary &&
                      !_attemptedExerciseResults.containsKey(_exerciseIndex),
                  onPressed: _openBobo,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

IconData lessonShapeIcon(String shape) {
  switch (shape) {
    case 'triangle':
      return Icons.change_history_rounded;
    case 'hexagon':
      return Icons.hexagon_outlined;
    case 'square':
      return Icons.crop_square_rounded;
    case 'circle':
      return Icons.circle_outlined;
    case 'star':
    default:
      return Icons.star_border_rounded;
  }
}
