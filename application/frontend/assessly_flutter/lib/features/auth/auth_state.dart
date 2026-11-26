import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/api_client.dart';

class AppUser {
  final String id;
  final String email;
  final String fullName;
  final String role;
  AppUser({required this.id, required this.email, required this.fullName, required this.role});

  factory AppUser.fromJson(Map<String, dynamic> j) => AppUser(
        id: j['id'] as String,
        email: j['email'] as String,
        fullName: j['fullName'] as String,
        role: j['role'] as String,
      );
}

/// Holds the signed-in user and the JWT. The token is kept in browser storage
/// so a page refresh does not log the person out.
class AuthState extends ChangeNotifier {
  static const _tokenKey = 'assessly_token';
  final ApiClient api;
  AppUser? user;
  bool ready = false;

  AuthState(this.api);

  bool get signedIn => user != null;

  /// Restores a saved session. An expired or invalid token is discarded.
  Future<void> restore() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_tokenKey);
    if (saved != null) {
      api.token = saved;
      try {
        final res = await api.get('/api/auth/me');
        user = AppUser.fromJson(res['user'] as Map<String, dynamic>);
      } catch (_) {
        api.token = null;
        await prefs.remove(_tokenKey);
      }
    }
    ready = true;
    notifyListeners();
  }

  Future<void> login(String email, String password) async {
    final res = await api.post('/api/auth/login', {'email': email.trim(), 'password': password});
    await _accept(res);
  }

  Future<void> register(String fullName, String email, String password, String? rollNumber) async {
    final res = await api.post('/api/auth/register', {
      'fullName': fullName.trim(),
      'email': email.trim(),
      'password': password,
      if (rollNumber != null && rollNumber.trim().isNotEmpty) 'rollNumber': rollNumber.trim(),
    });
    await _accept(res);
  }

  Future<void> _accept(Map<String, dynamic> res) async {
    api.token = res['token'] as String;
    user = AppUser.fromJson(res['user'] as Map<String, dynamic>);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, api.token!);
    notifyListeners();
  }

  Future<void> logout() async {
    api.token = null;
    user = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    notifyListeners();
  }
}
