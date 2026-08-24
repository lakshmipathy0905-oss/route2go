import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../providers/safety_provider.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/app_widgets.dart';
import '../../widgets/guest_gate.dart';

class SafetyCentreScreen extends ConsumerStatefulWidget {
  const SafetyCentreScreen({super.key});

  @override
  ConsumerState<SafetyCentreScreen> createState() => _SafetyCentreScreenState();
}

class _SafetyCentreScreenState extends ConsumerState<SafetyCentreScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(safetyProvider.notifier).load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isLoggedIn = ref.watch(isLoggedInProvider);
    final contactsAsync = ref.watch(safetyProvider);

    if (!isLoggedIn) {
      return Scaffold(
        appBar: AppBar(title: const Text('Safety Centre')),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.security_outlined, size: 48),
              const SizedBox(height: 16),
              const Text('Sign in to access Safety Centre'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => showGuestGate(context),
                child: const Text('Sign in'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Safety Centre'),
      ),
      body: contactsAsync.when(
        loading: () =>
            const AppLoadingState(message: 'Loading safety settings...'),
        error: (e, _) => AppErrorState(
          error: e,
          onRetry: () => ref.read(safetyProvider.notifier).load(),
        ),
        data: (contacts) => _buildContent(context, contacts),
      ),
    );
  }

  Widget _buildContent(BuildContext context, List contacts) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildSafetyTipCard(),
        const SizedBox(height: 16),
        _buildEmergencyCard(),
        const SizedBox(height: 16),
        _buildTrustedContactsCard(contacts),
        const SizedBox(height: 16),
        _buildSharingSettingsCard(),
      ],
    );
  }

  Widget _buildSafetyTipCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.info_outline,
                color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Drive Safely',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text(
                    'Route2Go is a planning aid. Always follow traffic laws and never interact with your device while driving.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmergencyCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Emergency', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              'In an emergency, use your device\'s emergency call feature.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                        'Use your phone\'s emergency button or dial 112 for emergency services.'),
                  ),
                );
              },
              icon: const Icon(Icons.emergency),
              label: const Text('Emergency Info'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTrustedContactsCard(List contacts) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Trusted Contacts',
                    style: Theme.of(context).textTheme.titleMedium),
                TextButton.icon(
                  onPressed: () => context.push(AppRoutes.trustedContacts),
                  icon: const Icon(Icons.add),
                  label: const Text('Add'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (contacts.isEmpty)
              Text(
                'Add trusted contacts to share your trip plans and ETA.',
                style: Theme.of(context).textTheme.bodySmall,
              )
            else
              Text(
                '${contacts.length} contact${contacts.length == 1 ? '' : 's'} added',
                style: Theme.of(context).textTheme.bodySmall,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSharingSettingsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Sharing Settings',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              'Control what information is shared with your trusted contacts during trips.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            _buildSettingTile(
              icon: Icons.location_on_outlined,
              title: 'Live Location',
              subtitle: 'Share your real-time location during trips',
              value: true,
              onChanged: (v) {},
            ),
            _buildSettingTile(
              icon: Icons.route_outlined,
              title: 'Trip Plan',
              subtitle: 'Share your planned route and stops',
              value: true,
              onChanged: (v) {},
            ),
            _buildSettingTile(
              icon: Icons.schedule_outlined,
              title: 'ETA Updates',
              subtitle: 'Notify contacts when your ETA changes',
              value: true,
              onChanged: (v) {},
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return SwitchListTile(
      value: value,
      onChanged: onChanged,
      title: Text(title),
      subtitle: Text(subtitle),
      secondary: Icon(icon),
      contentPadding: EdgeInsets.zero,
    );
  }
}
