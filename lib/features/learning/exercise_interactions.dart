import 'package:flutter/material.dart';

import '../../app_style.dart';
import '../../services/ui_translations.dart';
import 'lesson_exercises.dart';

class InlineFillBlankInteraction extends StatefulWidget {
  const InlineFillBlankInteraction({
    required this.parts,
    required this.wordLengths,
    required this.locked,
    required this.onChanged,
    super.key,
  });

  final List<String> parts;
  final List<int> wordLengths;
  final bool locked;
  final ValueChanged<List<String>> onChanged;

  @override
  State<InlineFillBlankInteraction> createState() =>
      _InlineFillBlankInteractionState();
}

class _InlineFillBlankInteractionState
    extends State<InlineFillBlankInteraction> {
  late final List<TextEditingController> _controllers;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(
      (widget.parts.length - 1).clamp(0, 5),
      (_) => TextEditingController(),
    );
  }

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: AppColors.infoBackground,
      borderRadius: BorderRadius.circular(AppRadii.input),
      border: Border.all(color: AppColors.border),
    ),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 6,
        runSpacing: 12,
        children: [
          for (var i = 0; i < _controllers.length; i++) ...[
            Text(
              widget.parts[i],
              style: const TextStyle(fontSize: 17, height: 1.5),
            ),
            SizedBox(
              width: (widget.wordLengths.elementAtOrNull(i) ?? 5) * 13.0 + 18,
              child: TextField(
                controller: _controllers[i],
                enabled: !widget.locked,
                textAlign: TextAlign.center,
                maxLength: widget.wordLengths.elementAtOrNull(i),
                onChanged: (_) => widget.onChanged(
                  _controllers.map((controller) => controller.text).toList(),
                ),
                decoration: InputDecoration(
                  labelText: '${uiText(context, 'Answer')} ${i + 1}',
                  helperText: List.filled(
                    widget.wordLengths.elementAtOrNull(i) ?? 5,
                    '_',
                  ).join(' '),
                  helperStyle: TextStyle(
                    color: AppColors.mutedText,
                    letterSpacing: 1.5,
                  ),
                  counterText: '',
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 10,
                  ),
                ),
              ),
            ),
          ],
          if (widget.parts.isNotEmpty)
            Text(
              widget.parts.last,
              style: const TextStyle(fontSize: 17, height: 1.5),
            ),
        ],
      ),
    ),
  );
}

class SpotMistakeInteraction extends StatelessWidget {
  const SpotMistakeInteraction({
    required this.tokens,
    required this.selected,
    required this.locked,
    required this.onSelect,
    super.key,
  });

  final List<String> tokens;
  final String? selected;
  final bool locked;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppColors.infoBackground,
      borderRadius: BorderRadius.circular(AppRadii.input),
      border: Border.all(color: AppColors.border),
    ),
    child: Wrap(
      spacing: 4,
      runSpacing: 8,
      children: tokens.map((token) {
        final isSelected = selected == token;
        return Semantics(
          selected: isSelected,
          button: true,
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: locked ? null : () => onSelect(token),
            child: AnimatedContainer(
              duration: AppMotion.duration(context),
              constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.primaryLight.withValues(alpha: 0.55)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
                border: isSelected
                    ? Border.all(color: AppColors.primary)
                    : null,
              ),
              child: Text(
                token,
                style: const TextStyle(fontSize: 17, height: 1.5),
              ),
            ),
          ),
        );
      }).toList(),
    ),
  );
}

class CategorizationInteraction extends StatelessWidget {
  const CategorizationInteraction({
    required this.exercise,
    required this.assignments,
    required this.locked,
    required this.onAssign,
    super.key,
  });

  final LessonExercise exercise;
  final Map<String, String> assignments;
  final bool locked;
  final void Function(String card, String category) onAssign;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: exercise.pairs
            .where((pair) => !assignments.containsKey(pair.left))
            .map((pair) => _DraggableLabel(label: pair.left, enabled: !locked))
            .toList(),
      ),
      const SizedBox(height: 14),
      for (final category in exercise.options)
        DragTarget<String>(
          onWillAcceptWithDetails: (_) => !locked,
          onAcceptWithDetails: (details) => onAssign(details.data, category),
          builder: (context, candidates, rejected) {
            final assigned = assignments.entries
                .where((entry) => entry.value == category)
                .map((entry) => entry.key)
                .toList();
            return Container(
              constraints: const BoxConstraints(minHeight: 76),
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: candidates.isNotEmpty
                    ? AppColors.success.withValues(alpha: 0.14)
                    : AppColors.inputBackground,
                borderRadius: BorderRadius.circular(AppRadii.input),
                border: Border.all(color: AppColors.border, width: 1.5),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    category,
                    style: TextStyle(
                      color: AppColors.primaryDark,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Wrap(
                    spacing: 7,
                    runSpacing: 7,
                    children: assigned
                        .map(
                          (card) => Draggable<String>(
                            data: card,
                            maxSimultaneousDrags: locked ? 0 : 1,
                            feedback: Material(
                              color: Colors.transparent,
                              child: _LabelCard(label: card),
                            ),
                            childWhenDragging: Opacity(
                              opacity: 0.35,
                              child: _LabelCard(label: card),
                            ),
                            child: _LabelCard(label: card),
                          ),
                        )
                        .toList(),
                  ),
                ],
              ),
            );
          },
        ),
    ],
  );
}

class CauseEffectLinesInteraction extends StatelessWidget {
  const CauseEffectLinesInteraction({
    required this.exercise,
    required this.connections,
    required this.locked,
    required this.onConnect,
    super.key,
  });

  final LessonExercise exercise;
  final Map<String, String> connections;
  final bool locked;
  final void Function(String cause, String effect) onConnect;

  @override
  Widget build(BuildContext context) {
    final effects = exercise.options;
    return LayoutBuilder(
      builder: (context, constraints) {
        final rowHeight = 68.0;
        final height = rowHeight * exercise.pairs.length;
        return SizedBox(
          height: height,
          child: Stack(
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: _ConnectionPainter(
                    causes: exercise.pairs.map((pair) => pair.left).toList(),
                    effects: effects,
                    connections: Map<String, String>.of(connections),
                    rowHeight: rowHeight,
                  ),
                ),
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      children: exercise.pairs
                          .map(
                            (pair) => SizedBox(
                              height: rowHeight,
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: Draggable<String>(
                                  data: pair.left,
                                  maxSimultaneousDrags: locked ? 0 : 1,
                                  feedback: Material(
                                    color: Colors.transparent,
                                    child: _LabelCard(label: pair.left),
                                  ),
                                  childWhenDragging: Opacity(
                                    opacity: 0.4,
                                    child: _LabelCard(label: pair.left),
                                  ),
                                  child: _LabelCard(label: pair.left),
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                  SizedBox(width: constraints.maxWidth * 0.22),
                  Expanded(
                    child: Column(
                      children: effects
                          .map(
                            (effect) => SizedBox(
                              height: rowHeight,
                              child: Align(
                                alignment: Alignment.centerRight,
                                child: DragTarget<String>(
                                  onWillAcceptWithDetails: (_) => !locked,
                                  onAcceptWithDetails: (details) =>
                                      onConnect(details.data, effect),
                                  builder: (context, candidates, rejected) =>
                                      AnimatedContainer(
                                        duration: const Duration(
                                          milliseconds: 120,
                                        ),
                                        width: double.infinity,
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: candidates.isNotEmpty
                                              ? AppColors.success.withValues(
                                                  alpha: 0.18,
                                                )
                                              : AppColors.inputBackground,
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          border: Border.all(
                                            color: AppColors.border,
                                            width: 1.4,
                                          ),
                                        ),
                                        child: Text(
                                          effect,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                      ),
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class VennDiagramInteraction extends StatelessWidget {
  const VennDiagramInteraction({
    required this.exercise,
    required this.assignments,
    required this.locked,
    required this.onAssign,
    super.key,
  });

  final LessonExercise exercise;
  final Map<String, String> assignments;
  final bool locked;
  final void Function(String statement, String region) onAssign;

  @override
  Widget build(BuildContext context) {
    final regions = exercise.categories.length >= 3
        ? exercise.categories.take(3).toList()
        : [
            uiText(context, 'A only'),
            uiText(context, 'Both'),
            uiText(context, 'B only'),
          ];
    return Column(
      children: [
        SizedBox(
          height: 220,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final diameter = (constraints.maxWidth * 0.62)
                  .clamp(170.0, 208.0)
                  .toDouble();
              return Stack(
                alignment: Alignment.center,
                children: [
                  Positioned(
                    left: constraints.maxWidth * 0.38 - diameter / 2,
                    child: _vennCircle(
                      exercise.categories.isNotEmpty
                          ? exercise.categories.first
                          : 'A',
                      AppColors.primaryLight.withValues(alpha: 0.45),
                      diameter,
                    ),
                  ),
                  Positioned(
                    left: constraints.maxWidth * 0.62 - diameter / 2,
                    child: _vennCircle(
                      exercise.categories.length > 1
                          ? exercise.categories[1]
                          : 'B',
                      AppColors.success.withValues(alpha: 0.35),
                      diameter,
                    ),
                  ),
                  for (var i = 0; i < regions.length; i++)
                    Align(
                      alignment: i == 0
                          ? const Alignment(-0.5, 0.25)
                          : i == 1
                          ? Alignment.center
                          : const Alignment(0.5, 0.25),
                      child: DragTarget<String>(
                        onWillAcceptWithDetails: (_) => !locked,
                        onAcceptWithDetails: (details) =>
                            onAssign(details.data, regions[i]),
                        builder: (context, candidates, rejected) {
                          final cards = assignments.entries
                              .where((entry) => entry.value == regions[i])
                              .map((entry) => entry.key)
                              .toList();
                          return Container(
                            constraints: const BoxConstraints(
                              minWidth: 72,
                              maxWidth: 112,
                              minHeight: 54,
                            ),
                            padding: const EdgeInsets.all(5),
                            decoration: BoxDecoration(
                              color: candidates.isNotEmpty
                                  ? AppColors.success.withValues(alpha: 0.45)
                                  : Colors.white.withValues(alpha: 0.78),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: AppColors.primary.withValues(
                                  alpha: 0.65,
                                ),
                              ),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  regions[i],
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                for (final card in cards)
                                  _DraggableLabel(
                                    label: card,
                                    enabled: !locked,
                                  ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                ],
              );
            },
          ),
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: exercise.pairs
              .where((pair) => !assignments.containsKey(pair.left))
              .map(
                (pair) => _DraggableLabel(label: pair.left, enabled: !locked),
              )
              .toList(),
        ),
      ],
    );
  }

  Widget _vennCircle(String label, Color color, double diameter) => Container(
    width: diameter,
    height: diameter,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: color,
      border: Border.all(
        color: AppColors.primary.withValues(alpha: 0.65),
        width: 2,
      ),
    ),
    alignment: const Alignment(0, -0.76),
    child: Text(
      label,
      textAlign: TextAlign.center,
      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12),
    ),
  );
}

class BuildProcessInteraction extends StatelessWidget {
  const BuildProcessInteraction({
    required this.exercise,
    required this.slots,
    required this.locked,
    required this.onPlace,
    super.key,
  });

  final LessonExercise exercise;
  final List<String?> slots;
  final bool locked;
  final void Function(int slot, String component) onPlace;

  @override
  Widget build(BuildContext context) {
    final available = exercise.options
        .where((option) => !slots.contains(option))
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < slots.length; i++) ...[
          DragTarget<String>(
            onWillAcceptWithDetails: (_) => !locked,
            onAcceptWithDetails: (details) => onPlace(i, details.data),
            builder: (context, candidates, rejected) => Container(
              constraints: const BoxConstraints(minHeight: 62),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: candidates.isNotEmpty
                    ? AppColors.success.withValues(alpha: 0.18)
                    : AppColors.inputBackground,
                borderRadius: BorderRadius.circular(AppRadii.input),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.65),
                  width: 1.5,
                ),
              ),
              child: Row(
                children: [
                  CircleAvatar(radius: 15, child: Text('${i + 1}')),
                  const SizedBox(width: 10),
                  Expanded(
                    child: slots[i] == null
                        ? Text(
                            uiText(context, 'Drag a component here'),
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: AppColors.mutedText,
                            ),
                          )
                        : _DraggableLabel(label: slots[i]!, enabled: !locked),
                  ),
                ],
              ),
            ),
          ),
          if (i < slots.length - 1)
            Center(
              child: Icon(
                Icons.arrow_downward_rounded,
                color: AppColors.primary,
              ),
            ),
        ],
        const SizedBox(height: 14),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: available
              .map(
                (component) =>
                    _DraggableLabel(label: component, enabled: !locked),
              )
              .toList(),
        ),
      ],
    );
  }
}

class _DraggableLabel extends StatelessWidget {
  const _DraggableLabel({required this.label, required this.enabled});
  final String label;
  final bool enabled;

  @override
  Widget build(BuildContext context) => Draggable<String>(
    data: label,
    maxSimultaneousDrags: enabled ? 1 : 0,
    feedback: Material(
      color: Colors.transparent,
      child: _LabelCard(label: label),
    ),
    childWhenDragging: Opacity(opacity: 0.35, child: _LabelCard(label: label)),
    child: _LabelCard(label: label),
  );
}

class _LabelCard extends StatelessWidget {
  const _LabelCard({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(maxWidth: 220),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: BoxDecoration(
      color: AppColors.inputBackground,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(
        color: AppColors.primary.withValues(alpha: 0.7),
        width: 1.4,
      ),
      boxShadow: const [
        BoxShadow(
          color: Color(0x14000000),
          blurRadius: 4,
          offset: Offset(0, 2),
        ),
      ],
    ),
    child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
  );
}

class _ConnectionPainter extends CustomPainter {
  const _ConnectionPainter({
    required this.causes,
    required this.effects,
    required this.connections,
    required this.rowHeight,
  });
  final List<String> causes;
  final List<String> effects;
  final Map<String, String> connections;
  final double rowHeight;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.primary
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    for (final entry in connections.entries) {
      final from = causes.indexOf(entry.key);
      final to = effects.indexOf(entry.value);
      if (from < 0 || to < 0) continue;
      final start = Offset(size.width * 0.40, rowHeight * (from + 0.5));
      final end = Offset(size.width * 0.60, rowHeight * (to + 0.5));
      final path = Path()
        ..moveTo(start.dx, start.dy)
        ..cubicTo(
          size.width * 0.47,
          start.dy,
          size.width * 0.53,
          end.dy,
          end.dx,
          end.dy,
        );
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _ConnectionPainter oldDelegate) =>
      oldDelegate.connections != connections ||
      oldDelegate.causes != causes ||
      oldDelegate.effects != effects;
}
