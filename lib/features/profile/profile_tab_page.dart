import 'package:flutter/material.dart';

import '../../app_style.dart';
import '../../models/app_models.dart';
import '../../services/auth_api.dart';
import '../../services/theme_preferences.dart';
import '../../services/ui_translations.dart';
import '../../shared/app_widgets.dart';
import '../auth/account_preferences_page.dart';
import 'avatar_palette.dart';
import 'notification_preferences_panel.dart';
import 'optimistic_save_controller.dart';

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
    this.preferencesController,
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
  final OptimisticSaveController<({String language, int age})>?
  preferencesController;

  @override
  State<ProfileTabPage> createState() => _ProfileTabPageState();
}

class _ProfileTabPageState extends State<ProfileTabPage> {
  final _api = AuthApi();
  late OptimisticSaveController<int> _palette;
  late OptimisticSaveController<int> _glasses;
  late OptimisticSaveController<String> _avatarEmoji;
  late String _emojiDraft;
  late OptimisticSaveController<({String language, int age})> _preferences;
  late bool _ownsPreferences;
  bool _deletingAccount = false;

  int get _paletteIndex => _palette.value;
  int get _glassesIndex => _glasses.value;
  String get _emoji => _emojiDraft;
  String get _preferredLanguage => _preferences.value.language;
  int get _ageYears => _preferences.value.age;
  bool get _savingPalette => _palette.isSaving;
  bool get _savingGlasses => _glasses.isSaving;
  bool get _savingEmoji => _avatarEmoji.isSaving;
  bool get _savingPreferences => _preferences.isSaving;

  @override
  void initState() {
    super.initState();
    _initializeControllers();
  }

  void _initializeControllers() {
    _palette = OptimisticSaveController(
      initialValue: widget.avatarPaletteIndex,
      persist: _api.saveAvatarPalette,
    );
    _glasses = OptimisticSaveController(
      initialValue: widget.glassesAccessoryIndex,
      persist: _api.saveAvatarGlasses,
    );
    _avatarEmoji = OptimisticSaveController(
      initialValue: widget.avatarEmoji,
      persist: _api.saveAvatarEmoji,
    );
    _emojiDraft = widget.avatarEmoji;
    _ownsPreferences = widget.preferencesController == null;
    _preferences =
        widget.preferencesController ??
        OptimisticSaveController(
          initialValue: (
            language:
                widget.account.preferredLanguage ??
                accountLanguageOptions.first.code,
            age: widget.account.ageYears ?? 18,
          ),
          persist: (value) async {
            await _api.saveAccountPreferences(
              preferredLanguage: value.language,
              ageYears: value.age,
            );
            return value;
          },
        );
    for (final controller in [_palette, _glasses, _preferences]) {
      controller.addListener(_onProfileChanged);
    }
    _avatarEmoji.addListener(_onEmojiChanged);
  }

  void _onEmojiChanged() {
    _emojiDraft = _avatarEmoji.value;
    _onProfileChanged();
  }

  void _onProfileChanged() {
    if (mounted) setState(() {});
  }

  @override
  void didUpdateWidget(covariant ProfileTabPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.account.id != widget.account.id ||
        oldWidget.preferencesController != widget.preferencesController) {
      _disposeControllers();
      _initializeControllers();
      return;
    }
    _palette.synchronize(widget.avatarPaletteIndex);
    _glasses.synchronize(widget.glassesAccessoryIndex);
    _avatarEmoji.synchronize(widget.avatarEmoji);
    if (oldWidget.avatarEmoji != widget.avatarEmoji) {
      _emojiDraft = widget.avatarEmoji;
    }
    _preferences.synchronize((
      language:
          widget.account.preferredLanguage ?? accountLanguageOptions.first.code,
      age: widget.account.ageYears ?? 18,
    ));
  }

  void _disposeControllers() {
    _preferences.removeListener(_onProfileChanged);
    if (_ownsPreferences) _preferences.dispose();
    for (final controller in [_palette, _glasses, _avatarEmoji]) {
      controller.dispose();
    }
  }

  @override
  void dispose() {
    _disposeControllers();
    super.dispose();
  }

  Future<void> _saveAvatar<T>(
    OptimisticSaveController<T> controller,
    T value,
    ValueChanged<T> onCommit,
    String failureMessage,
  ) async {
    try {
      await controller.save(value, onCommit: onCommit);
    } catch (_) {
      if (mounted) _showSaveError(failureMessage);
    }
  }

  Future<void> _selectPalette(int value) => _saveAvatar(
    _palette,
    value,
    widget.onAvatarPaletteChanged,
    'Could not save your avatar colors.',
  );
  Future<void> _selectGlasses(int value) => _saveAvatar(
    _glasses,
    value,
    widget.onGlassesAccessoryChanged,
    'Could not save your glasses.',
  );
  Future<void> _selectEmoji(String value) async {
    if (!_savingEmoji && value == _avatarEmoji.value) {
      setState(() => _emojiDraft = value);
      return;
    }
    await _saveAvatar(
      _avatarEmoji,
      value,
      widget.onAvatarEmojiChanged,
      'Could not save your avatar emoji.',
    );
  }

  Future<void> _savePreferences({String? language, int? age}) async {
    // Capture the Home callback, not this tab's State. The parent-owned save
    // must still publish its result/rollback after this tab is unmounted.
    final onChanged = widget.onAccountPreferencesChanged;
    void publish(({String language, int age}) value) =>
        onChanged(value.language, value.age);
    final next = (
      language: language ?? _preferredLanguage,
      age: age ?? _ageYears,
    );
    try {
      await _preferences.save(
        next,
        // Home owns global language persistence. Publish the language preview
        // once, and restore that same parent snapshot if persistence fails.
        onPreview: language == null ? null : publish,
        onRollback: language == null ? null : publish,
        onCommit: language == null ? publish : null,
      );
    } on AuthException catch (error) {
      if (mounted) _showSaveError(error.message);
    } catch (_) {
      if (mounted) _showSaveError('Could not save your preferences.');
    }
  }

  void _showSaveError(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(uiText(context, message))));
  }

  Future<void> _confirmDeleteAccount() async {
    if (_deletingAccount) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(uiText(context, 'Permanently delete your account?')),
        content: Text(
          uiText(
            context,
            'This permanently deletes your account and all linked learning progress, rewards, and Bobo chats. This cannot be undone.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(uiText(context, 'Cancel')),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red.shade700,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(uiText(context, 'Delete account')),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _deletingAccount = true);
    try {
      await AuthApi().deleteOwnAccount();
      if (mounted) widget.onLogout();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            uiText(context, 'Could not delete your account. Please try again.'),
          ),
        ),
      );
      setState(() => _deletingAccount = false);
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
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    uiText(context, 'Notifications'),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                NotificationPreferencesPanel(accountId: widget.account.id),
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
                                avatarEmoji: _emoji,
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
                          setState(() => _emojiDraft = value);
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
                OutlinedButton.icon(
                  onPressed: _deletingAccount ? null : _confirmDeleteAccount,
                  icon: const Icon(Icons.delete_forever_outlined),
                  label: Text(uiText(context, 'Delete account permanently')),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red.shade700,
                    side: BorderSide(color: Colors.red.shade700),
                    minimumSize: const Size.fromHeight(48),
                  ),
                ),
                if (_deletingAccount) ...[
                  const SizedBox(height: 8),
                  const LinearProgressIndicator(),
                ],
                const SizedBox(height: 12),
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
