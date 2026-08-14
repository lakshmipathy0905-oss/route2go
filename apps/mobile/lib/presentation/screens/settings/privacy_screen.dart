import 'package:flutter/material.dart';

import 'legal_doc_screen.dart';

class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const LegalDocScreen(
      assetPath: 'assets/docs/PRIVACY_POLICY.md',
      title: 'Privacy Policy',
    );
  }
}