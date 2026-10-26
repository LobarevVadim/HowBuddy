import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;

import '../auth/google_auth_button.dart';
import '../../services/api_session.dart';
import '../../services/auth_api.dart';
import '../../models/app_models.dart';
import 'support_download.dart';
import 'admin_analytics_sections.dart';

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
  int _section = 0;
  String? _error;
  String _inbox = '';
  List<String> _inboxes = const [];
  List<Map<String, dynamic>> _conversations = [];
  Map<String, dynamic>? _active;
  final Set<String> _plainTextMessageIds = {};
  final _reply = TextEditingController();
  final List<_ReplyAttachment> _replyAttachments = [];

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
        !_conversations.any((item) => item['id'] == _active!['id'])) {
      _active = null;
    }
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
    if (current == null ||
        (_reply.text.trim().isEmpty && _replyAttachments.isEmpty)) {
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await _api(
        '/admin/conversations/${current['id']}/reply',
        method: 'POST',
        data: {
          'text': _reply.text,
          'attachments': _replyAttachments
              .map(
                (attachment) => {
                  'filename': attachment.name,
                  'contentType': attachment.contentType,
                  'content': base64Encode(attachment.bytes),
                },
              )
              .toList(),
        },
      );
      _reply.clear();
      _replyAttachments.clear();
      await _selectConversation(current);
      await _loadConversations();
    } catch (error) {
      setState(() => _error = _errorMessage(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickReplyAttachments() async {
    try {
      final files = await FilePicker.pickFiles();
      if (files.isEmpty) return;
      if (_replyAttachments.length + files.length > 10) {
        throw Exception('Attach up to 10 files per reply.');
      }
      var totalBytes = _replyAttachments.fold<int>(
        0,
        (sum, item) => sum + item.bytes.lengthInBytes,
      );
      final added = <_ReplyAttachment>[];
      for (final file in files) {
        final size = file.lengthSync() ?? await file.length() ?? 0;
        if (totalBytes + size > 25 * 1024 * 1024) {
          throw Exception('Attachments must total 25 MB or less.');
        }
        final bytes = await file.readAsBytes();
        if (totalBytes + bytes.lengthInBytes > 25 * 1024 * 1024) {
          throw Exception('Attachments must total 25 MB or less.');
        }
        totalBytes += bytes.lengthInBytes;
        added.add(
          _ReplyAttachment(
            name: file.name,
            bytes: bytes,
            contentType: _contentType(file.name),
          ),
        );
      }
      if (mounted) setState(() => _replyAttachments.addAll(added));
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error.toString().replaceFirst('Exception: ', ''),
        );
      }
    }
  }

  String _contentType(String filename) {
    final extension = filename.split('.').last.toLowerCase();
    return const {
          'pdf': 'application/pdf',
          'txt': 'text/plain',
          'csv': 'text/csv',
          'json': 'application/json',
          'png': 'image/png',
          'jpg': 'image/jpeg',
          'jpeg': 'image/jpeg',
          'gif': 'image/gif',
          'webp': 'image/webp',
          'doc': 'application/msword',
          'docx':
              'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
          'xls': 'application/vnd.ms-excel',
          'xlsx':
              'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
          'zip': 'application/zip',
        }[extension] ??
        'application/octet-stream';
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
            _sectionNavigation(),
            if (_error != null) _errorBanner(),
            if (_section == 0)
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
              )
            else if (_section == 1)
              Expanded(
                child: AdminUsersSection(onRequest: (path) => _api(path)),
              )
            else
              Expanded(
                child: AdminLearningAnalyticsSection(
                  onRequest: (path) => _api(path),
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
              'ADMIN CONSOLE',
              style: TextStyle(
                fontSize: 10,
                letterSpacing: 1.2,
                color: Color(0xFF778091),
              ),
            ),
          ],
        ),
        const Spacer(),
        if (_section == 0)
          IconButton(
            tooltip: 'Refresh inbox',
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

  Widget _sectionNavigation() => Container(
    color: Colors.white,
    padding: const EdgeInsets.fromLTRB(18, 4, 18, 10),
    child: Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _sectionButton(0, Icons.inbox_outlined, 'Inbox'),
        _sectionButton(1, Icons.people_outline_rounded, 'Users'),
        _sectionButton(2, Icons.insights_rounded, 'Learning analytics'),
      ],
    ),
  );

  Widget _sectionButton(int section, IconData icon, String label) {
    final selected = _section == section;
    return TextButton.icon(
      onPressed: () => setState(() => _section = section),
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: TextButton.styleFrom(
        foregroundColor: selected
            ? const Color(0xFF7056D8)
            : const Color(0xFF697386),
        backgroundColor: selected
            ? const Color(0xFFF2F0FF)
            : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

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
                  separatorBuilder: (_, _) => const Divider(height: 1),
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
                onChanged: (_) => setState(() {}),
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
              if (_replyAttachments.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: _replyAttachments
                      .asMap()
                      .entries
                      .map(
                        (entry) => InputChip(
                          avatar: const Icon(Icons.attach_file, size: 16),
                          label: Text(
                            '${entry.value.name} (${_size(entry.value.bytes.lengthInBytes)})',
                          ),
                          onDeleted: _loading
                              ? null
                              : () => setState(
                                  () => _replyAttachments.removeAt(entry.key),
                                ),
                        ),
                      )
                      .toList(),
                ),
              ],
              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: _loading || _replyAttachments.length >= 10
                        ? null
                        : _pickReplyAttachments,
                    icon: const Icon(Icons.attach_file_rounded),
                    label: const Text('Attach files'),
                  ),
                  const Spacer(),
                  FilledButton.icon(
                    onPressed:
                        _loading ||
                            (_reply.text.trim().isEmpty &&
                                _replyAttachments.isEmpty)
                        ? null
                        : _sendReply,
                    icon: const Icon(Icons.send_rounded),
                    label: const Text('Send reply'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _messageCard(Map<String, dynamic> message) {
    final inbound = message['direction'] == 'inbound';
    final messageId = message['id']?.toString() ?? '';
    final attachments = (message['attachments'] as List<dynamic>? ?? const [])
        .cast<Map<String, dynamic>>();
    final headers = (message['headers'] as Map<String, dynamic>?) ?? const {};
    final text = message['text']?.toString() ?? '';
    final htmlBody = message['html']?.toString() ?? '';
    final showPlainText = _plainTextMessageIds.contains(messageId);
    final cc = _emailAddresses(message['ccEmails']);
    final bcc = _emailAddresses(message['bccEmails']);
    final replyTo = _emailAddresses(message['replyToEmails']);
    final receivedFor = _emailAddresses(message['receivedFor']);
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
                        [
                          if ((message['senderName']?.toString() ?? '')
                              .isNotEmpty)
                            message['senderName'].toString(),
                          message['senderEmail']?.toString() ?? '',
                        ].where((value) => value.isNotEmpty).join(' · '),
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
                _messageDetailLine(
                  'To',
                  message['recipientEmail']?.toString() ?? '',
                ),
                if (cc.isNotEmpty) _messageDetailLine('Cc', cc),
                if (bcc.isNotEmpty) _messageDetailLine('Bcc', bcc),
                if (replyTo.isNotEmpty) _messageDetailLine('Reply-to', replyTo),
                if (receivedFor.isNotEmpty)
                  _messageDetailLine('Delivered to', receivedFor),
                if ((message['subject']?.toString() ?? '').isNotEmpty)
                  _messageDetailLine('Subject', message['subject'].toString()),
                if (inbound && message['forwardedAt'] != null) ...[
                  const SizedBox(height: 7),
                  const Text(
                    'Forwarded to vlobarev823@gmail.com',
                    style: TextStyle(fontSize: 12, color: Color(0xFF32855A)),
                  ),
                ],
                if (inbound && headers.isNotEmpty)
                  ExpansionTile(
                    tilePadding: EdgeInsets.zero,
                    childrenPadding: const EdgeInsets.only(bottom: 8),
                    dense: true,
                    title: const Text(
                      'Message headers',
                      style: TextStyle(fontSize: 13),
                    ),
                    children: headers.entries
                        .map(
                          (entry) => _messageDetailLine(
                            entry.key,
                            entry.value?.toString() ?? '',
                          ),
                        )
                        .toList(),
                  ),
                if (htmlBody.isNotEmpty && text.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: () => setState(() {
                        if (showPlainText) {
                          _plainTextMessageIds.remove(messageId);
                        } else {
                          _plainTextMessageIds.add(messageId);
                        }
                      }),
                      icon: Icon(
                        showPlainText
                            ? Icons.web_asset_rounded
                            : Icons.notes_rounded,
                        size: 16,
                      ),
                      label: Text(
                        showPlainText
                            ? 'Show formatted email'
                            : 'Show plain text',
                      ),
                    ),
                  ),
                ],
                if (htmlBody.isNotEmpty && !showPlainText)
                  Html(
                    data: htmlBody,
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
                  SelectableText(text),
                if (attachments.isNotEmpty) ...[
                  const Divider(height: 24),
                  Text(
                    'Attachments (${attachments.length})',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  ...attachments.map((item) {
                    final contentType =
                        item['contentType']?.toString() ?? 'file';
                    final isImage = contentType.toLowerCase().startsWith(
                      'image/',
                    );
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF6F7FA),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFE6E9EF)),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            isImage
                                ? Icons.image_outlined
                                : Icons.insert_drive_file_outlined,
                            color: const Color(0xFF788091),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item['filename']?.toString() ?? 'attachment',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  '$contentType · ${_size(item['size'])} · ${item['contentDisposition'] ?? 'attachment'}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFF788091),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (isImage && inbound && item['id'] != null)
                            IconButton(
                              tooltip: 'Preview image',
                              onPressed: () =>
                                  _openAttachment(item, preview: true),
                              icon: const Icon(Icons.visibility_outlined),
                            ),
                          if (inbound && item['id'] != null)
                            IconButton(
                              tooltip: 'Open or download',
                              onPressed: () => _openAttachment(item),
                              icon: const Icon(Icons.download_outlined),
                            ),
                        ],
                      ),
                    );
                  }),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _messageDetailLine(String label, String value) {
    if (value.trim().isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: SelectableText.rich(
        TextSpan(
          children: [
            TextSpan(
              text: '$label: ',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            TextSpan(text: value),
          ],
        ),
        style: const TextStyle(fontSize: 12, color: Color(0xFF687184)),
      ),
    );
  }

  String _emailAddresses(dynamic value) {
    if (value is List) {
      return value
          .map((item) => item.toString())
          .where((item) => item.isNotEmpty)
          .join(', ');
    }
    return value?.toString() ?? '';
  }

  Future<void> _openAttachment(
    Map<String, dynamic> item, {
    bool preview = false,
  }) async {
    try {
      final link = await _api('/admin/attachments/${item['id']}');
      final url = link['url'].toString();
      if (!preview) {
        openSupportAttachment(url);
        return;
      }
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(item['filename']?.toString() ?? 'Image preview'),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720, maxHeight: 560),
            child: Image.network(
              url,
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) =>
                  const Text('This image preview could not be loaded.'),
              loadingBuilder: (context, child, progress) => progress == null
                  ? child
                  : const Center(child: CircularProgressIndicator()),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    } catch (error) {
      if (mounted) setState(() => _error = _errorMessage(error));
    }
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
    if (date.year == now.year &&
        date.month == now.month &&
        date.day == now.day) {
      return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    }
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

class _ReplyAttachment {
  const _ReplyAttachment({
    required this.name,
    required this.bytes,
    required this.contentType,
  });

  final String name;
  final Uint8List bytes;
  final String contentType;
}
