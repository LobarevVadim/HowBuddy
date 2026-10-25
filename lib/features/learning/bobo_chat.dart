import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../app_style.dart';
import '../../services/bobo_api.dart';
import '../../services/ui_translations.dart';

Future<void> showBoboChatSheet(
  BuildContext context, {
  required Future<String> Function(String message, List<BoboChatTurn> history)
  onSend,
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
          child: _BoboChatPanel(onSend: onSend),
        ),
      ),
    ),
  );
}

class BoboLessonButton extends StatelessWidget {
  const BoboLessonButton({required this.onPressed, super.key});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: uiText(context, 'Ask Bobo'),
    child: Tooltip(
      message: uiText(context, 'Ask Bobo'),
      child: Material(
        color: AppColors.inputBackground,
        shape: const CircleBorder(),
        elevation: 7,
        shadowColor: Colors.black.withValues(alpha: 0.2),
        child: InkWell(
          onTap: onPressed,
          customBorder: const CircleBorder(),
          child: Container(
            width: 62,
            height: 62,
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.border, width: 1.5),
            ),
            child: SvgPicture.asset(
              'assets/icon/cropped_how_buddy.svg',
              fit: BoxFit.contain,
            ),
          ),
        ),
      ),
    ),
  );
}

class _BoboChatPanel extends StatefulWidget {
  const _BoboChatPanel({required this.onSend});

  final Future<String> Function(String message, List<BoboChatTurn> history)
  onSend;

  @override
  State<_BoboChatPanel> createState() => _BoboChatPanelState();
}

class _BoboChatPanelState extends State<_BoboChatPanel> {
  final _inputController = TextEditingController();
  final _scrollController = ScrollController();
  final List<BoboChatTurn> _turns = [];
  bool _isSending = false;
  String? _errorCode;

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final message = _inputController.text.trim();
    if (message.isEmpty || _isSending || message.length > 1200) return;
    final history = List<BoboChatTurn>.of(_turns);
    setState(() {
      _turns.add(BoboChatTurn(role: 'user', content: message));
      _inputController.clear();
      _isSending = true;
      _errorCode = null;
    });
    _scrollToEnd();
    try {
      final reply = await widget.onSend(message, history);
      if (!mounted) return;
      setState(() {
        _turns.add(BoboChatTurn(role: 'assistant', content: reply));
      });
    } on BoboApiException catch (error) {
      if (mounted) setState(() => _errorCode = error.code);
    } catch (_) {
      if (mounted) setState(() => _errorCode = 'unavailable');
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
        _scrollToEnd();
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
              child: SvgPicture.asset(
                'assets/icon/cropped_how_buddy.svg',
                fit: BoxFit.contain,
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
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        Divider(color: AppColors.border, height: 1),
        const SizedBox(height: 18),
        Expanded(
          child: ListView(
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
                _BoboMessageBubble(
                  turn: BoboChatTurn(
                    role: 'assistant',
                    content: uiText(context, _errorText(_errorCode!)),
                  ),
                  isError: true,
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
                enabled: !_isSending,
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
              onPressed: _isSending ? null : _send,
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
