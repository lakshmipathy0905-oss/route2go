import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Firebase Auth is the sole source of identity in Route2Go. Every privileged
/// backend call sends the Firebase ID token as a bearer token; the app never
/// talks to Supabase directly for privileged writes (see AuthRepository /
/// ApiClient for how the token gets attached to requests).
final firebaseAuthProvider = Provider<FirebaseAuth>((ref) => FirebaseAuth.instance);

/// Streams the current Firebase user; null means guest mode, which is a
/// first-class, supported state (spec Section 5.2) — not an error state.
final authStateProvider = StreamProvider<User?>((ref) {
  final auth = ref.watch(firebaseAuthProvider);
  return auth.authStateChanges();
});

/// Convenience provider for "am I logged in right now" checks in widgets
/// that shouldn't rebuild on the full stream (e.g. one-off guard checks).
final isLoggedInProvider = Provider<bool>((ref) {
  return ref.watch(authStateProvider).valueOrNull != null;
});

class AuthRepository {
  AuthRepository(this._auth);
  final FirebaseAuth _auth;

  Future<UserCredential> signInWithGoogle(AuthCredential credential) {
    return _auth.signInWithCredential(credential);
  }

  Future<UserCredential> signUpWithEmail(String email, String password) {
    return _auth.createUserWithEmailAndPassword(email: email, password: password);
  }

  Future<UserCredential> signInWithEmail(String email, String password) {
    return _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  Future<void> sendPasswordResetEmail(String email) {
    return _auth.sendPasswordResetEmail(email: email);
  }

  /// Starts phone OTP verification. `onCodeSent` receives the verificationId
  /// to be used with `confirmOtp` once the user types the code.
  Future<void> startPhoneVerification({
    required String phoneNumber,
    required void Function(String verificationId) onCodeSent,
    required void Function(FirebaseAuthException e) onError,
  }) {
    return _auth.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      timeout: const Duration(seconds: 60),
      verificationCompleted: (credential) async {
        await _auth.signInWithCredential(credential);
      },
      verificationFailed: onError,
      codeSent: (verificationId, resendToken) => onCodeSent(verificationId),
      codeAutoRetrievalTimeout: (verificationId) {},
    );
  }

  Future<UserCredential> confirmOtp({
    required String verificationId,
    required String smsCode,
  }) {
    final credential = PhoneAuthProvider.credential(
      verificationId: verificationId,
      smsCode: smsCode,
    );
    return _auth.signInWithCredential(credential);
  }

  /// Returns the current Firebase ID token for attaching to API requests as
  /// `Authorization: Bearer <token>`. Never cache this beyond the in-memory
  /// request — Firebase handles refresh; forceRefresh only when a 401 comes back.
  Future<String?> getIdToken({bool forceRefresh = false}) {
    final user = _auth.currentUser;
    if (user == null) return Future.value(null);
    return user.getIdToken(forceRefresh);
  }

  Future<void> signOut() => _auth.signOut();

  /// Account deletion (spec Section 5.2 / 22): re-authentication may be
  /// required by Firebase if the session is old; the UI should catch
  /// FirebaseAuthException(code: 'requires-recent-login') and prompt re-auth
  /// before retrying. Server-side deletion of Supabase-owned data happens
  /// via the /privacy/request-delete endpoint BEFORE this call, so backend
  /// data isn't orphaned by an identity that no longer exists.
  Future<void> deleteAccount() async {
    final user = _auth.currentUser;
    if (user == null) return;
    await user.delete();
  }
}

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(ref.watch(firebaseAuthProvider));
});
