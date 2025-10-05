import 'package:shared_preferences/shared_preferences.dart';
import '../core/api.dart';

class AuthRepo {
  final _dio = Api.I.dio;

  Future<void> login(String email, String password) async {
    final r = await _dio.post(
      '/auth/login',
      data: {'email': email, 'password': password},
    );
    if (r.statusCode == 200 && r.data?['token'] != null) {
      await _save(r.data['token']);
      return;
    }
    // 4xx here are not thrown; craft a readable message
    final msg = _extractMsg(r.data) ?? 'Invalid email or password';
    throw msg;
  }

  Future<void> signup(String email, String password) async {
    final r = await _dio.post(
      '/auth/signup',
      data: {'email': email, 'password': password},
    );
    if (r.statusCode == 200 && r.data?['token'] != null) {
      await _save(r.data['token']);
      return;
    }
    final msg = _extractMsg(r.data) ?? 'Could not create account';
    throw msg;
  }

  String? _extractMsg(dynamic data) {
    if (data is Map) {
      return (data['error'] ?? data['message'])?.toString();
    }
    return null;
  }

  Future<void> _save(String token) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString('token', token);
  }

  Future<void> logout() async {
    final sp = await SharedPreferences.getInstance();
    await sp.remove('token');
  }
}
