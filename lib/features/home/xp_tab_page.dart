import 'package:flutter/material.dart';
import '../../app_style.dart';
import '../../models/app_models.dart';
import '../../services/auth_api.dart';
import '../../services/theme_preferences.dart';
import '../../services/ui_translations.dart';
import '../profile/avatar_palette.dart';

class XpTabPage extends StatefulWidget {
  const XpTabPage({required this.accountId, this.loadSummary, super.key});

  final String accountId;
  final Future<XpWeeklySummary> Function(String)? loadSummary;

  @override
  State<XpTabPage> createState() => _XpTabPageState();
}

class _XpTabPageState extends State<XpTabPage> {
  late Future<XpWeeklySummary> _summary = _load();
  Future<XpWeeklySummary> _load() =>
      (widget.loadSummary ?? AuthApi().fetchWeeklyXp)(widget.accountId);
  @override
  void didUpdateWidget(covariant XpTabPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.accountId != widget.accountId ||
        oldWidget.loadSummary != widget.loadSummary) {
      _summary = _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    ThemePreferencesScope.watch(context);
    return FutureBuilder<XpWeeklySummary>(
      future: _summary,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.tabPagePadding),
              child: Column(mainAxisSize: MainAxisSize.min, children: [Text(
                uiText(
                  context,
                  'Could not load your XP. Please check your connection and try again.',
                ),
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(color: AppColors.mutedText),
              ), const SizedBox(height: 12), FilledButton.icon(
                onPressed: () => setState(() => _summary = _load()),
                icon: const Icon(Icons.refresh_rounded), label: Text(uiText(context, 'Try again')),
              )]),
            ),
          );
        }

        final summary = snapshot.data!;
        final maxXp = summary.days.fold<int>(
          1,
          (maximum, day) => day.xp > maximum ? day.xp : maximum,
        );
        return Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.tabPagePadding),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    uiText(context, 'Your XP'),
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: AppColors.primaryDark,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    uiText(
                      context,
                      '{count} total XP',
                      args: {'count': '${summary.totalXp}'},
                    ),
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 28),
                  Text(
                    uiText(context, 'Leaderboard'),
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.authPanelBackground,
                      borderRadius: BorderRadius.circular(AppRadii.heroImage),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      children: [
                        ...summary.leaderboard.map(
                          (entry) => _leaderboardRow(context, entry),
                        ),
                        if (summary.yourPlace case final yourPlace?) ...[
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 10),
                            child: Divider(height: 18),
                          ),
                          _leaderboardRow(context, yourPlace),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),
                  Text(
                    uiText(context, 'This week'),
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Container(
                    height: 240,
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                    decoration: BoxDecoration(
                      color: AppColors.authPanelBackground,
                      borderRadius: BorderRadius.circular(AppRadii.heroImage),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: summary.days.map((day) {
                        final fraction = day.xp / maxXp;
                        final weekday = [
                          uiText(context, 'Mon'),
                          uiText(context, 'Tue'),
                          uiText(context, 'Wed'),
                          uiText(context, 'Thu'),
                          uiText(context, 'Fri'),
                          uiText(context, 'Sat'),
                          uiText(context, 'Sun'),
                        ][day.date.weekday - 1];
                        return Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: Column(
                              children: [
                                SizedBox(
                                  height: 22,
                                  child: FittedBox(
                                    child: Text(
                                      '${day.xp}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Expanded(
                                  child: Align(
                                    alignment: Alignment.bottomCenter,
                                    child: FractionallySizedBox(
                                      heightFactor: fraction,
                                      child: Container(
                                        width: double.infinity,
                                        decoration: BoxDecoration(
                                          color: day.xp == 0
                                              ? AppColors.border
                                              : AppColors.success,
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  weekday,
                                  style: TextStyle(
                                    color: AppColors.mutedText,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    uiText(context, 'XP earned each day over the last 7 days'),
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.mutedText),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _leaderboardRow(BuildContext context, LeaderboardEntry entry) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 3),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: entry.isYou ? AppColors.primary.withValues(alpha: 0.09) : null,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 42,
            child: Text(
              '#${entry.place}',
              style: TextStyle(
                color: entry.place <= 3
                    ? AppColors.primary
                    : AppColors.mutedText,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 4),
          HowBuddyAvatar(
            paletteIndex: entry.avatarPaletteIndex,
            glassesAccessoryIndex: entry.glassesAccessoryIndex,
            avatarEmoji: entry.avatarEmoji,
            size: 32,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              entry.isYou
                  ? '${entry.name}${uiText(context, ' (you)')}'
                  : entry.name,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            '${entry.xp} XP',
            style: TextStyle(
              color: AppColors.primaryDark,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
