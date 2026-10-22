import 'package:flutter/material.dart';

typedef AdminGet = Future<Map<String, dynamic>> Function(String path);

const _ink = Color(0xFF20283A);
const _muted = Color(0xFF778091);
const _accent = Color(0xFF7056D8);
const _line = Color(0xFFE4E8EF);

class AdminUsersSection extends StatefulWidget {
  const AdminUsersSection({required this.onRequest, super.key});

  final AdminGet onRequest;

  @override
  State<AdminUsersSection> createState() => _AdminUsersSectionState();
}

class _AdminUsersSectionState extends State<AdminUsersSection> {
  final _search = TextEditingController();
  Map<String, dynamic> _overview = const {};
  List<Map<String, dynamic>> _users = const [];
  bool _loading = true;
  String? _error;
  int _total = 0;
  int _offset = 0;
  static const _pageSize = 25;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load({bool resetPage = false}) async {
    if (resetPage) _offset = 0;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final query = Uri(
        queryParameters: {
          if (_search.text.trim().isNotEmpty) 'search': _search.text.trim(),
          'limit': '$_pageSize',
          'offset': '$_offset',
        },
      ).query;
      final results = await Future.wait([
        widget.onRequest('/admin/overview'),
        widget.onRequest('/admin/users?$query'),
      ]);
      if (!mounted) return;
      _overview = results[0];
      _users = (results[1]['users'] as List<dynamic>)
          .cast<Map<String, dynamic>>();
      _total = results[1]['total'] as int? ?? 0;
    } catch (error) {
      _error = _friendlyError(error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => RefreshIndicator(
    onRefresh: _load,
    child: ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Users',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: _ink,
                ),
              ),
            ),
            IconButton(
              onPressed: _loading ? null : _load,
              tooltip: 'Refresh',
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (_error != null) _InlineError(_error!),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _MetricCard(label: 'Total users', value: _number('totalUsers')),
            _MetricCard(label: 'New · 7 days', value: _number('newUsers7d')),
            _MetricCard(label: 'New · 30 days', value: _number('newUsers30d')),
            _MetricCard(label: 'DAU · today', value: _number('dau')),
            _MetricCard(label: 'MAU · 30 days', value: _number('mau')),
            _MetricCard(
              label: 'DAU / MAU',
              value: '${_overview['dauMauPercent'] ?? 0}%',
            ),
          ],
        ),
        const SizedBox(height: 22),
        Card(
          elevation: 0,
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: const BorderSide(color: _line),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _search,
                  onSubmitted: (_) => _load(resetPage: true),
                  decoration: InputDecoration(
                    hintText: 'Search name or email',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: IconButton(
                      onPressed: () => _load(resetPage: true),
                      icon: const Icon(Icons.arrow_forward_rounded),
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 12),
                if (_loading && _users.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (_users.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(
                      child: Text(
                        'No users found.',
                        style: TextStyle(color: _muted),
                      ),
                    ),
                  )
                else
                  ..._users.map(_userRow),
                if (_total > _pageSize)
                  Row(
                    children: [
                      Text(
                        'Showing ${_offset + 1}–${(_offset + _users.length).clamp(0, _total)} of $_total',
                        style: const TextStyle(color: _muted, fontSize: 12),
                      ),
                      const Spacer(),
                      IconButton(
                        tooltip: 'Previous page',
                        onPressed: _offset == 0 || _loading
                            ? null
                            : () {
                                _offset -= _pageSize;
                                _load();
                              },
                        icon: const Icon(Icons.chevron_left_rounded),
                      ),
                      IconButton(
                        tooltip: 'Next page',
                        onPressed: _offset + _pageSize >= _total || _loading
                            ? null
                            : () {
                                _offset += _pageSize;
                                _load();
                              },
                        icon: const Icon(Icons.chevron_right_rounded),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
        const Padding(
          padding: EdgeInsets.only(top: 10),
          child: Text(
            'Demo leaderboard accounts are excluded. Activity means a sign-in or lesson activity.',
            style: TextStyle(color: _muted, fontSize: 12),
          ),
        ),
      ],
    ),
  );

  String _number(String key) => '${_overview[key] ?? 0}';

  Widget _userRow(Map<String, dynamic> user) => ListTile(
    contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
    leading: CircleAvatar(
      backgroundColor: const Color(0xFFF0EDFF),
      foregroundColor: _accent,
      child: Text(
        (user['fullName']?.toString().trim().isNotEmpty ?? false)
            ? user['fullName'].toString().trim()[0].toUpperCase()
            : '?',
      ),
    ),
    title: Text(
      user['fullName']?.toString() ?? 'Unnamed user',
      style: const TextStyle(fontWeight: FontWeight.w700, color: _ink),
    ),
    subtitle: Text(
      '${user['email'] ?? ''} · Joined ${_date(user['createdAt'])}',
      style: const TextStyle(color: _muted),
    ),
    trailing: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        const Text(
          'Last active',
          style: TextStyle(fontSize: 10, color: _muted),
        ),
        Text(
          _date(user['lastActiveAt']),
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: _ink,
          ),
        ),
      ],
    ),
  );
}

class AdminLearningAnalyticsSection extends StatefulWidget {
  const AdminLearningAnalyticsSection({required this.onRequest, super.key});

  final AdminGet onRequest;

  @override
  State<AdminLearningAnalyticsSection> createState() =>
      _AdminLearningAnalyticsSectionState();
}

class _AdminLearningAnalyticsSectionState
    extends State<AdminLearningAnalyticsSection> {
  Map<String, dynamic> _data = const {};
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      _data = await widget.onRequest('/admin/learning-analytics');
    } catch (error) {
      _error = _friendlyError(error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => RefreshIndicator(
    onRefresh: _load,
    child: ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Learning analytics',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: _ink,
                ),
              ),
            ),
            IconButton(
              onPressed: _loading ? null : _load,
              tooltip: 'Refresh',
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (_error != null) _InlineError(_error!),
        if (_loading && _data.isEmpty)
          const Padding(
            padding: EdgeInsets.all(48),
            child: Center(child: CircularProgressIndicator()),
          )
        else ...[
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _MetricCard(
                label: 'Lessons started',
                value: '${_data['lessonsStarted'] ?? 0}',
              ),
              _MetricCard(
                label: 'Lessons completed',
                value: '${_data['lessonsCompleted'] ?? 0}',
              ),
            ],
          ),
          const SizedBox(height: 22),
          _Panel(
            title: 'User retention',
            subtitle:
                'Users who completed a lesson on that calendar day after registering.',
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              children: ((_data['retention'] as List<dynamic>? ?? const [])).map((
                item,
              ) {
                final row = item as Map<String, dynamic>;
                return _MetricCard(
                  label: 'Day ${row['day']} retention',
                  value: '${row['ratePercent']}%',
                  detail:
                      '${row['retainedUsers']} of ${row['eligibleUsers']} eligible users',
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 16),
          _Panel(
            title: 'Popular topics',
            subtitle: 'Ranked by recorded lesson starts and completions.',
            child: _topicList(
              _data['popularTopics'] as List<dynamic>? ?? const [],
              popular: true,
            ),
          ),
          const SizedBox(height: 16),
          _Panel(
            title: 'Course completion rates',
            subtitle:
                'A course is complete when a user finishes all available lessons for that topic.',
            child: _topicList(
              _data['topics'] as List<dynamic>? ?? const [],
              popular: false,
            ),
          ),
          const Padding(
            padding: EdgeInsets.only(top: 10),
            child: Text(
              'Lesson starts are counted once per user and lesson from this analytics release onward. Completion history uses existing progress records.',
              style: TextStyle(color: _muted, fontSize: 12),
            ),
          ),
        ],
      ],
    ),
  );

  Widget _topicList(List<dynamic> values, {required bool popular}) {
    final topics = values.cast<Map<String, dynamic>>();
    if (topics.isEmpty)
      return const Text(
        'No lesson activity yet.',
        style: TextStyle(color: _muted),
      );
    return Column(
      children: topics.map((topic) {
        final label = topic['title']?.toString() ?? topic['id'].toString();
        final started = topic['lessonsStarted'] as int? ?? 0;
        final completed = topic['lessonsCompleted'] as int? ?? 0;
        final rate = (topic['completionRatePercent'] as num? ?? 0).toDouble();
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 9),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      label,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: _ink,
                      ),
                    ),
                  ),
                  Text(
                    popular
                        ? '$started starts · $completed done'
                        : '${rate.toStringAsFixed(1)}%',
                    style: const TextStyle(
                      color: _muted,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              if (!popular) ...[
                const SizedBox(height: 7),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: rate / 100,
                    minHeight: 7,
                    backgroundColor: const Color(0xFFF0F1F5),
                    color: _accent,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${topic['usersCompleted']} of ${topic['usersStarted']} starters completed ${topic['lessonCount']} lessons',
                  style: const TextStyle(color: _muted, fontSize: 11),
                ),
              ],
              const Divider(height: 14),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.label, required this.value, this.detail});

  final String label;
  final String value;
  final String? detail;

  @override
  Widget build(BuildContext context) => Container(
    width: 176,
    constraints: const BoxConstraints(minHeight: 106),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: _line),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(label, style: const TextStyle(color: _muted, fontSize: 12)),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            color: _ink,
            fontSize: 24,
            fontWeight: FontWeight.w800,
          ),
        ),
        if (detail != null) ...[
          const SizedBox(height: 3),
          Text(detail!, style: const TextStyle(color: _muted, fontSize: 10)),
        ],
      ],
    ),
  );
}

class _Panel extends StatelessWidget {
  const _Panel({required this.title, required this.child, this.subtitle});

  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) => Card(
    elevation: 0,
    color: Colors.white,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(18),
      side: const BorderSide(color: _line),
    ),
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: _ink,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 3),
            Text(
              subtitle!,
              style: const TextStyle(fontSize: 12, color: _muted),
            ),
          ],
          const SizedBox(height: 14),
          child,
        ],
      ),
    ),
  );
}

class _InlineError extends StatelessWidget {
  const _InlineError(this.message);
  final String message;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Text(message, style: const TextStyle(color: Color(0xFF9E3030))),
  );
}

String _friendlyError(Object error) =>
    error.toString().replaceFirst('Exception: ', '');

String _date(dynamic value) {
  final date = DateTime.tryParse(value?.toString() ?? '')?.toLocal();
  if (date == null) return 'Never';
  return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}
