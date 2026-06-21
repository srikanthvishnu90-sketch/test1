import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

class AuthController {
  static final GetStorage _box = GetStorage();

  static String? get accessToken => _box.read<String>('accessToken');
  static String? get refreshToken => _box.read<String>('refreshToken');
  static String? get activeRole => _box.read<String>('activeRole');
  static String? get userId => _box.read<String>('userId');

  static Future<void> saveUserToken(String token) async {
    await _box.write('accessToken', token);
  }

  static Future<void> saveRefreshToken(String token) async {
    await _box.write('refreshToken', token);
  }

  static Future<void> saveActiveRole(String role) async {
    await _box.write('activeRole', role);
  }

  static Future<void> saveUserId(String id) async {
    await _box.write('userId', id);
  }

  static Future<void> forceLogout() async {
    await _box.remove('accessToken');
    await _box.remove('refreshToken');
    await _box.remove('activeRole');
    await _box.remove('userId');
    Get.offAllNamed('/auth-entry');
  }
}
