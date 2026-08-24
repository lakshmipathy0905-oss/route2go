import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/safety_provider.dart';
import '../../widgets/app_widgets.dart';

class TrustedContactsScreen extends ConsumerStatefulWidget {
  const TrustedContactsScreen({super.key});

  @override
  ConsumerState<TrustedContactsScreen> createState() =>
      _TrustedContactsScreenState();
}

class _TrustedContactsScreenState extends ConsumerState<TrustedContactsScreen> {
  @override
  Widget build(BuildContext context) {
    final contactsAsync = ref.watch(safetyProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Trusted Contacts'),
        actions: [
          IconButton(
            onPressed: () => _showAddContactDialog(context),
            icon: const Icon(Icons.add),
            tooltip: 'Add contact',
          ),
        ],
      ),
      body: contactsAsync.when(
        loading: () => const AppLoadingState(message: 'Loading contacts...'),
        error: (e, _) => AppErrorState(
          error: e,
          onRetry: () => ref.read(safetyProvider.notifier).load(),
        ),
        data: (contacts) {
          if (contacts.isEmpty) {
            return AppEmptyState(
              icon: Icons.people_outline,
              title: 'No trusted contacts yet',
              message:
                  'Add contacts to share your trip plans and ETA during live trips.',
              action: FilledButton.icon(
                onPressed: () => _showAddContactDialog(context),
                icon: const Icon(Icons.add),
                label: const Text('Add Contact'),
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: contacts.length,
            itemBuilder: (context, index) {
              final contact = contacts[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: CircleAvatar(
                    child: Text(contact.name[0].toUpperCase()),
                  ),
                  title: Text(contact.name),
                  subtitle: Text(contact.phone),
                  trailing: PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'delete') {
                        _confirmDelete(context, contact.id, contact.name);
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'delete',
                        child: ListTile(
                          leading: Icon(Icons.delete_outline),
                          title: Text('Remove'),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _showAddContactDialog(BuildContext context) {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    bool shareLocation = true;
    bool shareTrip = true;
    bool shareEta = true;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Add Trusted Contact'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Name *',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: phoneCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Phone *',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: emailCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Email (optional)',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 16),
                    CheckboxListTile(
                      value: shareLocation,
                      onChanged: (v) =>
                          setDialogState(() => shareLocation = v ?? true),
                      title: const Text('Share live location'),
                      contentPadding: EdgeInsets.zero,
                    ),
                    CheckboxListTile(
                      value: shareTrip,
                      onChanged: (v) =>
                          setDialogState(() => shareTrip = v ?? true),
                      title: const Text('Share trip plan'),
                      contentPadding: EdgeInsets.zero,
                    ),
                    CheckboxListTile(
                      value: shareEta,
                      onChanged: (v) =>
                          setDialogState(() => shareEta = v ?? true),
                      title: const Text('Share ETA updates'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () {
                    if (nameCtrl.text.trim().isEmpty ||
                        phoneCtrl.text.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('Name and phone are required')),
                      );
                      return;
                    }
                    ref.read(safetyProvider.notifier).addContact(
                          name: nameCtrl.text.trim(),
                          phone: phoneCtrl.text.trim(),
                          email: emailCtrl.text.trim().isEmpty
                              ? null
                              : emailCtrl.text.trim(),
                          canViewLiveLocation: shareLocation,
                          canViewTripPlan: shareTrip,
                          canViewEta: shareEta,
                        );
                    Navigator.of(dialogContext).pop();
                  },
                  child: const Text('Add'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _confirmDelete(BuildContext context, String id, String name) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Contact'),
        content: Text('Remove $name from your trusted contacts?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              ref.read(safetyProvider.notifier).deleteContact(id);
              Navigator.of(context).pop();
            },
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }
}
