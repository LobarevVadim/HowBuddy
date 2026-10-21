import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:http/http.dart' as http;

import '../auth/google_auth_button.dart';
import '../../services/api_session.dart';
import '../../services/auth_api.dart';
import '../../models/app_models.dart';
import 'support_download.dart';

class AdminPage extends StatefulWidget {
  const AdminPage({super.key});

  @override
  State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> {
  final _auth = AuthApi();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _search = TextEditingController();
  bool _loading = false;
  bool _authorized = false;
  String? _error;
  String _inbox = '';
  List<String> _inboxes = const [];
  List<Map<String, dynamic>> _conversations = [];
  Map<String, dynamic>? _active;
  final _reply = TextEditingController();

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _search.dispose();
    _reply.dispose();
    super.dispose();
  }

  Future<Map<String, dynamic>> _api(
    String path, {
    String method = 'GET',
    Map<String, dynamic>? data,
  }) async {
    final uri = Uri.parse('${_auth.baseUrl}$path');
    final headers = ApiSession.authenticatedHeaders;
    final response = switch (method) {
      'POST' => await http.post(
        uri,
        headers: headers,
        body: jsonEncode(data ?? {}),
      ),
      _ => await http.get(uri, headers: headers),
    };
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiSessionException(
        body['message']?.toString() ?? 'Request failed.',
      );
    }
    return body;
  }

  Future<void> _login() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await _auth.login(
        identifier: _email.text.trim(),
        password: _password.text,
      );
      await _openAdmin();
    } on AuthException catch (error) {
      ApiSession.clear();
      setState(() => _error = error.message);
    } on ApiSessionException catch (error) {
      ApiSession.clear();
      setState(() => _error = error.message);
    } catch (error) {
      ApiSession.clear();
      setState(() => _error = 'Could not reach the account server.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _google(String idToken) async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await _auth.googleSignIn(idToken: idToken, allowRegistration: false);
      await _openAdmin();
    } on AuthException catch (error) {
      ApiSession.clear();
      setState(() => _error = error.message);
    } on ApiSessionException catch (error) {
      ApiSession.clear();
      setState(() => _error = error.message);
    } catch (error) {
      ApiSession.clear();
      setState(() => _error = 'Could not reach the account server.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openAdmin() async {
    late final Map<String, dynamic> result;
    try {
      result = await _api('/admin/session');
    } catch (_) {
      ApiSession.clear();
      rethrow;
    }
    _inboxes = (result['inboxes'] as List<dynamic>).cast<String>();
    _authorized = true;
    await _loadConversations();
    if (mounted) setState(() {});
  }

  Future<void> _loadConversations() async {
    final query = <String, String>{
      if (_search.text.trim().isNotEmpty) 'search': _search.text.trim(),
      if (_inbox.isNotEmpty) 'inbox': _inbox,
    };
    final result = await _api(
      '/admin/conversations${query.isEmpty ? '' : '?${Uri(queryParameters: query).query}'}',
    );
    _conversations = (result['conversations'] as List<dynamic>)
        .cast<Map<String, dynamic>>();
    if (_active != null &&
        !_conversations.any((item) => item['id'] == _active!['id']))
      _active = null;
    if (mounted) setState(() {});
  }

  Future<void> _selectConversation(Map<String, dynamic> item) async {
    try {
      final result = await _api('/admin/conversations/${item['id']}');
      _active = result['conversation'] as Map<String, dynamic>;
      if (_active!['is_read'] != true) {
        await _api('/admin/conversations/${item['id']}/read', method: 'POST');
        item['is_read'] = true;
      }
      if (mounted) setState(() {});
    } catch (error) {
      if (mounted) setState(() => _error = _errorMessage(error));
    }
  }

  Future<void> _sendReply() async {
    final current = _active;
    if (current == null || _reply.text.trim().isEmpty) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await _api(
        '/admin/conversations/${current['id']}/reply',
        method: 'POST',
        data: {'text': _reply.text},
      );
      _reply.clear();
      await _selectConversation(current);
      await _loadConversations();
    } catch (error) {
      setState(() => _error = _errorMessage(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_authorized) return _buildLogin(context);
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      body: SafeArea(
        child: Column(
          children: [
            _header(),
            if (_error != null) _errorBanner(),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final narrow = constraints.maxWidth < 800;
                  if (narrow && _active != null) return _conversationPane();
                  return Row(
                    children: [
                      SizedBox(
                        width: narrow ? constraints.maxWidth : 350,
                        child: _listPane(),
                      ),
                      if (!narrow) const VerticalDivider(width: 1),
                      if (!narrow)
                        Expanded(
                          child: _active == null
                              ? _emptyPane()
                              : _conversationPane(),
                        ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogin(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFF4F6FA),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 430),
        child: Card(
          margin: const EdgeInsets.all(24),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: const BorderSide(color: Color(0xFFE4E8EF)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(
                  Icons.inbox_rounded,
                  size: 42,
                  color: Color(0xFF7056D8),
                ),
                const SizedBox(height: 16),
                const Text(
                  'HowBuddy Support',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 25, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Sign in with an authorized administrator account.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Color(0xFF6D7584)),
                ),
                const SizedBox(height: 26),
                TextField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _password,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Password',
                    border: OutlineInputBorder(),
                  ),
                  onSubmitted: (_) => _login(),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _loading ? null : _login,
                  child: _loading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Sign in'),
                ),
                const SizedBox(height: 10),
                GoogleAuthButton(
                  isLoading: _loading,
                  onIdToken: _google,
                  onError: (message) => setState(() => _error = message),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _error!,
                    style: const TextStyle(color: Colors.red),
                    textAlign: TextAlign.center,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    ),
  );

  Widget _header() => Container(
    height: 72,
    padding: const EdgeInsets.symmetric(horizontal: 22),
    decoration: const BoxDecoration(
      color: Colors.white,
      border: Border(bottom: BorderSide(color: Color(0xFFE4E8EF))),
    ),
    child: Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: const Color(0xFF7056D8),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.all_inbox_rounded, color: Colors.white),
        ),
        const SizedBox(width: 12),
        const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'HowBuddy',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
            ),
            Text(
              'SUPPORT DESK',
              style: TextStyle(
                fontSize: 10,
                letterSpacing: 1.2,
                color: Color(0xFF778091),
              ),
            ),
          ],
        ),
        const Spacer(),
        IconButton(
          tooltip: 'Refresh',
          onPressed: _loadConversations,
          icon: const Icon(Icons.refresh_rounded),
        ),
        IconButton(
          tooltip: 'Sign out',
          onPressed: () {
            ApiSession.clear();
            setState(() {
              _authorized = false;
              _active = null;
            });
          },
          icon: const Icon(Icons.logout_rounded),
        ),
      ],
    ),
  );

  Widget _listPane() => Container(
    color: Colors.white,
    child: Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 10),
          child: Row(
            children: [
              const Text(
                'Inbox',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              Text(
                '${_conversations.length}',
                style: const TextStyle(color: Color(0xFF788091)),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: TextField(
            controller: _search,
            onSubmitted: (_) => _loadConversations(),
            decoration: InputDecoration(
              hintText: 'Search sender, subject, message',
              prefixIcon: const Icon(Icons.search),
              isDense: true,
              filled: true,
              fillColor: const Color(0xFFF4F6FA),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
          child: DropdownButtonFormField<String>(
            initialValue: _inbox,
            isExpanded: true,
            decoration: const InputDecoration(
              isDense: true,
              border: OutlineInputBorder(),
            ),
            items: [
              const DropdownMenuItem(value: '', child: Text('All inboxes')),
              ..._inboxes.map(
                (address) =>
                    DropdownMenuItem(value: address, child: Text(address)),
              ),
            ],
            onChanged: (value) {
              _inbox = value ?? '';
              _loadConversations();
            },
          ),
        ),
        Expanded(
          child: _conversations.isEmpty
              ? const Center(child: Text('No conversations yet'))
              : ListView.separated(
                  itemCount: _conversations.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final item = _conversations[index];
                    final selected = item['id'] == _active?['id'];
                    return ListTile(
                      selected: selected,
                      selectedTileColor: const Color(0xFFF2F0FF),
                      onTap: () => _selectConversation(item),
                      title: Row(
                        children: [
                          Expanded(
                            child: Text(
                              item['sender_email']?.toString() ?? '',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontWeight: item['is_read'] == true
                                    ? FontWeight.w500
                                    : FontWeight.w800,
                              ),
                            ),
                          ),
                          if (item['is_read'] != true)
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: Color(0xFF7056D8),
                                shape: BoxShape.circle,
                              ),
                            ),
                        ],
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item['subject']?.toString() ?? '(no subject)',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          Text(
                            item['preview']?.toString() ?? '',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            '${item['inbox_address']} · ${_date(item['last_activity_at'])}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF858D9B),
                            ),
                          ),
                        ],
                      ),
                      isThreeLine: true,
                    );
                  },
                ),
        ),
      ],
    ),
  );

  Widget _conversationPane() {
    final current = _active!;
    final messages = (current['messages'] as List<dynamic>)
        .cast<Map<String, dynamic>>();
    return Column(
      children: [
        Container(
          color: Colors.white,
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              if (MediaQuery.sizeOf(context).width < 800)
                IconButton(
                  onPressed: () => setState(() => _active = null),
                  icon: const Icon(Icons.arrow_back),
                ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      current['subject']?.toString().isNotEmpty == true
                          ? current['subject'].toString()
                          : '(no subject)',
                      style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${current['sender_email']}  →  ${current['inbox_address']}',
                      style: const TextStyle(color: Color(0xFF737C8C)),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: _loadConversations,
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: messages.length,
            itemBuilder: (context, index) => _messageCard(messages[index]),
          ),
        ),
        Container(
          color: Colors.white,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Reply from ${current['inbox_address']}',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _reply,
                minLines: 3,
                maxLines: 8,
                maxLength: 50000,
                decoration: InputDecoration(
                  hintText: 'Write a reply…',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.icon(
                  onPressed: _loading ? null : _sendReply,
                  icon: const Icon(Icons.send_rounded),
                  label: const Text('Send reply'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _messageCard(Map<String, dynamic> message) {
    final inbound = message['direction'] == 'inbound';
    final attachments = (message['attachments'] as List<dynamic>? ?? const [])
        .cast<Map<String, dynamic>>();
    return Align(
      alignment: inbound ? Alignment.centerLeft : Alignment.centerRight,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 780),
        child: Card(
          color: inbound ? Colors.white : const Color(0xFFF1EEFF),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFFE6E9EF)),
          ),
          margin: const EdgeInsets.only(bottom: 14),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        message['senderEmail']?.toString() ?? '',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    Text(
                      _date(message['receivedAt']),
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF788091),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if ((message['html']?.toString() ?? '').isNotEmpty)
                  Html(
                    data: message['html'].toString(),
                    style: {
                      'body': Style(
                        margin: Margins.zero,
                        padding: HtmlPaddings.zero,
                        fontSize: FontSize(15),
                        color: const Color(0xFF293042),
                      ),
                    },
                  )
                else
                  SelectableText(message['text']?.toString() ?? ''),
                if (attachments.isNotEmpty) ...[
                  const Divider(height: 24),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: attachments
                        .map(
                          (item) => OutlinedButton.icon(
                            onPressed: () async {
                              try {
                                final link = await _api(
                                  '/admin/attachments/${item['id']}',
                                );
                                openSupportAttachment(link['url'].toString());
                              } catch (error) {
                                setState(() => _error = _errorMessage(error));
                              }
                            },
                            icon: const Icon(Icons.attach_file, size: 16),
                            label: Text(
                              '${item['filename']} · ${_size(item['size'])}',
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _emptyPane() => const Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.mark_email_read_outlined,
          size: 54,
          color: Color(0xFFB5BAC4),
        ),
        SizedBox(height: 12),
        Text(
          'Select a conversation',
          style: TextStyle(color: Color(0xFF737C8C)),
        ),
      ],
    ),
  );

  Widget _errorBanner() => Material(
    color: const Color(0xFFFFEEEE),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              _error!,
              style: const TextStyle(color: Color(0xFF9E3030)),
            ),
          ),
          IconButton(
            onPressed: () => setState(() => _error = null),
            icon: const Icon(Icons.close, size: 18),
          ),
        ],
      ),
    ),
  );

  String _date(dynamic value) {
    final date = DateTime.tryParse(value?.toString() ?? '')?.toLocal();
    if (date == null) return '';
    final now = DateTime.now();
    if (date.year == now.year && date.month == now.month && date.day == now.day)
      return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    return '${date.month}/${date.day}/${date.year}';
  }

  String _size(dynamic value) {
    final bytes = int.tryParse(value?.toString() ?? '') ?? 0;
    return bytes < 1024
        ? '$bytes B'
        : '${(bytes / 1024).toStringAsFixed(0)} KB';
  }

  String _errorMessage(Object error) {
    if (error is ApiSessionException) return error.message;
    if (error is AuthException) return error.message;
    return 'The request could not be completed.';
  }
}
