import 'package:flutter/material.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/auth/auth_controller.dart';
import '../../../core/mock/mock_data.dart';

class AuthProvider extends ChangeNotifier {

  // State fields
  bool _isLoading = false;
  String? _errorMessage;
  String? _registrationEmail; 

  // Getters
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String? get registrationEmail => _registrationEmail;

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _setError(String? message) {
    _errorMessage = message;
    notifyListeners();
  }

  void setRegistrationEmail(String email) {
    _registrationEmail = email;
    notifyListeners();
  }

  Future<bool> login(String email, String password) async {
    _setError(null);
    _setLoading(true);

    await Future.delayed(const Duration(milliseconds: 600));

    try {
      final role = 'searcher';
      await AuthController.saveUserToken('mock_access_token');
      await AuthController.saveRefreshToken('mock_refresh_token');
      await AuthController.saveActiveRole(role);
      await AuthController.saveUserId('user_123');

      final prof = MockData.userProfile;
      prof['role'] = role;
      MockData.userProfile = prof;
      
      _setLoading(false);
      return true;
    } catch (e) {
      _setLoading(false);
      _setError(e.toString());
      return false;
    }
  }

  Future<bool> signup({
    required String firstName,
    required String lastName,
    required String email,
    required String password,
    String role = 'searcher',
  }) async {
    _setError(null);
    _setLoading(true);

    await Future.delayed(const Duration(milliseconds: 600));

    try {
      setRegistrationEmail(email.trim());
      _setLoading(false);
      return true;
    } catch (e) {
      _setLoading(false);
      _setError(e.toString());
      return false;
    }
  }

  Future<bool> verifyEmailOtp(String otp) async {
    if (_registrationEmail == null) {
      _setError('Registration context is missing. Please sign up again.');
      return false;
    }

    _setError(null);
    _setLoading(true);

    await Future.delayed(const Duration(milliseconds: 600));

    try {
      await AuthController.saveUserToken('mock_access_token');
      await AuthController.saveRefreshToken('mock_refresh_token');
      await AuthController.saveActiveRole('searcher');
      await AuthController.saveUserId('user_123');
      _setLoading(false);
      return true;
    } catch (e) {
      _setLoading(false);
      _setError(e.toString());
      return false;
    }
  }

  Future<bool> googleAuth(String idToken, {String role = 'searcher'}) async {
    _setError(null);
    _setLoading(true);

    await Future.delayed(const Duration(milliseconds: 600));

    try {
      await AuthController.saveUserToken('mock_access_token');
      await AuthController.saveRefreshToken('mock_refresh_token');
      await AuthController.saveActiveRole(role);
      await AuthController.saveUserId('user_123');

      final prof = MockData.userProfile;
      prof['role'] = role;
      MockData.userProfile = prof;
      
      _setLoading(false);
      return true;
    } catch (e) {
      _setLoading(false);
      _setError(e.toString());
      return false;
    }
  }

  Future<bool> appleAuth(String idToken, {String role = 'searcher'}) async {
    return await googleAuth(idToken, role: role);
  }

  Future<bool> forgotPassword(String email) async {
    _setError(null);
    _setLoading(true);

    await Future.delayed(const Duration(milliseconds: 600));

    _setLoading(false);
    return true;
  }

  Future<bool> resetPassword(String token, String newPassword) async {
    _setError(null);
    _setLoading(true);

    await Future.delayed(const Duration(milliseconds: 600));

    _setLoading(false);
    return true;
  }

  Future<bool> submitProviderApplication(Map<String, dynamic> data) async {
    _setError(null);
    _setLoading(true);

    await Future.delayed(const Duration(milliseconds: 600));
    _setLoading(false);
    return true;
  }

  Future<bool> logout() async {
    _setError(null);
    _setLoading(true);

    await Future.delayed(const Duration(milliseconds: 600));
    await AuthController.forceLogout();
    _setLoading(false);
    return true;
  }

  Future<String> determineNextRoute() async {
    final role = AuthController.activeRole;
    if (role == 'provider') {
      return AppRoutes.providerMainNav;
    }

    if (MockData.athletes.isNotEmpty) {
      return AppRoutes.mainNav;
    }
    
    if (MockData.providerProfile.isNotEmpty) {
      return AppRoutes.providerMainNav;
    }

    return AppRoutes.onboarding;
  }
}
