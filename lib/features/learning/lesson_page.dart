import 'package:flutter/material.dart';

import '../../app_style.dart';
import '../../models/app_models.dart';
import '../../services/auth_api.dart';
import 'lesson_exercises.dart';

class LessonPage extends StatefulWidget {
  const LessonPage({
    required this.accountId,
    required this.topicId,
    required this.level,
    super.key,
  });

  final String accountId;
  final String topicId;
  final LessonLevel level;

  @override
  State<LessonPage> createState() => _LessonPageState();
}

class _LessonPageState extends State<LessonPage> {
  final _answerController = TextEditingController();
  late DateTime _startedAt;
  List<LessonExercise> _exercises = <LessonExercise>[];
  String _lessonContent = '';
  final Set<String> _selectedAnswers = <String>{};
  final Map<String, String> _selectedMatches = <String, String>{};
  List<String> _orderedAnswers = <String>[];
  int _exerciseIndex = 0;
  int _correctAnswers = 0;
  bool? _answerWasCorrect;
  bool _isCompleting = false;
  int? _earnedXp;
  bool _isLoadingExercises = true;
  String? _exerciseLoadError;

  @override
  void initState() {
    super.initState();
    _fetchExercises();
  }

  @override
  void dispose() {
    _answerController.dispose();
    super.dispose();
  }

  Future<void> _fetchExercises() async {
    try {
      final lesson = await AuthApi().fetchLessonExercises(
        topicId: widget.topicId,
        lessonId: widget.level.id,
      );
      if (lesson.exercises.isEmpty) {
        throw AuthException('No exercises are available for this lesson yet.');
      }
      if (!mounted) return;
      _startedAt = DateTime.now();
      setState(() {
        _exercises = lesson.exercises;
        _lessonContent = lesson.content;
        _orderedAnswers = lesson.exercises.first.type ==
                LessonExerciseType.orderSteps
            ? List<String>.from(lesson.exercises.first.options)
            : <String>[];
        _isLoadingExercises = false;
        _exerciseLoadError = null;
      });
    } on AuthException catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoadingExercises = false;
        _exerciseLoadError = error.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoadingExercises = false;
        _exerciseLoadError = 'Could not load lesson exercises.';
      });
    }
  }

  void _retryLoadingExercises() {
    setState(() {
      _isLoadingExercises = true;
      _exerciseLoadError = null;
    });
    _fetchExercises();
  }

  bool get _isSummary =>
      _exercises.isNotEmpty && _exerciseIndex >= _exercises.length;

  bool get _hasAnswer {
    if (_isSummary) {
      return false;
    }
    if (_exercises[_exerciseIndex].type == LessonExerciseType.shortAnswer) {
      return _answerController.text.trim().isNotEmpty;
    }
    if (_exercises[_exerciseIndex].type == LessonExerciseType.orderSteps) {
      return _orderedAnswers.isNotEmpty;
    }
    if (_exercises[_exerciseIndex].type == LessonExerciseType.matching) {
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

  void _checkAnswer() {
    if (!_hasAnswer || _isSummary) {
      return;
    }

    final exercise = _exercises[_exerciseIndex];
    final isCorrect = switch (exercise.type) {
      LessonExerciseType.shortAnswer => exercise.correctAnswers.any(
        (answer) =>
            answer.toLowerCase() == _answerController.text.trim().toLowerCase(),
      ),
      LessonExerciseType.multipleSelect =>
        _selectedAnswers.length == exercise.correctAnswers.length &&
            _selectedAnswers.containsAll(exercise.correctAnswers),
      LessonExerciseType.singleChoice =>
        _selectedAnswers.firstOrNull == exercise.correctAnswers.firstOrNull,
      LessonExerciseType.orderSteps =>
          _orderedAnswers.join('\u0000') == exercise.correctOrder.join('\u0000'),
      LessonExerciseType.matching => exercise.pairs.every(
        (pair) => _selectedMatches[pair.left] == pair.right,
      ),
    };

    setState(() {
      _answerWasCorrect = isCorrect;
      if (isCorrect) {
        _correctAnswers++;
      }
    });
  }

  void _continueLesson() {
    final nextIndex = _exerciseIndex + 1;
    setState(() {
      _exerciseIndex = nextIndex;
      _selectedAnswers.clear();
      _selectedMatches.clear();
      _orderedAnswers = nextIndex < _exercises.length &&
              _exercises[nextIndex].type == LessonExerciseType.orderSteps
          ? List<String>.from(_exercises[nextIndex].options)
          : <String>[];
      _answerController.clear();
      _answerWasCorrect = null;
    });
  }

  Future<void> _finishLesson() async {
    if (_earnedXp != null) {
      Navigator.of(context).pop(widget.level.id);
      return;
    }
    setState(() => _isCompleting = true);
    try {
      final completion = await AuthApi().completeLesson(
        accountId: widget.accountId,
        topicId: widget.topicId,
        lessonId: widget.level.id,
        correctAnswers: _correctAnswers,
        exerciseCount: _exercises.length,
        durationSeconds: DateTime.now().difference(_startedAt).inSeconds,
      );
      if (!mounted) {
        return;
      }
      setState(() => _earnedXp = completion.earnedXp);
    } on AuthException catch (error) {
      _showMessage(error.message);
    } catch (_) {
      _showMessage('Could not save your lesson progress. Please try again.');
    } finally {
      if (mounted) {
        setState(() => _isCompleting = false);
      }
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
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
                    ? 'Loading lesson'
                    : _exerciseLoadError != null
                    ? 'Lesson unavailable'
                    : _isSummary
                    ? 'Lesson complete'
                    : 'Exercise ${_exerciseIndex + 1} of ${_exercises.length}',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              Text(
                '${(progress * 100).round()}%',
                style: const TextStyle(color: AppColors.mutedText),
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
              valueColor: const AlwaysStoppedAnimation<Color>(
                AppColors.success,
              ),
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
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      height: 1.45,
                    ),
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
              if (exercise.type == LessonExerciseType.shortAnswer)
                TextField(
                  controller: _answerController,
                  enabled: _answerWasCorrect == null,
                  textInputAction: TextInputAction.done,
                  onChanged: (_) => setState(() {}),
                  onSubmitted: (_) {
                    if (_answerWasCorrect == null && _hasAnswer) {
                      _checkAnswer();
                    }
                  },
                  decoration: const InputDecoration(
                    labelText: 'Your answer',
                    hintText: 'Type your answer',
                  ),
                )
              else if (exercise.type == LessonExerciseType.orderSteps)
                ReorderableListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _orderedAnswers.length,
                  onReorder: (oldIndex, newIndex) {
                    if (_answerWasCorrect != null) return;
                    setState(() {
                      if (newIndex > oldIndex) newIndex--;
                      final item = _orderedAnswers.removeAt(oldIndex);
                      _orderedAnswers.insert(newIndex, item);
                    });
                  },
                  itemBuilder: (context, index) => Card(
                    key: ValueKey(_orderedAnswers[index]),
                    child: ListTile(
                      leading: const Icon(Icons.drag_handle_rounded),
                      title: Text(_orderedAnswers[index]),
                    ),
                  ),
                )
              else if (exercise.type == LessonExerciseType.matching)
                Column(
                  children: exercise.pairs.map((pair) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: DropdownButtonFormField<String>(
                      value: _selectedMatches[pair.left],
                      decoration: InputDecoration(labelText: pair.left),
                      items: exercise.options.map((option) =>
                        DropdownMenuItem(value: option, child: Text(option)),
                      ).toList(),
                      onChanged: _answerWasCorrect == null
                          ? (value) => setState(() {
                              if (value == null) {
                                _selectedMatches.remove(pair.left);
                              } else {
                                _selectedMatches[pair.left] = value;
                              }
                            })
                          : null,
                    ),
                  )).toList(),
                )
              else
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: exercise.options.map((option) {
                    if (exercise.type == LessonExerciseType.multipleSelect) {
                      return FilterChip(
                        label: Text(option),
                        selected: _selectedAnswers.contains(option),
                        onSelected: _answerWasCorrect == null
                            ? (selected) => _toggleAnswer(option, selected)
                            : null,
                        selectedColor: AppColors.success.withValues(alpha: 0.2),
                        checkmarkColor: AppColors.success,
                      );
                    }

                    return ChoiceChip(
                      label: Text(option),
                      selected: _selectedAnswers.contains(option),
                      onSelected: _answerWasCorrect == null
                          ? (_) => _selectSingleAnswer(option)
                          : null,
                      selectedColor: AppColors.primaryLight.withValues(
                        alpha: 0.35,
                      ),
                    );
                  }).toList(),
                ),
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
                        _answerWasCorrect! ? 'Correct!' : 'Good try!',
                        style: const TextStyle(
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
                  onPressed: _answerWasCorrect != null
                      ? _continueLesson
                      : _hasAnswer
                      ? _checkAnswer
                      : null,
                  child: Text(
                    _answerWasCorrect != null ? 'Continue' : 'Check answer',
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

  Widget _buildSummary() {
    final accuracy = (_correctAnswers * 100 / _exercises.length).round();
    final elapsedSeconds = DateTime.now().difference(_startedAt).inSeconds;
    final rawXp = (_correctAnswers * 5) + ((_exercises.length - _correctAnswers) * 2);
    final estimatedXp = (rawXp * (elapsedSeconds > 180 ? 0.8 : 1)).round();
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
              const Icon(
                Icons.celebration_rounded,
                color: AppColors.success,
                size: 82,
              ),
              const SizedBox(height: 14),
              Text(
                'You did great!!!',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: AppColors.primaryDark,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'You finished ${widget.level.title}. Keep up the great work!',
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
                    _statRow('Exercises completed', '${_exercises.length}'),
                    const Divider(height: 24),
                    _statRow(
                      'Answers correct',
                      '$_correctAnswers / ${_exercises.length}',
                    ),
                    const Divider(height: 24),
                    _statRow('Accuracy', '$accuracy%'),
                    const Divider(height: 24),
                    _statRow(
                      _earnedXp == null
                          ? 'XP estimate (without potion)'
                          : 'XP earned',
                      '${_earnedXp ?? estimatedXp} XP',
                    ),
                    const Divider(height: 24),
                    _statRow('Time', elapsed),
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
                        ? 'Saving progress…'
                        : _earnedXp == null
                        ? 'Finish lesson'
                        : 'Back to lessons',
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
            style: const TextStyle(
              color: AppColors.mutedText,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Text(
          value,
          style: const TextStyle(
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
                child: const Text('Try again'),
              ),
            ],
          ),
        ),
      );
    } else {
      lessonBody = AnimatedSwitcher(
        duration: const Duration(milliseconds: 180),
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
      body: lessonBody,
    );
  }
}

class DevelopmentPage extends StatelessWidget {
  const DevelopmentPage({required this.title, super.key});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        backgroundColor: AppColors.pageBackground,
        foregroundColor: AppColors.primaryDark,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.tabPagePadding),
          child: Text(
            'More content is in development.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: AppColors.primaryDark,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
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
