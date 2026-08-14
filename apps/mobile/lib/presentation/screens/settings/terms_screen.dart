import 'package:flutter/material.dart';

import 'legal_doc_screen.dart';

class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const LegalDocScreen(
      assetPath: 'assets/docs/TERMS_OF_SERVICE.md',
      title: 'Terms of Service',
    );
  }
}
