export 'xp_tab_page.dart';
import 'xp_tab_page.dart';
export '../profile/profile_tab_page.dart';
import '../profile/profile_tab_page.dart';
import '../profile/optimistic_save_controller.dart';
import '../../services/latest_request.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import '../../app_style.dart';
import '../../models/app_models.dart';
import '../../services/auth_api.dart';
import '../../services/gamification_api.dart';
import '../../services/theme_preferences.dart';
import '../../services/ui_translations.dart';
import '../gamification/gamification_pages.dart';
import '../learning/lesson_tree.dart';
import '../notepad/notepad_tree_page.dart';
import '../../services/notification_service.dart';

class HomePage extends StatefulWidget {
  const HomePage({
    required this.account,
    required this.onLogout,
    this.initialIndex = 0,
    this.topicId = 'heart',
    this.savePreferences,
    this.loadGameState,
    super.key,
  });

  final Account account;
  final VoidCallback onLogout;
  final int initialIndex;
  final String topicId;
  final Future<void> Function(String language, int age)? savePreferences;
  final Future<GameState> Function(String accountId)? loadGameState;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _gameRequests = LatestRequest();
  late int _selectedIndex = widget.initialIndex;
  late String _topicId = widget.topicId;
  late final _profilePreferences = OptimisticSaveController(
    initialValue: (
      language: widget.account.preferredLanguage ?? 'en',
      age: widget.account.ageYears ?? 18,
    ),
    persist: (({String language, int age}) value) async {
      await (widget.savePreferences?.call(value.language, value.age) ??
          AuthApi().saveAccountPreferences(
            preferredLanguage: value.language,
            ageYears: value.age,
          ));
      return value;
    },
  );
  String get _preferredLanguage => _profilePreferences.value.language;
  int get _ageYears => _profilePreferences.value.age;
  int _notepadRefreshKey = 0;
  int _xpRefreshKey = 0;
  late int _avatarPaletteIndex = widget.account.avatarPaletteIndex;
  late int _glassesAccessoryIndex = widget.account.glassesAccessoryIndex;
  late String _avatarEmoji = widget.account.avatarEmoji;
  late Future<GameState> _gameStateFuture;
  GameState? _currentGameState;
  bool _topicReady = false;
  String? _queuedNotificationTopic;
  StreamSubscription<String>? _notificationSubscription;
  StreamSubscription<ForegroundNotification>?
  _foregroundNotificationSubscription;

  @override
  void initState() {
    super.initState();
    _notificationSubscription = NotificationService.instance.topicTaps.listen(
      _onNotificationTopic,
    );
    _foregroundNotificationSubscription = NotificationService
        .instance
        .foregroundNotifications
        .listen(_onForegroundNotification);
    unawaited(NotificationService.instance.syncAccount(widget.account.id));
    UiTranslations.saveLanguage(_preferredLanguage);
    final version = _gameRequests.begin();
    _gameStateFuture = _loadGameState().then((state) {
      if (mounted && _gameRequests.owns(version)) _currentGameState = state;
      return state;
    });
    _restoreLastTopic();
  }

  void _onNotificationTopic(String topicId) {
    _queuedNotificationTopic = topicId;
    if (!_topicReady || !mounted) return;
    setState(() {
      _topicId = topicId;
      _selectedIndex = 0;
    });
    AuthApi().saveLastTopicId(topicId).catchError((_) {});
  }

  void _onForegroundNotification(ForegroundNotification notification) {
    if (!mounted) return;
    final topicId = notification.topicId;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          notification.body.isEmpty
              ? notification.title
              : '${notification.title}\n${notification.body}',
        ),
        action: topicId.isEmpty
            ? null
            : SnackBarAction(
                label: uiText(context, 'Open'),
                onPressed: () => _onNotificationTopic(topicId),
              ),
      ),
    );
  }

  @override
  void dispose() {
    _profilePreferences.dispose();
    _gameRequests.invalidate();
    _notificationSubscription?.cancel();
    _foregroundNotificationSubscription?.cancel();
    super.dispose();
  }

  Future<void> _restoreLastTopic() async {
    try {
      final savedTopicId = await AuthApi().fetchLastTopicId();
      if (!mounted) return;
      if (_queuedNotificationTopic != null) {
        setState(() => _topicId = _queuedNotificationTopic!);
      } else if (savedTopicId != null && savedTopicId.isNotEmpty) {
        setState(() => _topicId = savedTopicId);
      } else {
        await AuthApi().saveLastTopicId(_topicId);
      }
    } catch (_) {
      // Keep the starting topic if the preference request is temporarily unavailable.
    } finally {
      if (mounted) {
        setState(() => _topicReady = true);
        final notificationTopic = _queuedNotificationTopic;
        if (notificationTopic != null) {
          AuthApi().saveLastTopicId(notificationTopic).catchError((_) {});
        }
      }
    }
  }

  void _setGameState(GameState state) {
    if (!mounted) return;
    _gameRequests.invalidate();
    setState(() {
      _currentGameState = state;
      _gameStateFuture = Future.value(state);
    });
  }

  Future<void> _refreshGameState() async {
    final version = _gameRequests.begin();
    try {
      final state = await _loadGameState();
      if (_gameRequests.owns(version)) _setGameState(state);
    } catch (_) {
      // Keep the last displayed game state if a refresh is temporarily unavailable.
    }
  }

  Future<GameState> _loadGameState() =>
      widget.loadGameState?.call(widget.account.id) ??
      GamificationApi().fetchState(widget.account.id);

  void _retryGameState() {
    final version = _gameRequests.begin();
    setState(() {
      _gameStateFuture = _loadGameState().then((state) {
        if (mounted && _gameRequests.owns(version)) _currentGameState = state;
        return state;
      });
    });
  }

  Future<void> _openStreak(GameState state) async {
    await _refreshGameState();
    if (!mounted) return;
    final currentState = _currentGameState ?? state;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => StreakCalendarPage(state: currentState),
      ),
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
    if (!mounted) return;
    setState(() {});
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
        preferencesController: _profilePreferences,
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
        if (state == null && snapshot.hasError) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(uiText(context, 'Could not load your progress.')),
                ),
                IconButton(
                  key: const ValueKey('retry-game-state'),
                  onPressed: _retryGameState,
                  tooltip: uiText(context, 'Retry'),
                  icon: const Icon(Icons.refresh_rounded),
                ),
              ],
            ),
          );
        }
        if (state == null) {
          return const SizedBox(
            key: ValueKey('game-state-loading'),
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
          constraints: const BoxConstraints(minHeight: 48),
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
