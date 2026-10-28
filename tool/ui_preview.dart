// Local-only, synthetic preview. No authentication, database or provider calls.
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:hello/app_style.dart';
import 'package:hello/features/learning/bobo_chat.dart';
import 'package:hello/features/learning/exercise_interactions.dart';
import 'package:hello/services/bobo_api.dart';

void main() => runApp(const Preview());

class Preview extends StatefulWidget {
  const Preview({super.key});
  @override
  State<Preview> createState() => _PreviewState();
}

class _PreviewState extends State<Preview> {
  bool dark = false;
  bool large = false;
  bool reduced = false;
  bool lesson = false;
  String state = 'ready';
  String? selected;
  @override
  Widget build(BuildContext context) {
    AppColors.isDarkMode = dark;
    return MaterialApp(
      theme: dark ? AppTheme.dark() : AppTheme.light(),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(large ? 2 : 1),
          disableAnimations: reduced,
        ),
        child: child!,
      ),
      home: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(8),
                child: Wrap(
                  spacing: 8,
                  children: [
                    FilterChip(
                      label: const Text('Dark'),
                      selected: dark,
                      onSelected: (value) => setState(() => dark = value),
                    ),
                    FilterChip(
                      label: const Text('Large text'),
                      selected: large,
                      onSelected: (value) => setState(() => large = value),
                    ),
                    FilterChip(
                      label: const Text('Reduced motion'),
                      selected: reduced,
                      onSelected: (value) => setState(() => reduced = value),
                    ),
                    FilterChip(
                      label: const Text('Lesson'),
                      selected: lesson,
                      onSelected: (value) => setState(() => lesson = value),
                    ),
                    for (final mode in ['ready', 'empty', 'error', 'loading'])
                      ChoiceChip(
                        label: Text(mode),
                        selected: state == mode,
                        onSelected: (_) => setState(() => state = mode),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 390),
                    child: lesson
                        ? SingleChildScrollView(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(
                                  'A closer look at cells',
                                  style: Theme.of(
                                    context,
                                  ).textTheme.headlineSmall,
                                ),
                                const SizedBox(height: 16),
                                const LinearProgressIndicator(
                                  value: .5,
                                  semanticsLabel: 'Lesson progress',
                                ),
                                const SizedBox(height: 24),
                                const Text(
                                  'Select the word that does not belong.',
                                ),
                                const SizedBox(height: 12),
                                SpotMistakeInteraction(
                                  tokens: const ['Cells', 'are', 'rocks'],
                                  selected: selected,
                                  locked: false,
                                  onSelect: (value) =>
                                      setState(() => selected = value),
                                ),
                                const SizedBox(height: 24),
                                InlineFillBlankInteraction(
                                  parts: const ['Cells are ', ' units.'],
                                  wordLengths: const [6],
                                  locked: false,
                                  onChanged: (_) {},
                                ),
                              ],
                            ),
                          )
                        : BoboChatPanel(
                            key: ValueKey(state),
                            lessonTitle: 'What makes a cell alive?',
                            exerciseIndex: 0,
                            answerSubmitted: true,
                            answerCorrect: false,
                            onOpen: () async {
                              if (state == 'loading') {
                                return Completer<BoboConversation>().future;
                              }
                              if (state == 'error') {
                                throw const BoboApiException('unavailable');
                              }
                              return BoboConversation(
                                id: 'preview',
                                messages: state == 'empty'
                                    ? []
                                    : const [
                                        BoboChatTurn(
                                          role: 'user',
                                          content:
                                              'How is a cell different from a rock?',
                                        ),
                                        BoboChatTurn(
                                          role: 'assistant',
                                          content:
                                              'A cell uses energy and responds to its surroundings. What do you think it needs to stay alive?',
                                        ),
                                      ],
                              );
                            },
                            onSend: (_, message, _) async =>
                                'Good question. Let’s connect that to what a cell needs to stay alive.',
                            onClear: (_) async => const BoboConversation(
                              id: 'preview',
                              messages: [],
                            ),
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
}
