import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/router/app_router.dart';
import '../../providers/auth_provider.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

enum _Mode { landing, emailSignIn, emailSignUp }

class _LoginScreenState extends ConsumerState<LoginScreen> {
  _Mode _mode = _Mode.landing;
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _loading = false;
  String? _error;

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await action();
      if (mounted) context.go(AppRoutes.home);
    } on FirebaseAuthException catch (e) {
      setState(() => _error = _humanizeAuthError(e.code));
    } catch (_) {
      setState(() => _error = 'Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _humanizeAuthError(String code) {
    switch (code) {
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Incorrect email or password.'; // never hints which one, per spec's no-account-enumeration rule
      case 'email-already-in-use':
        return 'An account already exists with this email.';
      case 'weak-password':
        return 'Please choose a stronger password (at least 6 characters).';
      case 'invalid-verification-code':
        return "That code didn't match. Please check and try again.";
      case 'too-many-requests':
        return 'Too many attempts. Please wait a moment and try again.';
      default:
        return 'Sign-in failed. Please try again.';
    }
  }

  @override
  Widget build(BuildContext context) {
    final authRepo = ref.read(authRepositoryProvider);

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: AppSpacing.xl),
              Text('Welcome to Route2Go', style: Theme.of(context).textTheme.headlineLarge),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Sign in to save trips, vehicles and get notifications — or continue as a guest.',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: AppColors.textSecondary),
              ),
              const SizedBox(height: AppSpacing.xl),
              if (_error != null) ...[
                Text(_error!, style: const TextStyle(color: AppColors.error)),
                const SizedBox(height: AppSpacing.md),
              ],
              Expanded(child: _buildBody(authRepo)),
              TextButton(
                onPressed: _loading ? null : () => context.go(AppRoutes.home),
                child: const Text('Skip for now'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody(AuthRepository authRepo) {
    switch (_mode) {
      case _Mode.landing:
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton.icon(
              icon: const Icon(Icons.g_mobiledata),
              label: const Text('Continue with Google'),
              onPressed: _loading ? null : () => _handleGoogleSignIn(authRepo),
            ),
            const SizedBox(height: AppSpacing.md),
            OutlinedButton(
              onPressed: _loading ? null : () => setState(() => _mode = _Mode.emailSignIn),
              child: const Text('Continue with Email'),
            ),
          ],
        );
      case _Mode.emailSignIn:
      case _Mode.emailSignUp:
        final isSignUp = _mode == _Mode.emailSignUp;
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'Email'),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Password'),
            ),
            const SizedBox(height: AppSpacing.lg),
            ElevatedButton(
              onPressed: _loading
                  ? null
                  : () => _run(() async {
                        if (isSignUp) {
                          await authRepo.signUpWithEmail(
                              _emailController.text.trim(), _passwordController.text);
                        } else {
                          await authRepo.signInWithEmail(
                              _emailController.text.trim(), _passwordController.text);
                        }
                      }),
              child: Text(_loading ? 'Please wait…' : (isSignUp ? 'Sign Up' : 'Sign In')),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextButton(
              onPressed: _loading
                  ? null
                  : () => setState(() => _mode = isSignUp ? _Mode.emailSignIn : _Mode.emailSignUp),
              child: Text(isSignUp ? 'Have an account? Sign in' : "New here? Create an account"),
            ),
            if (!isSignUp)
              TextButton(
                onPressed: _loading
                    ? null
                    : () => _run(() => authRepo.sendPasswordResetEmail(_emailController.text.trim())),
                child: const Text('Forgot password?'),
              ),
          ],
        );
    }
  }

  Future<void> _handleGoogleSignIn(AuthRepository authRepo) async {
    // Requires the `google_sign_in` package + platform config (google-services.json /
    // GoogleService-Info.plist) — wired here as the integration point; see README
    // "Firebase setup" for the exact platform configuration steps.
    setState(() => _error =
        'Google Sign-In needs your Firebase project\'s OAuth client configured — see README > Firebase setup.');
  }
}
