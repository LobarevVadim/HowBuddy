import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../app_style.dart';
import '../../services/bobo_api.dart';
import '../../services/ui_translations.dart';

Future<void> showBoboChatSheet(
  BuildContext context, {
  required String lessonTitle,
  required int? exerciseIndex,
  required bool answerSubmitted,
  required bool? answerCorrect,
  required Future<BoboConversation> Function() onOpen,
  required Future<String> Function(
    String conversationId,
    String message,
    String? teachingAction,
  )
  onSend,
  required Future<BoboConversation> Function(String conversationId) onClear,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    backgroundColor: AppColors.pageBackground,
    builder: (context) => FractionallySizedBox(
      heightFactor: 0.78,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: _BoboChatPanel(
            lessonTitle: lessonTitle,
            exerciseIndex: exerciseIndex,
            answerSubmitted: answerSubmitted,
            answerCorrect: answerCorrect,
            onOpen: onOpen,
            onSend: onSend,
            onClear: onClear,
          ),
        ),
      ),
    ),
  );
}

class BoboLessonButton extends StatelessWidget {
  const BoboLessonButton({
    required this.onPressed,
    this.locked = false,
    super.key,
  });

  final VoidCallback onPressed;
  final bool locked;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: uiText(context, locked ? 'Bobo is locked' : 'Ask Bobo'),
    child: Tooltip(
      message: uiText(context, locked ? 'Bobo is locked' : 'Ask Bobo'),
      child: Material(
        color: AppColors.inputBackground,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.button),
          side: BorderSide(color: AppColors.border, width: 1.5),
        ),
        elevation: 7,
        shadowColor: Colors.black.withValues(alpha: 0.2),
        child: InkWell(
          onTap: onPressed,
          customBorder: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.button),
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadii.button),
                child: Stack(
                  children: [
                    SvgPicture.asset(
                      'assets/icon/cropped_how_buddy.svg',
                      width: 62,
                      height: 62,
                      fit: BoxFit.cover,
                    ),
                    if (locked)
                      Positioned.fill(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: Colors.grey.withValues(alpha: 0.7),
                            borderRadius: BorderRadius.circular(
                              AppRadii.button,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              if (locked)
                Positioned(
                  right: -8,
                  top: -9,
                  child: const IgnorePointer(
                    child: Text(
                      '\u{1F512}',
                      style: TextStyle(
                        fontSize: 34.2,
                        shadows: [Shadow(color: Colors.white, blurRadius: 3)],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _BoboChatPanel extends StatefulWidget {
  const _BoboChatPanel({
    required this.lessonTitle,
    required this.exerciseIndex,
    required this.answerSubmitted,
    required this.answerCorrect,
    required this.onOpen,
    required this.onSend,
    required this.onClear,
  });

  final String lessonTitle;
  final int? exerciseIndex;
  final bool answerSubmitted;
  final bool? answerCorrect;
  final Future<BoboConversation> Function() onOpen;
  final Future<String> Function(
    String conversationId,
    String message,
    String? teachingAction,
  )
  onSend;
  final Future<BoboConversation> Function(String conversationId) onClear;

  @override
  State<_BoboChatPanel> createState() => _BoboChatPanelState();
}

class _BoboChatPanelState extends State<_BoboChatPanel> {
  final _inputController = TextEditingController();
  final _scrollController = ScrollController();
  final List<BoboChatTurn> _turns = [];
  bool _isSending = false;
  bool _isLoadingConversation = true;
  String? _errorCode;
  String? _conversationId;

  @override
  void initState() {
    super.initState();
    _loadConversation();
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _send({String? action, String? presetMessage}) async {
    final message = (presetMessage ?? _inputController.text).trim();
    final conversationId = _conversationId;
    if (message.isEmpty ||
        _isSending ||
        _isLoadingConversation ||
        conversationId == null ||
        message.length > 1200) {
      return;
    }
    setState(() {
      _turns.add(BoboChatTurn(role: 'user', content: message));
      _inputController.clear();
      _isSending = true;
      _errorCode = null;
    });
    _scrollToEnd();
    try {
      final reply = await widget.onSend(conversationId, message, action);
      if (!mounted) return;
      setState(() {
        _turns.add(BoboChatTurn(role: 'assistant', content: reply));
      });
    } on BoboApiException catch (error) {
      if (mounted) {
        setState(() {
          if (_turns.isNotEmpty && _turns.last.role == 'user') {
            _turns.removeLast();
          }
          _errorCode = error.code;
        });
        _inputController.text = message;
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          if (_turns.isNotEmpty && _turns.last.role == 'user') {
            _turns.removeLast();
          }
          _errorCode = 'unavailable';
        });
        _inputController.text = message;
      }
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
        _scrollToEnd();
      }
    }
  }

  Future<void> _loadConversation() async {
    if (mounted) {
      setState(() {
        _isLoadingConversation = true;
        _errorCode = null;
      });
    }
    try {
      final conversation = await widget.onOpen();
      if (!mounted) return;
      setState(() {
        _conversationId = conversation.id;
        _turns
          ..clear()
          ..addAll(conversation.messages);
        _isLoadingConversation = false;
      });
      _scrollToEnd();
    } on BoboApiException catch (error) {
      if (mounted) {
        setState(() {
          _errorCode = error.code;
          _isLoadingConversation = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _errorCode = 'unavailable';
          _isLoadingConversation = false;
        });
      }
    }
  }

  Future<void> _clearConversation() async {
    final conversationId = _conversationId;
    if (conversationId == null || _isSending || _isLoadingConversation) return;
    final shouldClear = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(uiText(context, 'Clear conversation?')),
        content: Text(
          uiText(context, 'This permanently deletes this Bobo chat.'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(uiText(context, 'Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(uiText(context, 'Delete')),
          ),
        ],
      ),
    );
    if (shouldClear != true || !mounted) return;
    setState(() {
      _isLoadingConversation = true;
      _errorCode = null;
    });
    try {
      final conversation = await widget.onClear(conversationId);
      if (!mounted) return;
      setState(() {
        _conversationId = conversation.id;
        _turns
          ..clear()
          ..addAll(conversation.messages);
        _isLoadingConversation = false;
      });
    } on BoboApiException catch (error) {
      if (mounted) {
        setState(() {
          _errorCode = error.code;
          _isLoadingConversation = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _errorCode = 'unavailable';
          _isLoadingConversation = false;
        });
      }
    }
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(
      20,
      4,
      20,
      16 + MediaQuery.viewInsetsOf(context).bottom,
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            SizedBox(
              width: 48,
              height: 48,
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.inputBackground,
                  borderRadius: BorderRadius.circular(AppRadii.button),
                  border: Border.all(color: AppColors.border),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadii.button),
                  child: SvgPicture.asset(
                    'assets/icon/cropped_how_buddy.svg',
                    width: 48,
                    height: 48,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Bobo',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: AppColors.primaryDark,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    uiText(context, 'Your biology study buddy'),
                    style: TextStyle(color: AppColors.mutedText),
                  ),
                  Text(
                    uiText(
                      context,
                      'Lesson: {title}',
                      args: {'title': widget.lessonTitle},
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: AppColors.mutedText, fontSize: 12),
                  ),
                  if (widget.exerciseIndex != null)
                    Text(
                      uiText(
                        context,
                        'Exercise {number}',
                        args: {'number': '${widget.exerciseIndex! + 1}'},
                      ),
                      style: TextStyle(
                        color: AppColors.mutedText,
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
            ),
            IconButton(
              onPressed: _clearConversation,
              tooltip: uiText(context, 'Clear conversation'),
              icon: Icon(
                Icons.delete_outline_rounded,
                color: AppColors.mutedText,
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        Divider(color: AppColors.border, height: 1),
        const SizedBox(height: 18),
        Expanded(
          child: _isLoadingConversation
              ? Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                )
              : ListView(
                  controller: _scrollController,
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        constraints: const BoxConstraints(maxWidth: 400),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.infoBackground,
                          borderRadius: BorderRadius.circular(AppRadii.input),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Text(
                          uiText(
                            context,
                            "Hi! I'm Bobo. Ask me about the biology in this lesson, and we'll work through it together.",
                          ),
                          style: TextStyle(color: AppColors.text, height: 1.4),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    for (final turn in _turns) _BoboMessageBubble(turn: turn),
                    if (!_isSending) ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _quickActions()
                            .map(
                              (entry) => ActionChip(
                                label: Text(uiText(context, entry.$1)),
                                onPressed:
                                    _isLoadingConversation ||
                                        _conversationId == null
                                    ? null
                                    : () => _send(
                                        action: entry.$2,
                                        presetMessage: entry.$1,
                                      ),
                              ),
                            )
                            .toList(),
                      ),
                    ],
                    if (_isSending)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.primary,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(uiText(context, 'Bobo is thinking…')),
                          ],
                        ),
                      ),
                    if (_errorCode != null)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _BoboMessageBubble(
                            turn: BoboChatTurn(
                              role: 'assistant',
                              content: uiText(context, _errorText(_errorCode!)),
                            ),
                            isError: true,
                          ),
                          if (_conversationId == null)
                            TextButton.icon(
                              onPressed: _loadConversation,
                              icon: const Icon(Icons.refresh_rounded),
                              label: Text(uiText(context, 'Try again')),
                            ),
                        ],
                      ),
                  ],
                ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _inputController,
                enabled:
                    !_isSending &&
                    !_isLoadingConversation &&
                    _conversationId != null,
                minLines: 1,
                maxLines: 4,
                maxLength: 1200,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _send(),
                decoration: InputDecoration(
                  hintText: uiText(
                    context,
                    'Ask Bobo for a hint or explanation',
                  ),
                  counterText: '',
                  filled: true,
                  fillColor: AppColors.inputBackground,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadii.input),
                    borderSide: BorderSide(color: AppColors.border),
                  ),
                  disabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadii.input),
                    borderSide: BorderSide(color: AppColors.border),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              onPressed: _isSending || _isLoadingConversation ? null : _send,
              tooltip: uiText(context, 'Send message'),
              icon: const Icon(Icons.send_rounded),
            ),
          ],
        ),
      ],
    ),
  );

  String _errorText(String code) => switch (code) {
    'disabled' || 'not_configured' => 'Bobo is not available right now.',
    'daily_limit' =>
      'You reached today’s Bobo message limit. Try again tomorrow.',
    'invalid_message' => 'Please use a shorter message and try again.',
    'invalid_context' => 'Reopen the lesson and try asking Bobo again.',
    'unauthorized' => 'Please sign in again to use Bobo.',
    _ => 'Bobo is having trouble connecting. Please try again in a moment.',
  };

  List<(String, String)> _quickActions() {
    if (widget.exerciseIndex == null) {
      return [
        ('Explain this', 'explain'),
        ('Give me an example', 'example'),
        ('Go deeper', 'deeper'),
        ('Quiz me', 'quiz'),
      ];
    }
    if (widget.answerSubmitted && widget.answerCorrect == false) {
      return [
        ('Why was my answer wrong?', 'whyWrong'),
        ('Help me understand', 'helpUnderstand'),
        ('Try another explanation', 'anotherExplanation'),
        ('Explain this more simply', 'simplify'),
      ];
    }
    return [
      ('Give me a hint', 'giveHint'),
      ('Ask me a guiding question', 'guidingQuestion'),
      ('Explain this more simply', 'simplify'),
      ("I'm completely lost", 'lost'),
    ];
  }
}

class _BoboMessageBubble extends StatelessWidget {
  const _BoboMessageBubble({required this.turn, this.isError = false});

  final BoboChatTurn turn;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final isUser = turn.role == 'user';
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 420),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isError
              ? AppColors.primaryLight.withValues(alpha: 0.16)
              : isUser
              ? AppColors.primaryLight.withValues(alpha: 0.25)
              : AppColors.infoBackground,
          borderRadius: BorderRadius.circular(AppRadii.input),
          border: Border.all(color: AppColors.border),
        ),
        child: Text(
          turn.content,
          style: TextStyle(color: AppColors.text, height: 1.4),
        ),
      ),
    );
  }
}
