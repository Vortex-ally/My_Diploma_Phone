import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';

class AuthService {
  static const String _tokenKey = 'auth_token';
  static const String _userKey = 'user_data';
  final ApiService _api = ApiService();

  ApiService get api => _api;

  Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_tokenKey);
    if (token != null && token.isNotEmpty) {
      _api.setToken(token);
      return true;
    }
    return false;
  }

  Future<Map<String, dynamic>?> getStoredUser() async {
    final prefs = await SharedPreferences.getInstance();
    final userStr = prefs.getString(_userKey);
    if (userStr != null) {
      return jsonDecode(userStr) as Map<String, dynamic>;
    }
    return null;
  }

  Future<Map<String, dynamic>> login(String email, String password) async {
    final result = await _api.login(email, password);
    final token = result['token'] as String;
    final userData = Map<String, dynamic>.from(result['user'] as Map);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
    await prefs.setString(_userKey, jsonEncode(userData));

    _api.setToken(token);
    return userData;
  }

  /// Refresh stored user data from /api/profile/.
  Future<Map<String, dynamic>?> refreshProfile() async {
    try {
      final data = await _api.getProfile();
      final user = Map<String, dynamic>.from(data['user'] as Map);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_userKey, jsonEncode(user));
      return user;
    } catch (_) {
      return null;
    }
  }

  Future<void> persistUser(Map<String, dynamic> user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userKey, jsonEncode(user));
  }

  Future<void> persistToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
    _api.setToken(token);
  }

  Future<void> logout() async {
    _api.logout();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_userKey);
  }
}
