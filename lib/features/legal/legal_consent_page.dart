import 'package:flutter/material.dart';

import '../../app_style.dart';
import '../../models/app_models.dart';
import '../../services/auth_api.dart';
import '../../services/theme_preferences.dart';
import 'legal_documents.dart';

typedef LegalDestinationBuilder =
    Widget Function(BuildContext context, Account account);

class LegalConsentGate extends StatefulWidget {
  const LegalConsentGate({
    required this.account,
    required this.destinationBuilder,
    required this.onSignOut,
    super.key,
  });

  final Account account;
  final LegalDestinationBuilder destinationBuilder;
  final VoidCallback onSignOut;

  @override
  State<LegalConsentGate> createState() => _LegalConsentGateState();
}

class _LegalConsentGateState extends State<LegalConsentGate> {
  bool? _accepted;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadAcceptance();
  }

  Future<void> _loadAcceptance() async {
    setState(() => _error = null);
    try {
      final accepted = await AuthApi().hasCurrentLegalAcceptance();
      if (mounted) setState(() => _accepted = accepted);
    } on AuthException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Could not check policy acceptance.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_accepted == true) {
      return widget.destinationBuilder(context, widget.account);
    }
    if (_accepted == null) {
      return Scaffold(
        body: SafeArea(
          child: Center(
            child: _error == null
                ? const CircularProgressIndicator()
                : ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 460),
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(_error!, textAlign: TextAlign.center),
                          const SizedBox(height: 16),
                          FilledButton(
                            onPressed: _loadAcceptance,
                            child: const Text('Retry'),
                          ),
                          TextButton(
                            onPressed: widget.onSignOut,
                            child: const Text('Sign out'),
                          ),
                        ],
                      ),
                    ),
                  ),
          ),
        ),
      );
    }
    return LegalConsentPage(
      onAccepted: () {
        if (mounted) setState(() => _accepted = true);
      },
      onSignOut: widget.onSignOut,
    );
  }
}

class LegalConsentPage extends StatefulWidget {
  const LegalConsentPage({
    required this.onAccepted,
    required this.onSignOut,
    super.key,
  });

  final VoidCallback onAccepted;
  final VoidCallback onSignOut;

  @override
  State<LegalConsentPage> createState() => _LegalConsentPageState();
}

class _LegalConsentPageState extends State<LegalConsentPage> {
  final _scrollController = ScrollController();
  int _documentIndex = 0;
  bool _documentReadToEnd = false;
  bool _termsAccepted = false;
  bool _noticesAcknowledged = false;
  bool _saving = false;
  String? _error;

  bool get _isConsentForm => _documentIndex >= legalDocuments.length;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_checkScrollEnd);
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkScrollEnd());
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_checkScrollEnd)
      ..dispose();
    super.dispose();
  }

  void _checkScrollEnd() {
    if (!_scrollController.hasClients || _documentReadToEnd || _isConsentForm) {
      return;
    }
    final position = _scrollController.position;
    if (position.maxScrollExtent <= 0 ||
        position.pixels >= position.maxScrollExtent - 20) {
      if (mounted) setState(() => _documentReadToEnd = true);
    }
  }

  void _goForward() {
    if (!_documentReadToEnd || _isConsentForm) return;
    setState(() {
      _documentIndex++;
      _documentReadToEnd = false;
      _error = null;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) _scrollController.jumpTo(0);
      _checkScrollEnd();
    });
  }

  void _goBack() {
    if (_saving || _documentIndex == 0) return;
    setState(() {
      _documentIndex--;
      _documentReadToEnd = true;
      _error = null;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) _scrollController.jumpTo(0);
    });
  }

  Future<void> _acceptAndContinue() async {
    if (_saving || !_termsAccepted || !_noticesAcknowledged) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await AuthApi().recordLegalAcceptance(
        termsAccepted: _termsAccepted,
        privacyAcknowledged: _noticesAcknowledged,
        cookiesAcknowledged: _noticesAcknowledged,
        refundsAcknowledged: _noticesAcknowledged,
      );
      if (mounted) widget.onAccepted();
    } on AuthException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Could not save your choices. Please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    ThemePreferencesScope.watch(context);
    final document = _isConsentForm ? null : legalDocuments[_documentIndex];
    final pageCount = legalDocuments.length + 1;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Review HowBuddy policies'),
        actions: [
          TextButton.icon(
            onPressed: _saving ? null : widget.onSignOut,
            icon: const Icon(Icons.logout_rounded),
            label: const Text('Sign out'),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 840),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Step ${_documentIndex + 1} of $pageCount',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: AppColors.primaryDark,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: (_documentIndex + 1) / pageCount,
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: Card(
                      clipBehavior: Clip.antiAlias,
                      child: _isConsentForm
                          ? _buildConsentForm(context)
                          : _buildDocument(context, document!),
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 10),
                    Semantics(
                      liveRegion: true,
                      child: Text(
                        _error!,
                        style: TextStyle(color: Colors.red.shade800),
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      if (_documentIndex > 0)
                        OutlinedButton(
                          onPressed: _saving ? null : _goBack,
                          child: const Text('Back'),
                        ),
                      const Spacer(),
                      if (!_isConsentForm)
                        FilledButton(
                          onPressed: _documentReadToEnd ? _goForward : null,
                          child: Text(
                            _documentIndex == legalDocuments.length - 1
                                ? 'Continue to consent'
                                : 'Continue to next policy',
                          ),
                        )
                      else
                        FilledButton(
                          onPressed:
                              _saving ||
                                  !_termsAccepted ||
                                  !_noticesAcknowledged
                              ? null
                              : _acceptAndContinue,
                          child: _saving
                              ? const SizedBox.square(
                                  dimension: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text('Accept and continue'),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDocument(BuildContext context, LegalDocument document) =>
      SingleChildScrollView(
        controller: _scrollController,
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              document.title,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            const Text('Effective date: October 26, 2026'),
            const SizedBox(height: 20),
            for (final section in document.sections) ...[
              Text(
                section.heading,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              for (final paragraph in section.paragraphs) ...[
                SelectableText(
                  paragraph,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 12),
              ],
              const SizedBox(height: 8),
            ],
            Semantics(
              liveRegion: true,
              label: 'End of ${document.title}',
              child: const SizedBox(height: 1),
            ),
          ],
        ),
      );

  Widget _buildConsentForm(BuildContext context) => ListView(
    padding: const EdgeInsets.all(24),
    children: [
      Text('Your choices', style: Theme.of(context).textTheme.headlineSmall),
      const SizedBox(height: 12),
      const Text(
        'These are separate acknowledgements: agreeing to the service terms is not the same as consenting to every optional use of personal information. HowBuddy currently has no optional analytics or personalized-ad tracking enabled.',
      ),
      const SizedBox(height: 18),
      CheckboxListTile(
        value: _termsAccepted,
        onChanged: _saving
            ? null
            : (value) => setState(() => _termsAccepted = value ?? false),
        controlAffinity: ListTileControlAffinity.leading,
        title: const Text('I agree to the Terms and Conditions.'),
        subtitle: const Text('Required to create and use a HowBuddy account.'),
      ),
      CheckboxListTile(
        value: _noticesAcknowledged,
        onChanged: _saving
            ? null
            : (value) => setState(() => _noticesAcknowledged = value ?? false),
        controlAffinity: ListTileControlAffinity.leading,
        title: const Text(
          'I confirm I reviewed the Privacy, Cookie, and Refund policies.',
        ),
        subtitle: const Text(
          'This records that the notices were shown; it is not an opt-in to optional tracking.',
        ),
      ),
      const SizedBox(height: 12),
      const Text(
        'You must check both boxes before continuing. Your selections and the policy versions are saved to your account.',
      ),
    ],
  );
}
