import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/auth/app_user.dart';
import '../../../core/auth/auth_service.dart';

/// The SINGLE owner of auth state (#18). Wraps [AuthService] (Supabase behind
/// it), exposes plain state to the UI, and stays in sync via the auth stream —
/// including external sign-outs. GetX is used ONLY for routing here.
class AuthProvider extends ChangeNotifier {
  final AuthService _auth;
  StreamSubscription<AppUser?>? _sub;

  AuthProvider(this._auth) {
    _currentUser = _auth.currentUser;
    _sub = _auth.authStateChanges.listen((user) {
      _currentUser = user;
      notifyListeners();
    });
  }

  AppUser? _currentUser;
  bool _isLoading = false;
  String? _errorMessage;
  String? _registrationEmail;

  AppUser? get currentUser => _currentUser;
  bool get isLoggedIn => _currentUser != null;
  String? get role => _currentUser?.role;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String? get registrationEmail => _registrationEmail;

  void _setLoading(bool v) {
    _isLoading = v;
    notifyListeners();
  }

  void _setError(String? m) {
    _errorMessage = m;
    notifyListeners();
  }

  void setRegistrationEmail(String email) {
    _registrationEmail = email.trim();
    notifyListeners();
  }

  /// Home route for a role. Role source is user_metadata for now.
  // TODO(#19): read role from the `profiles` table once real data lands.
  String routeForRole(String? role) =>
      role == 'provider' ? AppRoutes.providerMainNav : AppRoutes.mainNav;

  Future<String> determineNextRoute() async => routeForRole(role);

  // ── New API (screens use these after Stage 4) ─────────────────────────────
  Future<AuthResult> signIn(
    String email,
    String password, {
    String? captchaToken,
  }) async {
    _setError(null);
    _setLoading(true);
    final res = await _auth.signIn(
      email: email.trim(),
      password: password,
      captchaToken: captchaToken,
    );
    if (res.status == AuthStatus.error) _setError(res.message);
    _setLoading(false);
    return res;
  }

  Future<AuthResult> signUp({
    required String name,
    required String email,
    required String password,
    required String role,
    String? phone,
    String? captchaToken,
  }) async {
    _setError(null);
    _setLoading(true);
    _registrationEmail = email.trim();
    final res = await _auth.signUp(
      email: email.trim(),
      password: password,
      role: role,
      name: name,
      phone: phone,
      captchaToken: captchaToken,
    );
    if (res.status == AuthStatus.error) _setError(res.message);
    _setLoading(false);
    return res;
  }

  Future<void> signOut() async {
    await _auth.signOut();
    // The authStateChanges listener clears _currentUser and notifies.
  }

  /// Sign out + return to the auth entry screen (used by profile screens).
  Future<void> logout() async {
    await signOut();
    Get.offAllNamed(AppRoutes.authEntry);
  }

  // ── Password reset (#18 "email/pw + reset") ──────────────────────────────
  Future<bool> forgotPassword(String email) async {
    _setError(null);
    _setLoading(true);
    _registrationEmail = email.trim();
    final ok = await _auth.sendPasswordReset(email.trim());
    if (!ok) _setError('Could not send the reset email. Please try again.');
    _setLoading(false);
    return ok;
  }

  Future<bool> resetPassword(String token, String newPassword) async {
    _setError(null);
    _setLoading(true);
    final ok = await _auth.resetPassword(
      email: _registrationEmail ?? '',
      token: token,
      newPassword: newPassword,
    );
    if (!ok) _setError('Reset failed. Check the code and try again.');
    _setLoading(false);
    return ok;
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
