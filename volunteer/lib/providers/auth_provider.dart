import 'package:flutter/foundation.dart';
import '../models/user.dart';
import '../services/auth_service.dart';

class AuthProvider with ChangeNotifier {
  final AuthService _authService = AuthService();

  User? _user;
  ProfileStats? _stats;
  bool _isLoading = true;
  String? _error;

  User? get user => _user;
  ProfileStats? get stats => _stats;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _user != null;
  String? get error => _error;
  String? get role => _user?.role;
  bool get isVolunteer => _user?.role == 'volunteer';

  AuthProvider() {
    initAuth();
  }

  Future<void> initAuth() async {
    _isLoading = true;
    notifyListeners();

    try {
      final loggedIn = await _authService.isLoggedIn();
      if (loggedIn) {
        final stored = await _authService.getStoredUser();
        if (stored != null) {
          _user = User.fromJson(stored);
        }
        // Refresh profile in background; ignore failures.
        unawaited(refreshProfile());
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> login(String email, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final userData = await _authService.login(email, password);
      _user = User.fromJson(userData);
      // Pull richer profile data after login.
      await refreshProfile();
      return true;
    } catch (e) {
      _error = e.toString().replaceAll('Exception: ', '');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refreshProfile() async {
    try {
      final data = await _authService.api.getProfile();
      final user = User.fromJson(
        Map<String, dynamic>.from(data['user'] as Map),
      );
      _user = user;
      await _authService.persistUser(user.toJson());
      final statsJson = data['stats'];
      if (statsJson is Map) {
        _stats = ProfileStats.fromJson(Map<String, dynamic>.from(statsJson));
      }
      notifyListeners();
    } catch (e) {
      if (e.toString().contains('Не авторизовано')) {
        _user = null;
        _stats = null;
        notifyListeners();
      }
    }
  }

  Future<bool> updateProfile({
    required String firstName,
    required String lastName,
    String? groupName,
  }) async {
    try {
      await _authService.api.updateProfile(
        firstName: firstName,
        lastName: lastName,
        groupName: groupName,
      );
      _user = _user?.copyWith(
        firstName: firstName,
        lastName: lastName,
        groupName: groupName ?? '',
      );
      if (_user != null) {
        await _authService.persistUser(_user!.toJson());
      }
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  Future<bool> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      final newToken = await _authService.api.changePassword(
        currentPassword: currentPassword,
        newPassword: newPassword,
      );
      if (newToken != null) {
        await _authService.persistToken(newToken);
      }
      return true;
    } catch (e) {
      _error = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    await _authService.logout();
    _user = null;
    _stats = null;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}

void unawaited(Future<void> future) {}
