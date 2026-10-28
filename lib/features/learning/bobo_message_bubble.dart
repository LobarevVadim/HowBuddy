import 'package:flutter/material.dart';
import '../../app_style.dart';
import '../../services/bobo_api.dart';
import '../../services/ui_translations.dart';

class BoboMessageBubble extends StatelessWidget {
  const BoboMessageBubble({
    required this.turn,
    this.isError = false,
    super.key,
  });
  final BoboChatTurn turn;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isUser = turn.role == 'user';
    final reduced = MediaQuery.disableAnimationsOf(context);
    final foreground = isError
        ? scheme.onErrorContainer
        : isUser
        ? scheme.onPrimaryContainer
        : scheme.onSurface;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: reduced ? 1 : 0, end: 1),
      duration: reduced ? Duration.zero : AppMotion.arrival,
      curve: Curves.easeOutCubic,
      builder: (context, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(
          offset: Offset(0, reduced ? 0 : 6 * (1 - value)),
          child: child,
        ),
      ),
      child: Align(
        alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
        child: Semantics(
          liveRegion: !isUser,
          container: true,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 420),
            margin: EdgeInsets.only(
              bottom: 12,
              left: isUser ? 24 : 0,
              right: isUser ? 0 : 24,
            ),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isError
                  ? scheme.errorContainer
                  : isUser
                  ? scheme.primaryContainer
                  : scheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(AppRadii.input),
              border: Border.all(color: scheme.outlineVariant),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  isError
                      ? uiText(context, 'Try again')
                      : isUser
                      ? uiText(context, 'You')
                      : 'Bobo',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: foreground,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                SelectableText(
                  turn.content,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: foreground,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
