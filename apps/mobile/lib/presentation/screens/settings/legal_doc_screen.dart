import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../../../core/theme/app_theme.dart';
import '../../widgets/app_widgets.dart';

/// Renders one of the bundled legal markdown documents (Privacy Policy /
/// Terms of Service) as an in-app screen. Both docs are drafts — they must be
/// reviewed by qualified legal counsel before Route2Go goes to the stores.
class LegalDocScreen extends StatefulWidget {
  const LegalDocScreen(
      {super.key, required this.assetPath, required this.title});

  final String assetPath;
  final String title;

  @override
  State<LegalDocScreen> createState() => _LegalDocScreenState();
}

class _LegalDocScreenState extends State<LegalDocScreen> {
  late final Future<String> _doc = rootBundle.loadString(widget.assetPath);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: SafeArea(
        child: FutureBuilder<String>(
          future: _doc,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const AppLoadingState(message: 'Loading document…');
            }
            if (snap.hasError) {
              return AppErrorState(error: snap.error!);
            }
            return ListView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: [
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppRadius.card),
                  ),
                  child: const Text(
                    'DRAFT — this document is a starting template and has not been reviewed by a lawyer. Do not rely on it as final legal text.',
                    style: TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                ..._renderMarkdown(snap.data ?? ''),
              ],
            );
          },
        ),
      ),
    );
  }

  List<Widget> _renderMarkdown(String md) {
    final widgets = <Widget>[];
    final lines = md.split('\n');
    for (final line in lines) {
      final trimmed = line.trimRight();
      if (trimmed.isEmpty) {
        widgets.add(const SizedBox(height: AppSpacing.md));
        continue;
      }
      if (trimmed.startsWith('## ')) {
        widgets.add(Padding(
          padding:
              const EdgeInsets.only(bottom: AppSpacing.sm, top: AppSpacing.lg),
          child: Text(trimmed.substring(3),
              style: Theme.of(context).textTheme.headlineSmall),
        ));
      } else if (trimmed.startsWith('# ')) {
        widgets.add(Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: Text(trimmed.substring(2),
              style: Theme.of(context).textTheme.headlineMedium),
        ));
      } else if (trimmed.startsWith('- ') || trimmed.startsWith('* ')) {
        widgets.add(Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.xs),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 6, right: AppSpacing.sm),
                child: Text('•'),
              ),
              Expanded(
                child: Text(
                  trimmed.substring(2),
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ),
            ],
          ),
        ));
      } else {
        widgets
            .add(Text(trimmed, style: Theme.of(context).textTheme.bodyLarge));
      }
    }
    return widgets;
  }
}
