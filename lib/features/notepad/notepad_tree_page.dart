import 'package:flutter/material.dart';

import '../../app_style.dart';
import '../../models/app_models.dart';
import '../../services/auth_api.dart';
import '../../services/theme_preferences.dart';
import '../../services/ui_translations.dart';

class NotepadTreePage extends StatefulWidget {
  const NotepadTreePage({
    required this.accountId,
    required this.onTopicSelected,
    super.key,
  });

  final String accountId;
  final ValueChanged<String> onTopicSelected;

  @override
  State<NotepadTreePage> createState() => _NotepadTreePageState();
}

class _NotepadTreePageState extends State<NotepadTreePage> {
  late final Future<NotepadTreeNode> _tree = AuthApi().fetchNotepadTree(
    widget.accountId,
  );

  @override
  Widget build(BuildContext context) {
    ThemePreferencesScope.watch(context);
    return FutureBuilder<NotepadTreeNode>(
      future: _tree,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Text(
              uiText(context, 'Could not load notepad tree.'),
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(color: AppColors.mutedText),
            ),
          );
        }

        return NotepadTreeCanvas(
          root: snapshot.data!,
          onTopicSelected: widget.onTopicSelected,
        );
      },
    );
  }
}

class NotepadTreeCanvas extends StatefulWidget {
  const NotepadTreeCanvas({
    required this.root,
    required this.onTopicSelected,
    super.key,
  });

  final NotepadTreeNode root;
  final ValueChanged<String> onTopicSelected;

  static const Size canvasSize = Size(3800, 1320);

  @override
  State<NotepadTreeCanvas> createState() => _NotepadTreeCanvasState();
}

class _NotepadTreeCanvasState extends State<NotepadTreeCanvas> {
  final TransformationController _transformationController =
      TransformationController();
  static const _subjectKeys = <String>[
    'Math',
    'Biology',
    'Geography',
    'History',
    'Physics',
    'Chemistry',
    'Geometry',
  ];
  String? _selectedSubject;
  bool _initialTransformApplied = false;

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ThemePreferencesScope.watch(context);
    final isPopularQuestions = _selectedSubject == null;
    final activeRoot = NotepadTreeNode(
      id: 'active-root',
      title: uiText(
        context,
        isPopularQuestions ? 'Popular Questions' : _selectedSubject!,
      ),
      isCompleted: isPopularQuestions && widget.root.isCompleted,
      children: isPopularQuestions
          ? widget.root.children
          : [
              const NotepadTreeNode(
                id: 'under-development',
                title: 'Content is currently under development',
                children: [],
                isCompleted: false,
              ),
            ],
    );
    final positionedNodes = _layoutTree(activeRoot, isPopularQuestions);

    return LayoutBuilder(
      builder: (context, constraints) {
        final viewport = constraints.biggest;
        if (!_initialTransformApplied &&
            viewport.width.isFinite &&
            viewport.height.isFinite &&
            viewport.width > 0 &&
            viewport.height > 0) {
          _initialTransformApplied = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            final scale = (viewport.width / NotepadTreeCanvas.canvasSize.width)
                .clamp(0.58, 0.72)
                .toDouble();
            final dx =
                (viewport.width - NotepadTreeCanvas.canvasSize.width * scale) /
                2;
            final dy =
                (viewport.height -
                    NotepadTreeCanvas.canvasSize.height * scale) /
                2;
            _transformationController.value = Matrix4.diagonal3Values(
              scale,
              scale,
              1,
            )..setTranslationRaw(dx, dy, 0);
          });
        }

        return InteractiveViewer(
          transformationController: _transformationController,
          constrained: false,
          alignment: Alignment.topLeft,
          boundaryMargin: const EdgeInsets.all(800),
          minScale: 0.16,
          maxScale: 2.4,
          child: SizedBox(
            width: NotepadTreeCanvas.canvasSize.width,
            height: NotepadTreeCanvas.canvasSize.height,
            child: Stack(
              children: [
                Positioned.fill(
                  child: CustomPaint(
                    painter: NotepadTreePainter(nodes: positionedNodes),
                  ),
                ),
                for (final node in positionedNodes)
                  Positioned(
                    left: node.offset.dx - (node.width / 2),
                    top: node.offset.dy - 35,
                    width: node.width,
                    child: NotepadTreeCard(
                      node: node.node,
                      labelOverride: node.labelOverride,
                      onPressed: node.isPlaceholder
                          ? null
                          : () => _openNode(node),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _openNode(PositionedNotepadNode positionedNode) {
    final subjectKey = positionedNode.subjectKey;
    if (subjectKey != null) {
      setState(() => _selectedSubject = subjectKey == 'Popular Questions'
          ? null
          : subjectKey);
      return;
    }

    final node = positionedNode.node;
    if (node.id == 'active-root') return;
    widget.onTopicSelected(node.id);
  }

  List<PositionedNotepadNode> _layoutTree(
    NotepadTreeNode root,
    bool isPopularQuestions,
  ) {
    final switcherKeys = isPopularQuestions
        ? _subjectKeys
        : [
            ..._subjectKeys.where((key) => key != _selectedSubject),
            'Popular Questions',
          ];
    const selectorXPositions = [260.0, 800.0, 1340.0, 1900.0, 2460.0, 3000.0, 3540.0];
    final nodes = <PositionedNotepadNode>[
      for (var index = 0; index < switcherKeys.length; index++)
        PositionedNotepadNode(
          node: NotepadTreeNode(
            id: 'subject-switch-$index',
            title: uiText(context, switcherKeys[index]),
            children: const [],
            isCompleted: false,
          ),
          offset: Offset(selectorXPositions[index], 90),
          width: switcherKeys[index] == 'Popular Questions' ? 250 : 210,
          parentId: root.id,
          subjectKey: switcherKeys[index],
        ),
      PositionedNotepadNode(
        node: root,
        offset: const Offset(1900, 350),
        width: 270,
        parentId: null,
      ),
    ];

    final topicY = 610.0;
    final questionY = 870.0;
    final leafY = 1170.0;
    final topicXPositions = [720.0, 1900.0, 3080.0];

    for (var topicIndex = 0; topicIndex < root.children.length; topicIndex++) {
      final topic = root.children[topicIndex];
      final topicX = root.children.length == 1
          ? 1900.0
          : topicXPositions[topicIndex];
      nodes.add(
        PositionedNotepadNode(
          node: topic,
          offset: Offset(topicX, topicY),
          width: 300,
          parentId: root.id,
          labelOverride: topic.id == 'under-development'
              ? uiText(context, 'Content is currently under development')
              : null,
          isPlaceholder: topic.id == 'under-development',
        ),
      );

      for (
        var questionIndex = 0;
        questionIndex < topic.children.length;
        questionIndex++
      ) {
        final question = topic.children[questionIndex];
        final questionX = topicX + ((questionIndex - 1) * 360);
        nodes.add(
          PositionedNotepadNode(
            node: question,
            offset: Offset(questionX, questionY),
            width: 220,
            parentId: topic.id,
          ),
        );

        for (
          var leafIndex = 0;
          leafIndex < question.children.length;
          leafIndex++
        ) {
          final leaf = question.children[leafIndex];
          final leafX = questionX + ((leafIndex - 1) * 125);
          nodes.add(
            PositionedNotepadNode(
              node: leaf,
              offset: Offset(leafX, leafY),
              width: 116,
              parentId: question.id,
            ),
          );
        }
      }
    }

    return nodes;
  }
}

class PositionedNotepadNode {
  final NotepadTreeNode node;
  final Offset offset;
  final double width;
  final String? parentId;
  final String? subjectKey;
  final String? labelOverride;
  final bool isPlaceholder;

  const PositionedNotepadNode({
    required this.node,
    required this.offset,
    required this.width,
    required this.parentId,
    this.subjectKey,
    this.labelOverride,
    this.isPlaceholder = false,
  });
}

class NotepadTreePainter extends CustomPainter {
  const NotepadTreePainter({required this.nodes});

  final List<PositionedNotepadNode> nodes;

  @override
  void paint(Canvas canvas, Size size) {
    final nodesById = {for (final node in nodes) node.node.id: node};
    final paint = Paint()
      ..color = AppColors.primaryLight
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    for (final node in nodes) {
      final parentId = node.parentId;
      if (parentId == null) {
        continue;
      }

      final parent = nodesById[parentId];
      if (parent == null) {
        continue;
      }

      final upper = parent.offset.dy <= node.offset.dy ? parent : node;
      final lower = identical(upper, parent) ? node : parent;
      final path = Path()
        ..moveTo(upper.offset.dx, upper.offset.dy + 36)
        ..cubicTo(
          upper.offset.dx,
          (upper.offset.dy + lower.offset.dy) / 2,
          lower.offset.dx,
          (upper.offset.dy + lower.offset.dy) / 2,
          lower.offset.dx,
          lower.offset.dy - 36,
        );
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant NotepadTreePainter oldDelegate) {
    return oldDelegate.nodes != nodes;
  }
}

class NotepadTreeCard extends StatelessWidget {
  const NotepadTreeCard({
    required this.node,
    this.labelOverride,
    required this.onPressed,
    super.key,
  });

  final NotepadTreeNode node;
  final String? labelOverride;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    ThemePreferencesScope.watch(context);
    final background = node.isCompleted
        ? AppColors.success.withValues(alpha: 0.18)
        : AppColors.inputBackground;
    final border = node.isCompleted
        ? AppColors.success
        : AppColors.primaryLight;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(AppRadii.button),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(AppRadii.button),
            border: Border.all(color: border, width: 3),
            boxShadow: const [
              BoxShadow(
                color: Color(0x1F6F482C),
                blurRadius: 8,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Text(
            labelOverride ?? node.title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.primaryDark,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ),
    );
  }
}
