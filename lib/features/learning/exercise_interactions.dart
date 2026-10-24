import 'package:flutter/material.dart';

import '../../app_style.dart';
import 'lesson_exercises.dart';

class ScenarioDecisionInteraction extends StatelessWidget {
  const ScenarioDecisionInteraction({
    required this.exercise,
    required this.selected,
    required this.locked,
    required this.onSelect,
    super.key,
  });

  final LessonExercise exercise;
  final String? selected;
  final bool locked;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: exercise.options.map((action) {
      final chosen = selected == action;
      return Card(
        clipBehavior: Clip.antiAlias,
        color: chosen ? AppColors.primaryLight.withValues(alpha: 0.2) : null,
        child: InkWell(
          onTap: locked ? null : () => onSelect(action),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      chosen
                          ? Icons.radio_button_checked
                          : Icons.radio_button_off,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        action,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
                if (chosen && exercise.consequences[action] != null) ...[
                  const Divider(height: 22),
                  Text(
                    'What may happen',
                    style: TextStyle(
                      color: AppColors.primaryDark,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(exercise.consequences[action]!),
                ],
              ],
            ),
          ),
        ),
      );
    }).toList(),
  );
}

class InlineFillBlankInteraction extends StatefulWidget {
  const InlineFillBlankInteraction({
    required this.parts,
    required this.locked,
    required this.onChanged,
    super.key,
  });

  final List<String> parts;
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
              width: 105,
              child: TextField(
                controller: _controllers[i],
                enabled: !widget.locked,
                textAlign: TextAlign.center,
                onChanged: (_) => widget.onChanged(
                  _controllers.map((controller) => controller.text).toList(),
                ),
                decoration: const InputDecoration(
                  hintText: 'word',
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
        return InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: locked ? null : () => onSelect(token),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppColors.primaryLight.withValues(alpha: 0.55)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              border: isSelected ? Border.all(color: AppColors.primary) : null,
            ),
            child: Text(
              token,
              style: const TextStyle(fontSize: 17, height: 1.5),
            ),
          ),
        );
      }).toList(),
    ),
  );
}

class DiagramLabelingInteraction extends StatelessWidget {
  const DiagramLabelingInteraction({
    required this.exercise,
    required this.assignments,
    required this.locked,
    required this.onAssign,
    super.key,
  });

  final LessonExercise exercise;
  final Map<String, String> assignments;
  final bool locked;
  final void Function(String target, String label) onAssign;

  static const _bodyPoints = <String, Alignment>{
    'brain': Alignment(0, -0.63),
    'head': Alignment(0, -0.63),
    'cerebrum': Alignment(0, -0.68),
    'brainstem': Alignment(0.18, -0.54),
    'cerebellum': Alignment(-0.18, -0.54),
    'lung': Alignment(-0.25, -0.15),
    'heart': Alignment(0.25, -0.13),
    'stomach': Alignment(0, 0.12),
    'kidney': Alignment(0, 0.35),
    'intestine': Alignment(0, 0.29),
    'bladder': Alignment(0, 0.49),
    'ureter': Alignment(0.2, 0.35),
    'artery': Alignment(0.3, -0.28),
    'vein': Alignment(-0.3, -0.28),
    'muscle': Alignment(0.38, 0.14),
    'bone': Alignment(-0.38, 0.14),
    'joint': Alignment(0.35, 0.02),
  };

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Container(
        height: 280,
        decoration: BoxDecoration(
          color: AppColors.infoBackground,
          borderRadius: BorderRadius.circular(AppRadii.input),
          border: Border.all(color: AppColors.border),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) => Stack(
            alignment: Alignment.center,
            children: [
              const Positioned.fill(
                child: CustomPaint(painter: _BodyDiagramPainter()),
              ),
              for (final pair in exercise.pairs)
                Align(
                  alignment: _pointFor(pair.left),
                  child: DragTarget<String>(
                    onWillAcceptWithDetails: (_) => !locked,
                    onAcceptWithDetails: (details) =>
                        onAssign(pair.left, details.data),
                    builder: (context, candidates, rejected) {
                      final value = assignments[pair.left];
                      return Container(
                        constraints: BoxConstraints(
                          maxWidth: constraints.maxWidth * 0.42,
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: candidates.isNotEmpty
                              ? AppColors.success.withValues(alpha: 0.22)
                              : Colors.white.withValues(alpha: 0.94),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppColors.primary,
                            width: 1.5,
                          ),
                        ),
                        child: value == null
                            ? Icon(Icons.add_circle_outline_rounded,
                                color: AppColors.primary, size: 22)
                            : _DraggableLabel(label: value, enabled: !locked),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 14),
      Wrap(
        alignment: WrapAlignment.center,
        spacing: 10,
        runSpacing: 10,
        children: exercise.options
            .where((label) => !assignments.values.contains(label))
            .map((label) => _DraggableLabel(label: label, enabled: !locked))
            .toList(),
      ),
    ],
  );

  Alignment _pointFor(String target) {
    final lower = target.toLowerCase();
    for (final entry in _bodyPoints.entries) {
      if (lower.contains(entry.key)) return entry.value;
    }
    final index = exercise.pairs.indexWhere((pair) => pair.left == target);
    const points = [
      Alignment(-0.24, -0.14),
      Alignment(0.24, -0.14),
      Alignment(0, 0.28),
      Alignment(0, -0.63),
    ];
    return points[index % points.length];
  }
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
        : const ['A only', 'Both', 'B only'];
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

class PredictionProcessInteraction extends StatefulWidget {
  const PredictionProcessInteraction({
    required this.exercise,
    required this.selected,
    required this.locked,
    required this.onSelect,
    required this.onPaused,
    super.key,
  });

  final LessonExercise exercise;
  final String? selected;
  final bool locked;
  final ValueChanged<String> onSelect;
  final ValueChanged<bool> onPaused;

  @override
  State<PredictionProcessInteraction> createState() =>
      _PredictionProcessInteractionState();
}

class _PredictionProcessInteractionState
    extends State<PredictionProcessInteraction>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _paused = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1700),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _pause() {
    if (_paused || widget.locked) return;
    setState(() => _paused = true);
    _controller.stop();
    widget.onPaused(true);
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.infoBackground,
          borderRadius: BorderRadius.circular(AppRadii.input),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          children: [
            Text(
              widget.exercise.visualStages.isNotEmpty
                  ? widget.exercise.visualStages.first
                  : 'A process is underway…',
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 18),
            AnimatedBuilder(
              animation: _controller,
              builder: (context, _) => SizedBox(
                height: 38,
                child: Stack(
                  alignment: Alignment.centerLeft,
                  children: [
                    Container(
                      height: 8,
                      decoration: BoxDecoration(
                        color: AppColors.border,
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    FractionallySizedBox(
                      widthFactor: _controller.value,
                      child: Container(
                        height: 8,
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                    ),
                    Align(
                      alignment: Alignment(_controller.value * 2 - 1, 0),
                      child: Container(
                        width: 27,
                        height: 27,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE34F63),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                          boxShadow: const [
                            BoxShadow(color: Color(0x33000000), blurRadius: 4),
                          ],
                        ),
                        child: const Center(
                          child: Icon(Icons.bubble_chart_rounded,
                              color: Colors.white, size: 17),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (_paused && widget.locked)
              Text(
                widget.exercise.visualStages.length > 1
                    ? widget.exercise.visualStages[1]
                    : 'The process is paused before its next step.',
              ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      if (!_paused)
        FilledButton.icon(
          onPressed: _pause,
          icon: const Icon(Icons.pause_circle_outline),
          label: const Text('Pause and predict'),
        )
      else ...[
        Text(
          'What happens next?',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: AppColors.primaryDark,
          ),
        ),
        for (final option in widget.exercise.options)
          Card(
            color: widget.selected == option
                ? AppColors.primaryLight.withValues(alpha: 0.24)
                : null,
            child: ListTile(
              leading: Icon(
                widget.selected == option
                    ? Icons.radio_button_checked
                    : Icons.radio_button_off,
              ),
              title: Text(option),
              onTap: widget.locked ? null : () => widget.onSelect(option),
            ),
          ),
      ],
    ],
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
                            'Drag a component here',
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

class _BodyDiagramPainter extends CustomPainter {
  const _BodyDiagramPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final fill = Paint()..color = const Color(0xFFFFD9BE);
    final outline = Paint()
      ..color = const Color(0xFF9D7162)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    final center = size.width / 2;
    canvas.drawCircle(
      Offset(center, size.height * 0.15),
      size.width * 0.09,
      fill,
    );
    canvas.drawCircle(
      Offset(center, size.height * 0.15),
      size.width * 0.09,
      outline,
    );
    final torso = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(center, size.height * 0.47),
        width: size.width * 0.34,
        height: size.height * 0.48,
      ),
      const Radius.circular(50),
    );
    canvas.drawRRect(torso, fill);
    canvas.drawRRect(torso, outline);
    canvas.drawLine(
      Offset(center - 24, size.height * 0.34),
      Offset(size.width * 0.2, size.height * 0.66),
      outline,
    );
    canvas.drawLine(
      Offset(center + 24, size.height * 0.34),
      Offset(size.width * 0.8, size.height * 0.66),
      outline,
    );
    canvas.drawLine(
      Offset(center - 25, size.height * 0.68),
      Offset(center - 35, size.height * 0.93),
      outline,
    );
    canvas.drawLine(
      Offset(center + 25, size.height * 0.68),
      Offset(center + 35, size.height * 0.93),
      outline,
    );
    final organ = Paint()
      ..color = const Color(0xFFE67878).withValues(alpha: 0.8);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(center - 15, size.height * 0.43),
        width: 24,
        height: 37,
      ),
      organ,
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(center + 15, size.height * 0.43),
        width: 24,
        height: 37,
      ),
      organ,
    );
    canvas.drawCircle(
      Offset(center + 3, size.height * 0.47),
      9,
      Paint()..color = const Color(0xFFE24F62),
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(center, size.height * 0.60),
        width: 38,
        height: 18,
      ),
      Paint()..color = const Color(0xFFB98257),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
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
