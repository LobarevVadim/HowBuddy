import 'dart:async';

import 'package:flutter/material.dart';

import '../../app_style.dart';
import '../../models/app_models.dart';
import '../../services/gamification_api.dart';
import '../../services/rewarded_ads.dart';
import '../../services/theme_preferences.dart';

class HeartsPage extends StatefulWidget {
  const HeartsPage({
    required this.accountId,
    required this.initialState,
    super.key,
  });

  final String accountId;
  final GameState initialState;

  @override
  State<HeartsPage> createState() => _HeartsPageState();
}

class _HeartsPageState extends State<HeartsPage> {
  late GameState _state = widget.initialState;
  bool _busy = false;
  bool _refreshingRecharge = false;
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final rechargeAt = _state.heartRechargeAt;
      if (rechargeAt != null && !rechargeAt.isAfter(DateTime.now())) {
        _refreshAfterRecharge();
      }
      setState(() {});
    });
    _refreshAfterRecharge();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  Future<void> _refreshAfterRecharge() async {
    if (_refreshingRecharge) return;
    _refreshingRecharge = true;
    try {
      final state = await GamificationApi().fetchState(widget.accountId);
      if (mounted) setState(() => _state = state);
    } catch (_) {
      // Keep the countdown visible and retry on the next tick.
    } finally {
      _refreshingRecharge = false;
    }
  }

  String _rechargeCountdown() {
    final rechargeAt = _state.heartRechargeAt;
    if (rechargeAt == null) return 'A heart will recharge in 3:00:00';
    final remaining = rechargeAt.difference(DateTime.now());
    final seconds = remaining.isNegative ? 0 : remaining.inSeconds;
    final hours = (seconds ~/ 3600).toString().padLeft(2, '0');
    final minutes = ((seconds % 3600) ~/ 60).toString().padLeft(2, '0');
    final secs = (seconds % 60).toString().padLeft(2, '0');
    return 'Next heart in $hours:$minutes:$secs';
  }

  Future<void> _watchVideo() async {
    if (_busy || _state.hearts >= 5) return;
    setState(() => _busy = true);
    try {
      final completed = await RewardedAds.show(context);
      if (!completed || !mounted) return;
      _state = await GamificationApi().watchHeartVideo(widget.accountId);
      if (mounted) setState(() {});
    } on AuthException catch (error) {
      _showError(error.message);
    } catch (_) {
      _showError('Could not restore a heart. Please try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    ThemePreferencesScope.watch(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Hearts')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.tabPagePadding),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.favorite_rounded,
                  color: Colors.redAccent,
                  size: 76,
                ),
                const SizedBox(height: 12),
                Text(
                  '${_state.hearts} of 5 hearts',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: AppColors.primaryDark,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Starting a lesson uses one heart.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.mutedText),
                ),
                const SizedBox(height: 24),
                if (_state.hearts < 5) ...[
                  Text(
                    _rechargeCountdown(),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppColors.primaryDark,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 22),
                ],
                Wrap(
                  spacing: 10,
                  children: List.generate(
                    5,
                    (index) => Icon(
                      Icons.favorite_rounded,
                      size: 36,
                      color: index < _state.hearts
                          ? Colors.redAccent
                          : AppColors.border,
                    ),
                  ),
                ),
                const SizedBox(height: 30),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _busy || _state.hearts >= 5 ? null : _watchVideo,
                    icon: _busy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.play_circle_outline_rounded),
                    label: Text(
                      _state.hearts >= 5
                          ? 'Hearts are full'
                          : 'Watch ad - +1 heart',
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  RewardedAds.isWebDemo
                      ? 'SIMULATED AD - WEB DEMO. No real advertisement is shown.'
                      : 'TEST AD - ADMOB. Test ads do not generate revenue.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.mutedText, fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class EmeraldShopPage extends StatefulWidget {
  const EmeraldShopPage({
    required this.accountId,
    required this.initialState,
    super.key,
  });

  final String accountId;
  final GameState initialState;

  @override
  State<EmeraldShopPage> createState() => _EmeraldShopPageState();
}

class _EmeraldShopPageState extends State<EmeraldShopPage> {
  late GameState _state = widget.initialState;
  bool _busy = false;
  late final Timer _countdownTimer;

  @override
  void initState() {
    super.initState();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _countdownTimer.cancel();
    super.dispose();
  }

  Future<void> _purchase(int minutes) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      _state = await GamificationApi().purchaseXpBoost(
        widget.accountId,
        durationMinutes: minutes,
      );
      if (mounted) setState(() {});
    } on AuthException catch (error) {
      _showError(error.message);
    } catch (_) {
      _showError('Could not buy the XP boost. Please try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _watchVideo() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final completed = await RewardedAds.show(context);
      if (!completed || !mounted) return;
      _state = await GamificationApi().watchEmeraldVideo(widget.accountId);
      if (mounted) setState(() {});
    } on AuthException catch (error) {
      _showError(error.message);
    } catch (_) {
      _showError('Could not add emeralds. Please try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  String _boostTimeLeft() {
    final end = _state.xpBoostUntil;
    if (end == null || !end.isAfter(DateTime.now())) return 'No active boost';
    final remaining = end.difference(DateTime.now());
    final hours = remaining.inHours;
    final minutes = remaining.inMinutes.remainder(60);
    final seconds = remaining.inSeconds.remainder(60);
    return '2x XP active - ${hours > 0 ? '${hours}h ' : ''}${minutes}m ${seconds}s left';
  }

  @override
  Widget build(BuildContext context) {
    ThemePreferencesScope.watch(context);
    const offers = [
      (minutes: 60, price: 80),
      (minutes: 30, price: 45),
      (minutes: 10, price: 20),
    ];
    return Scaffold(
      appBar: AppBar(title: const Text('Emerald shop')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.tabPagePadding),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.diamond_rounded,
                      color: Colors.green,
                      size: 34,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      '${_state.emeralds} emeralds',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: AppColors.primaryDark,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  _boostTimeLeft(),
                  style: TextStyle(
                    color: AppColors.success,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 26),
                Text(
                  'Double your lesson XP',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 12),
                for (final offer in offers) ...[
                  Card(
                    child: ListTile(
                      leading: const Icon(
                        Icons.bolt_rounded,
                        color: Colors.amber,
                      ),
                      title: Text(
                        '${offer.minutes} minute${offer.minutes == 60 ? '' : 's'} - 2x XP',
                      ),
                      trailing: FilledButton.tonal(
                        onPressed: _busy || _state.emeralds < offer.price
                            ? null
                            : () => _purchase(offer.minutes),
                        child: Text('Price: ${offer.price}'),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 18),
                FilledButton.icon(
                  onPressed: _busy ? null : _watchVideo,
                  icon: _busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.play_circle_outline_rounded),
                  label: const Text('Watch ad - +25 emeralds'),
                ),
                const SizedBox(height: 10),
                Text(
                  RewardedAds.isWebDemo
                      ? 'SIMULATED AD - WEB DEMO. No real advertisement is shown.'
                      : 'TEST AD - ADMOB. Test ads do not generate revenue.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.mutedText, fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class StreakCalendarPage extends StatefulWidget {
  const StreakCalendarPage({required this.state, super.key});

  final GameState state;

  @override
  State<StreakCalendarPage> createState() => _StreakCalendarPageState();
}

class _StreakCalendarPageState extends State<StreakCalendarPage> {
  late DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);

  @override
  Widget build(BuildContext context) {
    ThemePreferencesScope.watch(context);
    final firstWeekdayOffset = _month.weekday - 1;
    final daysInMonth = DateTime(_month.year, _month.month + 1, 0).day;
    final cells = firstWeekdayOffset + daysInMonth;
    final rowCount = (cells / 7).ceil();
    final today = DateTime.now();

    return Scaffold(
      appBar: AppBar(title: const Text('Study streak')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.tabPagePadding),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.local_fire_department_rounded,
                      color: Colors.orange,
                      size: 36,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${widget.state.streakCount} day streak',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(
                            color: AppColors.primaryDark,
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: 26),
                Row(
                  children: [
                    IconButton(
                      tooltip: 'Previous month',
                      onPressed: () => setState(() {
                        _month = DateTime(_month.year, _month.month - 1);
                      }),
                      icon: const Icon(Icons.chevron_left_rounded),
                    ),
                    Expanded(
                      child: Text(
                        '${_monthName(_month.month)} ${_month.year}',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Next month',
                      onPressed:
                          _month.year == today.year &&
                              _month.month >= today.month
                          ? null
                          : () => setState(() {
                              _month = DateTime(_month.year, _month.month + 1);
                            }),
                      icon: const Icon(Icons.chevron_right_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: ['M', 'T', 'W', 'T', 'F', 'S', 'S']
                      .map(
                        (day) => Expanded(
                          child: Center(
                            child: Text(
                              day,
                              style: TextStyle(
                                color: AppColors.mutedText,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 8),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: rowCount * 7,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 7,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                  ),
                  itemBuilder: (context, index) {
                    final day = index - firstWeekdayOffset + 1;
                    if (day < 1 || day > daysInMonth) {
                      return const SizedBox.shrink();
                    }
                    final date = DateTime(_month.year, _month.month, day);
                    final key = _dateKey(date);
                    final studied = widget.state.studyDays.contains(key);
                    final isToday = _sameDay(date, today);
                    return Container(
                      decoration: BoxDecoration(
                        color: studied
                            ? AppColors.success
                            : AppColors.authPanelBackground,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isToday ? AppColors.primary : AppColors.border,
                          width: isToday ? 2 : 1,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          '$day',
                          style: TextStyle(
                            color: studied ? Colors.white : AppColors.text,
                            fontWeight: studied || isToday
                                ? FontWeight.w900
                                : FontWeight.w600,
                          ),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 16),
                Text(
                  'Days you completed a lesson are highlighted.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.mutedText),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _monthName(int month) => const [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ][month - 1];

  String _dateKey(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  bool _sameDay(DateTime left, DateTime right) =>
      left.year == right.year &&
      left.month == right.month &&
      left.day == right.day;
}
