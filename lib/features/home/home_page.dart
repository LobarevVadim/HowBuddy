import 'package:flutter/material.dart';
import '../../app_style.dart';
import '../../models/app_models.dart';
import '../../services/auth_api.dart';
import '../../services/gamification_api.dart';
import '../../services/theme_preferences.dart';
import '../../services/ui_translations.dart';
import '../../shared/app_widgets.dart';
import '../gamification/gamification_pages.dart';
import '../learning/lesson_tree.dart';
import '../notepad/notepad_tree_page.dart';
import '../profile/avatar_palette.dart';
import '../auth/account_preferences_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({
    required this.account,
    required this.onLogout,
    this.initialIndex = 0,
    this.topicId = 'heart',
    super.key,
  });

  final Account account;
  final VoidCallback onLogout;
  final int initialIndex;
  final String topicId;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late int _selectedIndex = widget.initialIndex;
  late String _topicId = widget.topicId;
  late String _preferredLanguage = widget.account.preferredLanguage ?? 'en';
  late int _ageYears = widget.account.ageYears ?? 18;
  int _notepadRefreshKey = 0;
  int _xpRefreshKey = 0;
  late int _avatarPaletteIndex = widget.account.avatarPaletteIndex;
  late int _glassesAccessoryIndex = widget.account.glassesAccessoryIndex;
  late String _avatarEmoji = widget.account.avatarEmoji;
  late Future<GameState> _gameStateFuture;
  GameState? _currentGameState;
  bool _topicReady = false;

  @override
  void initState() {
    super.initState();
    UiTranslations.saveLanguage(_preferredLanguage);
    _gameStateFuture = GamificationApi().fetchState(widget.account.id).then((
      state,
    ) {
      _currentGameState = state;
      return state;
    });
    _restoreLastTopic();
  }

  Future<void> _restoreLastTopic() async {
    try {
      final savedTopicId = await AuthApi().fetchLastTopicId();
      if (!mounted) return;
      if (savedTopicId != null && savedTopicId.isNotEmpty) {
        setState(() => _topicId = savedTopicId);
      } else {
        await AuthApi().saveLastTopicId(_topicId);
      }
    } catch (_) {
      // Keep the starting topic if the preference request is temporarily unavailable.
    } finally {
      if (mounted) setState(() => _topicReady = true);
    }
  }

  void _setGameState(GameState state) {
    if (!mounted) return;
    setState(() {
      _currentGameState = state;
      _gameStateFuture = Future.value(state);
    });
  }

  Future<void> _refreshGameState() async {
    try {
      final state = await GamificationApi().fetchState(widget.account.id);
      _setGameState(state);
    } catch (_) {
      // Keep the last displayed game state if a refresh is temporarily unavailable.
    }
  }

  Future<void> _openStreak(GameState state) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => StreakCalendarPage(state: state)),
    );
    await _refreshGameState();
  }

  Future<void> _openHearts(GameState state) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) =>
            HeartsPage(accountId: widget.account.id, initialState: state),
      ),
    );
    await _refreshGameState();
  }

  Future<void> _openEmeraldShop(GameState state) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) =>
            EmeraldShopPage(accountId: widget.account.id, initialState: state),
      ),
    );
    await _refreshGameState();
  }

  void _selectTab(int index) {
    setState(() {
      _selectedIndex = index;
      if (index == 2) _xpRefreshKey++;
    });
  }

  void _openTopicFromNotepad(String topicId) {
    setState(() {
      _topicId = topicId;
      _selectedIndex = 0;
    });
    AuthApi().saveLastTopicId(topicId).catchError((_) {});
  }

  void _refreshNotepadProgress() {
    setState(() => _notepadRefreshKey++);
  }

  void _setAvatarPalette(int paletteIndex) {
    setState(() => _avatarPaletteIndex = paletteIndex);
  }

  void _setGlassesAccessory(int accessoryIndex) {
    setState(() => _glassesAccessoryIndex = accessoryIndex);
  }

  void _setAvatarEmoji(String emoji) {
    setState(() => _avatarEmoji = emoji);
  }

  void _setAccountPreferences(String language, int age) {
    setState(() {
      _preferredLanguage = language;
      _ageYears = age;
    });
    UiTranslations.saveLanguage(language);
  }

  Account get _accountWithPreferences => Account(
    id: widget.account.id,
    fullName: widget.account.fullName,
    email: widget.account.email,
    avatarPaletteIndex: _avatarPaletteIndex,
    glassesAccessoryIndex: _glassesAccessoryIndex,
    avatarEmoji: _avatarEmoji,
    preferredLanguage: _preferredLanguage,
    ageYears: _ageYears,
  );

  @override
  Widget build(BuildContext context) {
    ThemePreferencesScope.watch(context);
    final pages = [
      TreeLessonsPage(
        key: ValueKey('$_topicId-$_preferredLanguage'),
        accountId: widget.account.id,
        topicId: _topicId,
        onGameStateChanged: _setGameState,
        onNoHearts: () {
          final state = _currentGameState;
          if (state != null) _openHearts(state);
        },
        onTopicSelected: _openTopicFromNotepad,
        onTopicCompleted: () {
          _refreshNotepadProgress();
          _refreshGameState();
        },
      ),
      NotepadTreePage(
        key: ValueKey('$_notepadRefreshKey-$_preferredLanguage'),
        accountId: widget.account.id,
        onTopicSelected: _openTopicFromNotepad,
      ),
      XpTabPage(key: ValueKey(_xpRefreshKey), accountId: widget.account.id),
      ProfileTabPage(
        account: _accountWithPreferences,
        avatarPaletteIndex: _avatarPaletteIndex,
        glassesAccessoryIndex: _glassesAccessoryIndex,
        avatarEmoji: _avatarEmoji,
        onAvatarPaletteChanged: _setAvatarPalette,
        onGlassesAccessoryChanged: _setGlassesAccessory,
        onAvatarEmojiChanged: _setAvatarEmoji,
        onAccountPreferencesChanged: _setAccountPreferences,
        onLogout: widget.onLogout,
      ),
    ];

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _buildGameBar(),
            Expanded(
              child: _selectedIndex == 0 && !_topicReady
                  ? const Center(child: CircularProgressIndicator())
                  : pages[_selectedIndex],
            ),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: _selectTab,
        destinations: [
          NavigationDestination(
            icon: Icon(Icons.park_outlined),
            selectedIcon: Icon(Icons.park_rounded),
            label: uiText(context, 'Tree'),
          ),
          NavigationDestination(
            icon: Icon(Icons.note_alt_outlined),
            selectedIcon: Icon(Icons.note_alt_rounded),
            label: uiText(context, 'Topics'),
          ),
          NavigationDestination(
            icon: Icon(Icons.workspace_premium_outlined),
            selectedIcon: Icon(Icons.workspace_premium_rounded),
            label: uiText(context, 'XP'),
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person_rounded),
            label: uiText(context, 'Profile'),
          ),
        ],
      ),
    );
  }

  Widget _buildGameBar() {
    return FutureBuilder<GameState>(
      future: _gameStateFuture,
      builder: (context, snapshot) {
        final state = snapshot.data ?? _currentGameState;
        if (state == null) {
          return const SizedBox(
            height: 54,
            child: Center(child: LinearProgressIndicator(minHeight: 2)),
          );
        }
        return Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          child: Row(
            children: [
              Expanded(
                child: _resourceButton(
                  icon: Icons.local_fire_department_rounded,
                  color: Colors.orange,
                  label: '${state.streakCount} ${uiText(context, 'days')}',
                  onTap: () => _openStreak(state),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _resourceButton(
                  icon: Icons.diamond_rounded,
                  color: Colors.green,
                  label: '${state.emeralds}',
                  onTap: () => _openEmeraldShop(state),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _resourceButton(
                  icon: Icons.favorite_rounded,
                  color: Colors.redAccent,
                  label: '${state.hearts}/5',
                  onTap: () => _openHearts(state),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _resourceButton({
    required IconData icon,
    required Color color,
    required String label,
    required VoidCallback onTap,
  }) {
    return Material(
      color: AppColors.authPanelBackground,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 19),
              const SizedBox(width: 5),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    label,
                    style: const TextStyle(fontWeight: FontWeight.w800),
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

class XpTabPage extends StatelessWidget {
  const XpTabPage({required this.accountId, super.key});

  final String accountId;

  @override
  Widget build(BuildContext context) {
    ThemePreferencesScope.watch(context);
    return FutureBuilder<XpWeeklySummary>(
      future: AuthApi().fetchWeeklyXp(accountId),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.tabPagePadding),
              child: Text(
                uiText(
                  context,
                  'Could not load your XP. Please check your connection and try again.',
                ),
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(color: AppColors.mutedText),
              ),
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
        color: entry.isYou ? AppColors.primary.withOpacity(0.09) : null,
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

class ProfileTabPage extends StatefulWidget {
  const ProfileTabPage({
    required this.account,
    required this.avatarPaletteIndex,
    required this.glassesAccessoryIndex,
    required this.avatarEmoji,
    required this.onAvatarPaletteChanged,
    required this.onGlassesAccessoryChanged,
    required this.onAvatarEmojiChanged,
    required this.onAccountPreferencesChanged,
    required this.onLogout,
    super.key,
  });

  final Account account;
  final int avatarPaletteIndex;
  final int glassesAccessoryIndex;
  final String avatarEmoji;
  final ValueChanged<int> onAvatarPaletteChanged;
  final ValueChanged<int> onGlassesAccessoryChanged;
  final ValueChanged<String> onAvatarEmojiChanged;
  final void Function(String language, int age) onAccountPreferencesChanged;
  final VoidCallback onLogout;

  @override
  State<ProfileTabPage> createState() => _ProfileTabPageState();
}

class _ProfileTabPageState extends State<ProfileTabPage> {
  late int _paletteIndex = widget.avatarPaletteIndex;
  late int _glassesIndex = widget.glassesAccessoryIndex;
  late String _emoji = widget.avatarEmoji;
  late String _preferredLanguage =
      widget.account.preferredLanguage ?? accountLanguageOptions.first.code;
  late int _ageYears = widget.account.ageYears ?? 18;
  bool _savingPalette = false;
  bool _savingGlasses = false;
  bool _savingEmoji = false;
  bool _savingPreferences = false;

  Future<void> _selectPalette(int paletteIndex) async {
    if (_savingPalette || paletteIndex == _paletteIndex) return;
    final previousIndex = _paletteIndex;
    setState(() {
      _paletteIndex = paletteIndex;
      _savingPalette = true;
    });
    try {
      final savedIndex = await AuthApi().saveAvatarPalette(paletteIndex);
      if (mounted) {
        setState(() => _paletteIndex = savedIndex);
        widget.onAvatarPaletteChanged(savedIndex);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _paletteIndex = previousIndex);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(uiText(context, 'Could not save your avatar colors.')),
        ),
      );
    } finally {
      if (mounted) setState(() => _savingPalette = false);
    }
  }

  Future<void> _selectGlasses(int accessoryIndex) async {
    if (_savingGlasses || accessoryIndex == _glassesIndex) return;
    final previousIndex = _glassesIndex;
    setState(() {
      _glassesIndex = accessoryIndex;
      _savingGlasses = true;
    });
    try {
      final savedIndex = await AuthApi().saveAvatarGlasses(accessoryIndex);
      if (mounted) {
        setState(() => _glassesIndex = savedIndex);
        widget.onGlassesAccessoryChanged(savedIndex);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _glassesIndex = previousIndex);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(uiText(context, 'Could not save your glasses.')),
        ),
      );
    } finally {
      if (mounted) setState(() => _savingGlasses = false);
    }
  }

  Future<void> _selectEmoji(String emoji) async {
    if (_savingEmoji || emoji == _emoji) return;
    final previousEmoji = _emoji;
    setState(() {
      _emoji = emoji;
      _savingEmoji = true;
    });
    try {
      final savedEmoji = await AuthApi().saveAvatarEmoji(emoji);
      if (mounted) {
        setState(() => _emoji = savedEmoji);
        widget.onAvatarEmojiChanged(savedEmoji);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _emoji = previousEmoji);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(uiText(context, 'Could not save your avatar emoji.')),
        ),
      );
    } finally {
      if (mounted) setState(() => _savingEmoji = false);
    }
  }

  Future<void> _savePreferences({String? language, int? age}) async {
    if (_savingPreferences) return;
    final previousLanguage = _preferredLanguage;
    final previousAge = _ageYears;
    final nextLanguage = language ?? _preferredLanguage;
    final nextAge = age ?? _ageYears;
    if (language != null) {
      UiTranslations.saveLanguage(nextLanguage);
      widget.onAccountPreferencesChanged(nextLanguage, nextAge);
    }
    setState(() {
      _preferredLanguage = nextLanguage;
      _ageYears = nextAge;
      _savingPreferences = true;
    });
    try {
      await AuthApi().saveAccountPreferences(
        preferredLanguage: nextLanguage,
        ageYears: nextAge,
      );
      if (mounted) {
        widget.onAccountPreferencesChanged(nextLanguage, nextAge);
      }
    } on AuthException catch (error) {
      if (!mounted) return;
      setState(() {
        _preferredLanguage = previousLanguage;
        _ageYears = previousAge;
      });
      if (language != null) {
        UiTranslations.saveLanguage(previousLanguage);
        widget.onAccountPreferencesChanged(previousLanguage, previousAge);
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(uiText(context, error.message))));
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _preferredLanguage = previousLanguage;
        _ageYears = previousAge;
      });
      if (language != null) {
        UiTranslations.saveLanguage(previousLanguage);
        widget.onAccountPreferencesChanged(previousLanguage, previousAge);
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(uiText(context, 'Could not save your preferences.')),
        ),
      );
    } finally {
      if (mounted) setState(() => _savingPreferences = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final themePreferences = ThemePreferencesScope.of(context);
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.tabPagePadding),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                HowBuddyAvatar(
                  paletteIndex: _paletteIndex,
                  glassesAccessoryIndex: _glassesIndex,
                  avatarEmoji: _emoji,
                  size: AppSizes.tabHeroIcon,
                ),
                const SizedBox(height: AppSpacing.tabIconGap),
                Text(
                  uiText(
                    context,
                    'Hi, {name}',
                    args: {'name': widget.account.fullName},
                  ),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: AppSpacing.tabTextGap),
                Text(
                  widget.account.email,
                  textAlign: TextAlign.center,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyLarge?.copyWith(color: AppColors.mutedText),
                ),
                const SizedBox(height: 18),
                DropdownButtonFormField<String>(
                  initialValue: _preferredLanguage,
                  decoration: InputDecoration(
                    labelText: uiText(context, 'Language preference'),
                  ),
                  items: [
                    for (final language in accountLanguageOptions)
                      DropdownMenuItem(
                        value: language.code,
                        child: Text(UiTranslations.languageName(language.code)),
                      ),
                  ],
                  onChanged: _savingPreferences
                      ? null
                      : (value) {
                          if (value != null) _savePreferences(language: value);
                        },
                ),
                const SizedBox(height: AppSpacing.fieldGap),
                DropdownButtonFormField<int>(
                  initialValue: _ageYears,
                  decoration: InputDecoration(
                    labelText: uiText(context, 'Age'),
                  ),
                  items: [
                    for (var age = 1; age <= 120; age++)
                      DropdownMenuItem(value: age, child: Text('$age')),
                  ],
                  onChanged: _savingPreferences
                      ? null
                      : (value) {
                          if (value != null) _savePreferences(age: value);
                        },
                ),
                if (_savingPreferences) ...[
                  const SizedBox(height: 8),
                  const LinearProgressIndicator(),
                ],
                const SizedBox(height: 20),
                SwitchListTile.adaptive(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  secondary: Icon(
                    themePreferences.isDarkMode
                        ? Icons.dark_mode_rounded
                        : Icons.light_mode_rounded,
                    color: AppColors.primary,
                  ),
                  title: Text(
                    uiText(context, 'Dark mode'),
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(
                    uiText(context, themePreferences.isDarkMode ? 'On' : 'Off'),
                    style: TextStyle(color: AppColors.mutedText),
                  ),
                  value: themePreferences.isDarkMode,
                  onChanged: themePreferences.setDarkMode,
                ),
                const SizedBox(height: 20),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    uiText(context, 'Customize your buddy'),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  uiText(
                    context,
                    'Choose a color palette. Your eyes, mouth, and background stay the same.',
                  ),
                  style: TextStyle(color: AppColors.mutedText),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: avatarPalettes.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    childAspectRatio: 0.92,
                  ),
                  itemBuilder: (context, index) {
                    final selected = index == _paletteIndex;
                    return Semantics(
                      button: true,
                      selected: selected,
                      label: uiText(
                        context,
                        '{name} avatar colors',
                        args: {
                          'name': uiText(
                            context,
                            index == 0 ? 'Original' : 'Palette {number}',
                            args: {'number': '${index + 1}'},
                          ),
                        },
                      ),
                      child: InkWell(
                        onTap: _savingPalette
                            ? null
                            : () => _selectPalette(index),
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          decoration: BoxDecoration(
                            color: selected
                                ? AppColors.primary.withValues(alpha: 0.10)
                                : AppColors.authPanelBackground,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: selected
                                  ? AppColors.primary
                                  : AppColors.border,
                              width: selected ? 2 : 1,
                            ),
                          ),
                          padding: const EdgeInsets.all(6),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              HowBuddyAvatar(
                                paletteIndex: index,
                                glassesAccessoryIndex: _glassesIndex,
                                avatarEmoji: _emoji,
                                size: 48,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                uiText(
                                  context,
                                  index == 0 ? 'Original' : 'Palette {number}',
                                  args: {'number': '${index + 1}'},
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: selected
                                      ? FontWeight.w800
                                      : FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
                if (_savingPalette) ...[
                  const SizedBox(height: 8),
                  const LinearProgressIndicator(),
                ],
                const SizedBox(height: 20),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    uiText(context, 'Glasses accessory'),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  uiText(context, 'Choose glasses to layer over your buddy.'),
                  style: TextStyle(color: AppColors.mutedText),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: 17,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    childAspectRatio: 0.95,
                  ),
                  itemBuilder: (context, index) {
                    final selected = index == _glassesIndex;
                    return Semantics(
                      button: true,
                      selected: selected,
                      label: uiText(
                        context,
                        index == 0 ? 'No glasses' : 'Glasses {number}',
                        args: {'number': '$index'},
                      ),
                      child: InkWell(
                        onTap: _savingGlasses
                            ? null
                            : () => _selectGlasses(index),
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          decoration: BoxDecoration(
                            color: selected
                                ? AppColors.primary.withValues(alpha: 0.10)
                                : AppColors.authPanelBackground,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: selected
                                  ? AppColors.primary
                                  : AppColors.border,
                              width: selected ? 2 : 1,
                            ),
                          ),
                          padding: const EdgeInsets.all(5),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              HowBuddyAvatar(
                                paletteIndex: _paletteIndex,
                                glassesAccessoryIndex: index,
                                size: 56,
                              ),
                              const SizedBox(height: 3),
                              Text(
                                index == 0
                                    ? uiText(context, 'None')
                                    : uiText(
                                        context,
                                        'Glasses {number}',
                                        args: {'number': '$index'},
                                      ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: selected
                                      ? FontWeight.w800
                                      : FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
                if (_savingGlasses) ...[
                  const SizedBox(height: 8),
                  const LinearProgressIndicator(),
                ],
                const SizedBox(height: 20),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    uiText(context, 'Avatar emoji'),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  uiText(
                    context,
                    'Choose an emoji or type one. It can overlap the avatar border.',
                  ),
                  style: TextStyle(color: AppColors.mutedText),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8,
                  runSpacing: 8,
                  children:
                      [
                            '\u{1F600}',
                            '\u{1F970}',
                            '\u{1F602}',
                            '\u{1F60D}',
                            '\u{1F60E}',
                            '\u{1F973}',
                            '\u{1F98B}',
                            '\u{1F338}',
                            '\u{2B50}',
                            '\u{1F4A7}',
                            '\u{1F340}',
                            '\u{1F389}',
                            '\u{1F525}',
                            '\u{1F308}',
                            '\u{1F438}',
                            '\u{1F431}',
                          ]
                          .map(
                            (emoji) => ChoiceChip(
                              label: Text(
                                emoji,
                                style: const TextStyle(fontSize: 20),
                              ),
                              selected: _emoji == emoji,
                              onSelected: _savingEmoji
                                  ? null
                                  : (_) => _selectEmoji(emoji),
                            ),
                          )
                          .toList(),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        key: ValueKey(_emoji),
                        initialValue: _emoji,
                        maxLength: 8,
                        decoration: InputDecoration(
                          labelText: uiText(context, 'Type an emoji'),
                          counterText: '',
                          prefixIcon: const Icon(Icons.emoji_emotions_outlined),
                        ),
                        onChanged: (value) {
                          setState(() => _emoji = value);
                        },
                        onFieldSubmitted: _selectEmoji,
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filledTonal(
                      onPressed: _savingEmoji
                          ? null
                          : () => _selectEmoji(_emoji),
                      icon: const Icon(Icons.check_rounded),
                      tooltip: uiText(context, 'Save emoji'),
                    ),
                    IconButton(
                      onPressed: _savingEmoji ? null : () => _selectEmoji(''),
                      icon: const Icon(Icons.close_rounded),
                      tooltip: uiText(context, 'Remove emoji'),
                    ),
                  ],
                ),
                if (_savingEmoji) ...[
                  const SizedBox(height: 8),
                  const LinearProgressIndicator(),
                ],
                const SizedBox(height: AppSpacing.profileLogoutGap),
                PrimaryButton(
                  text: uiText(context, 'Logout'),
                  onPressed: widget.onLogout,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
