import 'package:flutter/material.dart';

import '../../app_style.dart';
import '../../models/app_models.dart';
import '../../services/gamification_api.dart';
import '../../services/ui_translations.dart';

class StreakGoalPage extends StatefulWidget {
  const StreakGoalPage({
    super.key,
    required this.account,
    required this.isNewAccount,
    required this.destinationBuilder,
  });

  final Account account;
  final bool isNewAccount;
  final Widget Function(BuildContext, Account) destinationBuilder;

  @override
  State<StreakGoalPage> createState() => _StreakGoalPageState();
}

class _StreakGoalPageState extends State<StreakGoalPage> {
  static const _goals = [(7, 1), (14, 3), (30, 7)];
  int? _selectedGoal;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    if (widget.isNewAccount) {
      _loading = false;
    } else {
      _checkExistingStreak();
    }
  }

  Future<void> _checkExistingStreak() async {
    setState(() {
      _loading = true;
    });
    try {
      final state = await GamificationApi().fetchState(widget.account.id);
      if (!mounted) return;
      if (state.streakCount > 0) {
        _continueToApp();
        return;
      }
      setState(() => _loading = false);
    } catch (_) {
      // If the streak cannot be checked, do not block sign-in or guess that
      // the user qualifies for the goal prompt.
      if (mounted) _continueToApp();
    }
  }

  void _continueToApp() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) =>
            widget.destinationBuilder(context, widget.account),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        backgroundColor: AppColors.pageBackground,
        body: Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.pageBackground,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.pageHorizontal),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    uiText(context, 'Choose your streak goal'),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.text,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    uiText(
                      context,
                      'Build a learning streak with a goal that feels right for you.',
                    ),
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.mutedText, fontSize: 16),
                  ),
                  const SizedBox(height: 28),
                  for (final (days, freezes) in _goals) ...[
                    _GoalOption(
                      days: days,
                      freezes: freezes,
                      selected: _selectedGoal == days,
                      onTap: () => setState(() => _selectedGoal = days),
                    ),
                    const SizedBox(height: 12),
                  ],
                  const SizedBox(height: 12),
                  SizedBox(
                    height: AppSizes.primaryButtonHeight,
                    child: FilledButton(
                      onPressed: _selectedGoal == null ? null : _continueToApp,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadii.button),
                        ),
                      ),
                      child: Text(uiText(context, 'Start my goal')),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GoalOption extends StatelessWidget {
  const _GoalOption({
    required this.days,
    required this.freezes,
    required this.selected,
    required this.onTap,
  });

  final int days;
  final int freezes;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final borderColor = selected ? AppColors.primary : AppColors.border;
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: AppColors.inputBackground,
        borderRadius: BorderRadius.circular(AppRadii.input),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadii.input),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 17),
            decoration: BoxDecoration(
              border: Border.all(color: borderColor, width: selected ? 2 : 1),
              borderRadius: BorderRadius.circular(AppRadii.input),
            ),
            child: Row(
              children: [
                Text('🔥', style: const TextStyle(fontSize: 23)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    uiText(context, '{count} days', args: {'count': '$days'}),
                    style: TextStyle(
                      color: AppColors.text,
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Text('❄️', style: const TextStyle(fontSize: 20)),
                const SizedBox(width: 7),
                Text(
                  freezes == 1
                      ? uiText(context, '1 streak freeze')
                      : uiText(
                          context,
                          '{count} streak freezes',
                          args: {'count': '$freezes'},
                        ),
                  style: TextStyle(color: AppColors.text, fontSize: 14),
                ),
                const SizedBox(width: 8),
                Icon(
                  selected
                      ? Icons.radio_button_checked
                      : Icons.radio_button_off,
                  color: selected ? AppColors.primary : AppColors.mutedText,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
