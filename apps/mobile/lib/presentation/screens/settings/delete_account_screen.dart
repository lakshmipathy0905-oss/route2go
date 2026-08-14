import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/live_trip_provider.dart';
import '../../providers/profile_provider.dart';
import '../../../data/repositories/privacy_repository.dart';

/// Delete Account flow (spec 2.12 / 3.1).
///
/// Order matters — Supabase-owned rows are deleted via the Edge Function
/// FIRST, then the Firebase identity is deleted, so no orphaned data is left
/// behind. Firebase may require a recent sign-in for `user.delete()`;
/// we re-authenticate in-place with the email/password credential.
class DeleteAccountScreen extends ConsumerStatefulWidget {
  const DeleteAccountScreen({super.key});

  @override
  ConsumerState<DeleteAccountScreen> createState() =>
      _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends ConsumerState<DeleteAccountScreen> {
  bool _working = false;
  String? _error;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Delete Account')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            const Icon(Icons.warning_amber_rounded,
                size: 48, color: AppColors.error),
            const SizedBox(height: AppSpacing.md),
            Text(
              'This permanently deletes your Route2Go data and sign-in.',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.lg),
            const _DeleteBullet('Saved trips, routes and itineraries'),
            const _DeleteBullet('Vehicles in your garage'),
            const _DeleteBullet('Expenses and split records'),
            const _DeleteBullet('Notifications and FCM tokens'),
            const _DeleteBullet('Profile, preferences and analytics consent'),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Booking details on partner sites (where you paid a stay provider) are not controlled by Route2Go and will remain on the partner’s records.',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: AppColors.textSecondary),
            ),
            if (_error != null) ...[
              const SizedBox(height: AppSpacing.md),
              Text(_error!, style: const TextStyle(color: AppColors.error)),
            ],
            const SizedBox(height: AppSpacing.xl),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppColors.error),
              onPressed: _working ? null : _confirmAndDelete,
              child: Text(_working ? 'Deleting…' : 'Delete my account'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmAndDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete your account?'),
        content: const Text(
            'This cannot be undone. All your Route2Go data will be permanently removed.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() {
      _working = true;
      _error = null;
    });

    try {
      // 1. Server-side: delete all Supabase-owned rows for this user.
      await ref.read(privacyRepositoryProvider).requestDelete(reason: '');

      // 2. Re-authenticate if Firebase requires a recent login, then delete
      //    the Firebase identity. Doing this after step 1 keeps the DB clean
      //    even if the identity deletion fails.
      await _reauthenticateIfNeeded();

      // 3. Sign out locally and clear cached state.
      await ref.read(authRepositoryProvider).signOut();
      ref.read(liveTripProvider.notifier).end();
      ref.read(profileProvider.notifier).clear();

      if (!mounted) return;
      Navigator.of(context).popUntil((r) => r.isFirst);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Your account has been deleted.')),
      );
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        setState(() {
          _working = false;
          _error = _friendlyAuthError(e);
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _working = false;
          _error = 'Something went wrong. Please try again.';
        });
      }
    }
  }

  Future<void> _reauthenticateIfNeeded() async {
    final user = ref.read(firebaseAuthProvider).currentUser;
    if (user == null || user.email == null) return;

    try {
      await user.delete();
    } on FirebaseAuthException catch (e) {
      if (e.code != 'requires-recent-login') rethrow;
      // Prompt for the password to obtain a fresh credential.
      final password = await _askForPassword();
      if (password == null || password.isEmpty || !mounted) {
        throw const FormatException('password cancelled');
      }
      final credential =
          EmailAuthProvider.credential(email: user.email!, password: password);
      await user.reauthenticateWithCredential(credential);
      await user.delete();
    }
  }

  Future<String?> _askForPassword() {
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Re-enter your password'),
        content: TextField(
          controller: ctrl,
          obscureText: true,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Password'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(context, ctrl.text),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
  }

  String _friendlyAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'wrong-password':
        return 'Wrong password. Please try again.';
      case 'too-many-requests':
        return 'Too many attempts. Wait a minute and try again.';
      case 'requires-recent-login':
        return 'Please sign in again, then retry account deletion.';
      default:
        return 'Could not delete your account. Please try again.';
    }
  }
}

class _DeleteBullet extends StatelessWidget {
  const _DeleteBullet(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check_circle_outline,
              size: 20, color: AppColors.textSecondary),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
              child: Text(text, style: Theme.of(context).textTheme.bodyLarge)),
        ],
      ),
    );
  }
}
