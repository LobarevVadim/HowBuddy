import 'package:flutter/material.dart';

import '../../app_style.dart';
import '../../models/app_models.dart';
import '../../services/auth_api.dart';
import 'lesson_exercises.dart';

class LessonPage extends StatefulWidget {
  const LessonPage({required this.topicId, required this.level, super.key});

  final String topicId;
  final LessonLevel level;

  @override
  State<LessonPage> createState() => _LessonPageState();
}

class _LessonPageState extends State<LessonPage> {
  static const int _exerciseCount = 10;

  final _answerController = TextEditingController();
  final _startedAt = DateTime.now();
  late final List<LessonExercise> _exercises = buildExercisesForTopic(
    widget.topicId,
  );
  final Set<String> _selectedAnswers = <String>{};
  int _exerciseIndex = 0;
  int _correctAnswers = 0;
  bool? _answerWasCorrect;
  bool _isCompleting = false;

  @override
  void dispose() {
    _answerController.dispose();
    super.dispose();
  }

  bool get _isSummary => _exerciseIndex >= _exercises.length;

  bool get _hasAnswer {
    if (_isSummary) {
      return false;
    }
    if (_exercises[_exerciseIndex].type == LessonExerciseType.shortAnswer) {
      return _answerController.text.trim().isNotEmpty;
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
    };

    setState(() {
      _answerWasCorrect = isCorrect;
      if (isCorrect) {
        _correctAnswers++;
      }
    });
  }

  void _continueLesson() {
    setState(() {
      _exerciseIndex++;
      _selectedAnswers.clear();
      _answerController.clear();
      _answerWasCorrect = null;
    });
  }

  Future<void> _finishLesson() async {
    setState(() => _isCompleting = true);
    try {
      await AuthApi().completeLesson(
        topicId: widget.topicId,
        lessonId: widget.level.id,
      );
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(widget.level.id);
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
    final progress = (_exerciseIndex / _exercises.length).clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Text(
                _isSummary
                    ? 'Lesson complete'
                    : 'Exercise ${_exerciseIndex + 1} of $_exerciseCount',
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
                      '$_correctAnswers / $_exerciseCount',
                    ),
                    const Divider(height: 24),
                    _statRow('Accuracy', '$accuracy%'),
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
                    _isCompleting ? 'Saving progress…' : 'Finish lesson',
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
      body: AnimatedSwitcher(
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
      ),
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
