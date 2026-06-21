import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_user.dart';
import 'auth_service.dart';

/// Supabase-backed [AuthService]. This is the ONLY file that imports the
/// Supabase SDK for auth — everything above it speaks [AppUser]/[AuthResult].
class SupabaseAuthService implements AuthService {
  final SupabaseClient _client = Supabase.instance.client;

  /// Map a Supabase [User] into our plain [AppUser]. role/name come from the
  /// user_metadata set at signup (TODO #19: read role from `profiles` instead).
  AppUser? _toAppUser(User? user) {
    if (user == null) return null;
    final meta = user.userMetadata ?? const <String, dynamic>{};
    return AppUser(
      id: user.id,
      email: user.email,
      role: (meta['role'] as String?) ?? 'searcher',
      name: meta['name'] as String?,
    );
  }

  @override
  Future<AuthResult> signUp({
    required String email,
    required String password,
    required String role,
    required String name,
    String? captchaToken,
  }) async {
    try {
      final res = await _client.auth.signUp(
        email: email,
        password: password,
        captchaToken: captchaToken,
        data: {'role': role, 'name': name}, // -> user_metadata
      );
      // Session present => confirmation is OFF, user is already in.
      // Session null => Supabase requires email confirmation first.
      if (res.session != null && res.user != null) {
        return AuthResult.signedIn(_toAppUser(res.user)!);
      }
      return AuthResult.emailConfirmationRequired();
    } on AuthException catch (e) {
      return AuthResult.error(e.message);
    } catch (_) {
      return AuthResult.error('Something went wrong. Please try again.');
    }
  }

  @override
  Future<AuthResult> signIn({
    required String email,
    required String password,
    String? captchaToken,
  }) async {
    try {
      final res = await _client.auth.signInWithPassword(
        email: email,
        password: password,
        captchaToken: captchaToken,
      );
      final user = _toAppUser(res.user);
      if (user != null) return AuthResult.signedIn(user);
      return AuthResult.error('Sign in failed. Please try again.');
    } on AuthException catch (e) {
      return AuthResult.error(e.message);
    } catch (_) {
      return AuthResult.error('Something went wrong. Please try again.');
    }
  }

  @override
  Future<void> signOut() => _client.auth.signOut();

  @override
  AppUser? get currentUser => _toAppUser(_client.auth.currentSession?.user);

  @override
  Stream<AppUser?> get authStateChanges =>
      _client.auth.onAuthStateChange.map((data) => _toAppUser(data.session?.user));

  @override
  Future<bool> sendPasswordReset(String email) async {
    try {
      await _client.auth.resetPasswordForEmail(email);
      return true;
    } on AuthException {
      return false;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> resetPassword({
    required String email,
    required String token,
    required String newPassword,
  }) async {
    try {
      await _client.auth.verifyOTP(
        email: email,
        token: token,
        type: OtpType.recovery,
      );
      await _client.auth.updateUser(UserAttributes(password: newPassword));
      return true;
    } on AuthException {
      return false;
    } catch (_) {
      return false;
    }
  }
}
