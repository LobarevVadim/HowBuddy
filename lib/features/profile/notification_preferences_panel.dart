import 'package:flutter/material.dart';

import '../../app_style.dart';
import '../../services/api_session.dart';
import '../../services/notification_service.dart';
import '../../services/ui_translations.dart';

class NotificationPreferencesPanel extends StatefulWidget {
  const NotificationPreferencesPanel({
    required this.accountId,
    this.loadPreferences,
    super.key,
  });

  final String accountId;
  final Future<NotificationPreferences> Function()? loadPreferences;

  @override
  State<NotificationPreferencesPanel> createState() =>
      _NotificationPreferencesPanelState();
}

class _NotificationPreferencesPanelState
    extends State<NotificationPreferencesPanel> {
  NotificationPreferences? _preferences;
  bool _loading = true;
  bool _saving = false;
  String? _loadError;
  int _loadGeneration = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final generation = ++_loadGeneration;
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final prefs =
          await (widget.loadPreferences?.call() ?? _fetchPreferences());
      if (!mounted || generation != _loadGeneration) return;
      setState(() => _preferences = prefs);
      if (prefs.enabled) {
        await NotificationService.instance.syncAccount(widget.accountId);
      }
    } catch (_) {
      if (mounted && generation == _loadGeneration) {
        setState(() => _loadError = 'Could not load notification preferences.');
      }
    } finally {
      if (mounted && generation == _loadGeneration) {
        setState(() => _loading = false);
      }
    }
  }

  Future<NotificationPreferences> _fetchPreferences() async {
    final response = await ApiSession.getJson(
      '/account/notifications/preferences',
    );
    return NotificationPreferences.fromJson(
      response['preferences'] as Map<String, dynamic>,
    );
  }

  @override
  void didUpdateWidget(covariant NotificationPreferencesPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.accountId != widget.accountId) {
      _preferences = null;
      _load();
    }
  }

  Future<void> _update(NotificationPreferences next) async {
    final current = _preferences;
    if (current == null || _saving) return;
    setState(() => _saving = true);
    try {
      if (next.enabled && !current.enabled) {
        final registered = await NotificationService.instance.enable(
          widget.accountId,
        );
        if (!registered) {
          _message('Notifications need Firebase setup and device permission.');
          return;
        }
      }
      final response = await ApiSession.putJson(
        '/account/notifications/preferences',
        next.toJson(),
      );
      if (mounted) {
        setState(
          () => _preferences = NotificationPreferences.fromJson(
            response['preferences'] as Map<String, dynamic>,
          ),
        );
      }
    } catch (_) {
      _message('Could not save notification preferences.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _chooseTime({required bool start}) async {
    final prefs = _preferences;
    if (prefs == null || _saving) return;
    final current = start ? prefs.quietStartMinute : prefs.quietEndMinute;
    final result = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: current ~/ 60, minute: current % 60),
    );
    if (result == null) return;
    final minute = result.hour * 60 + result.minute;
    await _update(
      NotificationPreferences(
        enabled: prefs.enabled,
        curiosityEnabled: prefs.curiosityEnabled,
        quietHoursEnabled: prefs.quietHoursEnabled,
        quietStartMinute: start ? minute : prefs.quietStartMinute,
        quietEndMinute: start ? prefs.quietEndMinute : minute,
      ),
    );
  }

  Future<void> _sendTest() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final result = await ApiSession.postJson(
        '/account/notifications/test',
        const {},
      );
      if ((result['sent'] as num? ?? 0) < 1) {
        _message('Could not send the test notification.');
        return;
      }
      _message(
        result['emailSent'] == true
            ? 'Test notification and email sent.'
            : 'Test notification sent; email was not sent.',
      );
    } catch (_) {
      _message('Could not send the test notification.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _message(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(uiText(context, message))));
  }

  String _time(int minute) =>
      TimeOfDay(hour: minute ~/ 60, minute: minute % 60).format(context);

  @override
  Widget build(BuildContext context) {
    final prefs = _preferences;
    return Card(
      color: AppColors.authPanelBackground,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: _loading
            ? const Padding(
                padding: EdgeInsets.all(16),
                child: LinearProgressIndicator(),
              )
            : prefs == null || _loadError != null
            ? Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Text(
                      uiText(
                        context,
                        _loadError ??
                            'Could not load notification preferences.',
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: _load,
                      icon: const Icon(Icons.refresh_rounded),
                      label: Text(uiText(context, 'Retry')),
                    ),
                  ],
                ),
              )
            : Column(
                children: [
                  SwitchListTile.adaptive(
                    title: Text(uiText(context, 'Push reminders')),
                    subtitle: Text(
                      uiText(context, 'Daily reminders and learning nudges'),
                    ),
                    value: prefs.enabled,
                    onChanged: _saving
                        ? null
                        : (value) => _update(
                            NotificationPreferences(
                              enabled: value,
                              curiosityEnabled: prefs.curiosityEnabled,
                              quietHoursEnabled: prefs.quietHoursEnabled,
                              quietStartMinute: prefs.quietStartMinute,
                              quietEndMinute: prefs.quietEndMinute,
                            ),
                          ),
                  ),
                  SwitchListTile.adaptive(
                    title: Text(uiText(context, 'Curiosity notifications')),
                    value: prefs.curiosityEnabled,
                    onChanged: _saving || !prefs.enabled
                        ? null
                        : (value) => _update(
                            NotificationPreferences(
                              enabled: prefs.enabled,
                              curiosityEnabled: value,
                              quietHoursEnabled: prefs.quietHoursEnabled,
                              quietStartMinute: prefs.quietStartMinute,
                              quietEndMinute: prefs.quietEndMinute,
                            ),
                          ),
                  ),
                  SwitchListTile.adaptive(
                    title: Text(uiText(context, 'Quiet hours')),
                    subtitle: Text(
                      '${uiText(context, 'From')} ${_time(prefs.quietStartMinute)}  ·  ${uiText(context, 'Until')} ${_time(prefs.quietEndMinute)}',
                    ),
                    value: prefs.quietHoursEnabled,
                    onChanged: _saving || !prefs.enabled
                        ? null
                        : (value) => _update(
                            NotificationPreferences(
                              enabled: prefs.enabled,
                              curiosityEnabled: prefs.curiosityEnabled,
                              quietHoursEnabled: value,
                              quietStartMinute: prefs.quietStartMinute,
                              quietEndMinute: prefs.quietEndMinute,
                            ),
                          ),
                  ),
                  if (prefs.enabled && prefs.quietHoursEnabled)
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 12,
                      children: [
                        TextButton(
                          onPressed: _saving
                              ? null
                              : () => _chooseTime(start: true),
                          child: Text(
                            '${uiText(context, 'From')}: ${_time(prefs.quietStartMinute)}',
                          ),
                        ),
                        TextButton(
                          onPressed: _saving
                              ? null
                              : () => _chooseTime(start: false),
                          child: Text(
                            '${uiText(context, 'Until')}: ${_time(prefs.quietEndMinute)}',
                          ),
                        ),
                      ],
                    ),
                  if (prefs.enabled)
                    TextButton.icon(
                      onPressed: _saving ? null : _sendTest,
                      icon: const Icon(Icons.notifications_active_outlined),
                      label: Text(
                        uiText(context, 'Send test notification now'),
                      ),
                    ),
                  if (_saving) const LinearProgressIndicator(),
                ],
              ),
      ),
    );
  }
}
