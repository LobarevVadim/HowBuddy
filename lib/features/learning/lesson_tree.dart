import 'package:flutter/material.dart';

import '../../app_style.dart';
import '../../models/app_models.dart';
import '../../services/auth_api.dart';
import '../../services/gamification_api.dart';
import '../../shared/app_widgets.dart';
import 'lesson_page.dart';
import '../../services/theme_preferences.dart';

class TreeLessonsPage extends StatefulWidget {
  const TreeLessonsPage({
    required this.accountId,
    required this.topicId,
    required this.onGameStateChanged,
    required this.onNoHearts,
    required this.onTopicSelected,
    required this.onTopicCompleted,
    super.key,
  });

  final String accountId;
  final String topicId;
  final ValueChanged<GameState> onGameStateChanged;
  final VoidCallback onNoHearts;
  final ValueChanged<String> onTopicSelected;
  final VoidCallback onTopicCompleted;

  @override
  State<TreeLessonsPage> createState() => _TreeLessonsPageState();
}

class _TreeLessonsPageState extends State<TreeLessonsPage> {
  late Future<TreeData> _treeData = _loadTreeData();
  final Set<String> _completedLessonIds = <String>{};

  @override
  void didUpdateWidget(covariant TreeLessonsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.topicId != widget.topicId) {
      _completedLessonIds.clear();
      _treeData = _loadTreeData();
    }
  }

  void _openQuestion(LessonQuestion question) {
    widget.onTopicSelected(question.id);
  }

  void _handleLessonCompleted(String lessonId) {
    setState(() {
      _completedLessonIds.add(lessonId);
      _treeData = _loadTreeData();
    });
    widget.onTopicCompleted();
  }

  Future<bool> _startLesson() async {
    final result = await GamificationApi().startLesson(widget.accountId);
    widget.onGameStateChanged(result.state);
    return result.lessonAllowed;
  }

  Future<TreeData> _loadTreeData() => AuthApi().fetchTreeData(
    topicId: widget.topicId,
    accountId: widget.accountId,
  );

  List<LessonLevel> _levelsWithLocalCompletions(List<LessonLevel> levels) {
    return levels.map((level) {
      final locallyCompleted = _completedLessonIds.contains(level.id);
      final previousLessonCompleted =
          level.level > 1 &&
          _completedLessonIds.contains('lesson-${level.level - 1}');

      if (!locallyCompleted && !previousLessonCompleted) {
        return level;
      }

      return LessonLevel(
        id: level.id,
        level: level.level,
        shape: level.shape,
        title: level.title,
        isCompleted: level.isCompleted || locallyCompleted,
        isUnlocked:
            level.isUnlocked || locallyCompleted || previousLessonCompleted,
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    ThemePreferencesScope.watch(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.tabPagePadding),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 28,
                  vertical: 24,
                ),
                decoration: BoxDecoration(
                  color: AppColors.authPanelBackground,
                  borderRadius: BorderRadius.circular(AppRadii.heroImage),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FutureBuilder<TreeData>(
                      future: _treeData,
                      builder: (context, snapshot) {
                        final question =
                            snapshot.data?.topic.question ??
                            'Explore the human body';
                        return Text(
                          question,
                          style: Theme.of(context).textTheme.headlineMedium
                              ?.copyWith(
                                color: AppColors.primaryDark,
                                fontWeight: FontWeight.w900,
                              ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.sectionGap),
              FutureBuilder<TreeData>(
                future: _treeData,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const TreePanel(
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }

                  if (snapshot.hasError) {
                    return TreePanel(
                      child: Center(
                        child: Text(
                          'Could not load lessons.',
                          style: Theme.of(context).textTheme.bodyLarge
                              ?.copyWith(color: AppColors.mutedText),
                        ),
                      ),
                    );
                  }

                  final treeData = snapshot.data!;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TreePanel(
                        child: LessonTree(
                          accountId: widget.accountId,
                          topicId: widget.topicId,
                          levels: _levelsWithLocalCompletions(treeData.levels),
                          onLessonStarting: _startLesson,
                          onNoHearts: widget.onNoHearts,
                          onLessonCompleted: _handleLessonCompleted,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sectionGap),
                      NextQuestionPanel(
                        questions: treeData.nextQuestions,
                        onQuestionSelected: _openQuestion,
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class NextQuestionPanel extends StatelessWidget {
  const NextQuestionPanel({
    required this.questions,
    required this.onQuestionSelected,
    super.key,
  });

  final List<LessonQuestion> questions;
  final ValueChanged<LessonQuestion> onQuestionSelected;

  @override
  Widget build(BuildContext context) {
    ThemePreferencesScope.watch(context);
    if (questions.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 22),
      decoration: BoxDecoration(
        color: AppColors.authPanelBackground,
        borderRadius: BorderRadius.circular(AppRadii.heroImage),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'What do you want to know next?',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: AppColors.primaryDark,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: AppSpacing.sectionGap),
          for (final question in questions) ...[
            OutlinedButton(
              onPressed: () => onQuestionSelected(question),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primaryDark,
                alignment: Alignment.centerLeft,
                side: BorderSide(color: AppColors.border),
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 16,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadii.button),
                ),
              ),
              child: Text(
                question.question,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
            const SizedBox(height: AppSpacing.socialButtonGap),
          ],
        ],
      ),
    );
  }
}

class LessonTree extends StatelessWidget {
  const LessonTree({
    required this.accountId,
    required this.topicId,
    required this.levels,
    required this.onLessonStarting,
    required this.onNoHearts,
    required this.onLessonCompleted,
    super.key,
  });

  final String accountId;
  final String topicId;
  final List<LessonLevel> levels;
  final Future<bool> Function() onLessonStarting;
  final VoidCallback onNoHearts;
  final ValueChanged<String> onLessonCompleted;

  static const double _topPadding = 84;
  static const double _bottomPadding = 110;
  static const double _levelGap = 118;

  @override
  Widget build(BuildContext context) {
    ThemePreferencesScope.watch(context);
    final treeHeight =
        _topPadding + _bottomPadding + ((levels.length - 1) * _levelGap);

    return SizedBox(
      height: treeHeight.clamp(620, double.infinity),
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: LessonTreePainter(
                levels: levels,
                topPadding: _topPadding,
                levelGap: _levelGap,
              ),
            ),
          ),
          for (var index = 0; index < levels.length; index++)
            LessonNode(
              accountId: accountId,
              topicId: topicId,
              level: levels[index],
              onLessonStarting: onLessonStarting,
              onNoHearts: onNoHearts,
              top: _topPadding + (index * _levelGap) - 38,
              isLeft: index.isOdd,
              onLessonCompleted: onLessonCompleted,
            ),
        ],
      ),
    );
  }
}

class LessonTreePainter extends CustomPainter {
  const LessonTreePainter({
    required this.levels,
    required this.topPadding,
    required this.levelGap,
  });

  final List<LessonLevel> levels;
  final double topPadding;
  final double levelGap;

  @override
  void paint(Canvas canvas, Size size) {
    final branchPaint = Paint()
      ..color = AppColors.primaryLight
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 10;
    final leafPaint = Paint()
      ..color = AppColors.success
      ..style = PaintingStyle.fill;
    final trunkX = size.width * 0.50;
    final topY = topPadding - 42;
    final bottomY = topPadding + ((levels.length - 1) * levelGap) + 76;

    canvas.drawLine(Offset(trunkX, topY), Offset(trunkX, bottomY), branchPaint);

    for (var index = 0; index < levels.length; index++) {
      final nodeY = topPadding + (index * levelGap);
      final isLeft = index.isOdd;
      final nodeX = isLeft ? size.width * 0.30 : size.width * 0.70;
      _drawBranch(
        canvas,
        branchPaint,
        Offset(trunkX, nodeY),
        Offset(nodeX, nodeY + 12),
      );
    }

    for (var index = 0; index < levels.length; index++) {
      final nodeY = topPadding + (index * levelGap);
      final isLeft = index.isOdd;
      final leaf = Offset(
        isLeft ? size.width * 0.56 : size.width * 0.44,
        nodeY + 38,
      );
      canvas.save();
      canvas.translate(leaf.dx, leaf.dy);
      canvas.rotate(isLeft ? 0.6 : -0.6);
      canvas.drawOval(
        Rect.fromCenter(center: Offset.zero, width: 18, height: 28),
        leafPaint,
      );
      canvas.restore();
    }
  }

  void _drawBranch(Canvas canvas, Paint paint, Offset start, Offset end) {
    final path = Path()
      ..moveTo(start.dx, start.dy)
      ..quadraticBezierTo((start.dx + end.dx) / 2, start.dy, end.dx, end.dy);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class LessonNode extends StatelessWidget {
  const LessonNode({
    required this.accountId,
    required this.topicId,
    required this.level,
    required this.onLessonStarting,
    required this.onNoHearts,
    required this.top,
    required this.isLeft,
    required this.onLessonCompleted,
    super.key,
  });

  final String accountId;
  final String topicId;
  final LessonLevel level;
  final Future<bool> Function() onLessonStarting;
  final VoidCallback onNoHearts;
  final double top;
  final bool isLeft;
  final ValueChanged<String> onLessonCompleted;

  @override
  Widget build(BuildContext context) {
    ThemePreferencesScope.watch(context);
    final borderColor = level.isCompleted
        ? AppColors.success
        : level.isUnlocked
        ? AppColors.primaryLight
        : AppColors.border;
    final iconColor = level.isCompleted
        ? AppColors.success
        : level.isUnlocked
        ? AppColors.primary
        : AppColors.mutedText;

    return Positioned(
      top: top,
      left: isLeft ? 88 : null,
      right: isLeft ? null : 88,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: level.isUnlocked
              ? () async {
                  final hasHeart = await onLessonStarting();
                  if (!context.mounted) return;
                  if (!hasHeart) {
                    onNoHearts();
                    return;
                  }
                  final completedLessonId = await Navigator.of(context)
                      .push<String>(
                        MaterialPageRoute(
                          builder: (_) => LessonPage(
                            accountId: accountId,
                            topicId: topicId,
                            level: level,
                          ),
                        ),
                      );
                  if (completedLessonId != null) {
                    onLessonCompleted(completedLessonId);
                  }
                }
              : null,
          child: Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              color: AppColors.inputBackground,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: borderColor, width: 4),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x1F6F482C),
                  blurRadius: 8,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Icon(
              level.isCompleted
                  ? Icons.check_rounded
                  : lessonShapeIcon(level.shape),
              color: iconColor,
              size: 42,
            ),
          ),
        ),
      ),
    );
  }
}
