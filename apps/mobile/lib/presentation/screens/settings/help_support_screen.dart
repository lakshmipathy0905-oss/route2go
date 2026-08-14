import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../../data/repositories/support_repository.dart';
import '../../widgets/guest_gate.dart';

class HelpSupportScreen extends ConsumerStatefulWidget {
  const HelpSupportScreen({super.key});

  @override
  ConsumerState<HelpSupportScreen> createState() => _HelpSupportScreenState();
}

class _HelpSupportScreenState extends ConsumerState<HelpSupportScreen> {
  final _subjectCtrl = TextEditingController();
  final _messageCtrl = TextEditingController();
  bool _sent = false;
  String? _error;
  List<Map<String, dynamic>>? _faqs;
  bool _faqsLoading = true;

  @override
  void initState() {
    super.initState();
    _loadFaqs();
  }

  Future<void> _loadFaqs() async {
    try {
      final faqs = await ref.read(supportRepositoryProvider).faqs();
      if (mounted) setState(() => _faqs = faqs);
    } catch (_) {
      // FAQs are non-critical; leave the list empty.
    } finally {
      if (mounted) setState(() => _faqsLoading = false);
    }
  }

  @override
  void dispose() {
    _subjectCtrl.dispose();
    _messageCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Help & Support')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            Text('Frequently asked', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: AppSpacing.md),
            if (_faqsLoading)
              const Text('Loading FAQs…', style: TextStyle(color: AppColors.textSecondary))
            else if (_faqs == null || _faqs!.isEmpty)
              const Text('No FAQs yet — contact us below.',
                  style: TextStyle(color: AppColors.textSecondary))
            else
              for (final f in _faqs!) ...[
                Card(
                  child: ExpansionTile(
                    title: Text(f['question'] as String? ?? ''),
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        child: Text(f['answer'] as String? ?? '',
                            style: Theme.of(context).textTheme.bodyLarge),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
              ],
            const SizedBox(height: AppSpacing.xl),
            Text("Can't find an answer?", style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _subjectCtrl,
              decoration: const InputDecoration(labelText: 'Subject'),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _messageCtrl,
              maxLines: 4,
              decoration: const InputDecoration(labelText: 'Message', alignLabelWithHint: true),
            ),
            if (_error != null) ...[
              const SizedBox(height: AppSpacing.md),
              Text(_error!, style: const TextStyle(color: AppColors.error)),
            ],
            if (_sent) ...[
              const SizedBox(height: AppSpacing.md),
              const Text('Thanks — your message has been sent.',
                  style: TextStyle(color: AppColors.success)),
            ],
            const SizedBox(height: AppSpacing.md),
            ElevatedButton(onPressed: _submit, child: const Text('Send message')),
            const SizedBox(height: AppSpacing.md),
            OutlinedButton.icon(
              onPressed: () => launchUrl(Uri(scheme: 'mailto', path: 'support@route2go.example')),
              icon: const Icon(Icons.mail_outline, size: 18),
              label: const Text('Email support@route2go.example'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    final isLoggedIn = ref.read(isLoggedInProvider);
    if (!isLoggedIn) {
      showGuestGate(context);
      return;
    }
    final subject = _subjectCtrl.text.trim();
    final message = _messageCtrl.text.trim();
    if (subject.isEmpty || message.isEmpty) {
      setState(() => _error = 'Please add both a subject and a message.');
      return;
    }
    setState(() {
      _error = null;
      _sent = false;
    });
    try {
      await ref.read(supportRepositoryProvider).openTicket(subject: subject, message: message);
      if (mounted) {
        setState(() => _sent = true);
        _subjectCtrl.clear();
        _messageCtrl.clear();
      }
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not send your message. Please try again.');
    }
  }
}