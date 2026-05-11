import 'package:shared_preferences/shared_preferences.dart';

/// Direct PostgreSQL connection settings. Mirrors the values that Django uses
/// in `volunteer/settings.py` so the mobile app talks to the same database.
///
/// Persisted in SharedPreferences so the user can override host/port at
/// runtime from the "Підключення до БД" screen without rebuilding.
class DbConfig {
  static const String defaultHost = 'localhost';
  static const int defaultPort = 5432;
  static const String defaultDatabase = 'volunteer_db';
  static const String defaultUsername = 'postgres';
  static const String defaultPassword = '';
  static const bool defaultUseSsl = false;

  static const String _hostKey = 'db_host';
  static const String _portKey = 'db_port';
  static const String _dbKey = 'db_name';
  static const String _userKey = 'db_user';
  static const String _passKey = 'db_pass';
  static const String _sslKey = 'db_ssl';

  static String _host = defaultHost;
  static int _port = defaultPort;
  static String _database = defaultDatabase;
  static String _username = defaultUsername;
  static String _password = defaultPassword;
  static bool _useSsl = defaultUseSsl;

  static String get host => _host;
  static int get port => _port;
  static String get database => _database;
  static String get username => _username;
  static String get password => _password;
  static bool get useSsl => _useSsl;

  static Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _host = prefs.getString(_hostKey) ?? defaultHost;
      _port = prefs.getInt(_portKey) ?? defaultPort;
      _database = prefs.getString(_dbKey) ?? defaultDatabase;
      _username = prefs.getString(_userKey) ?? defaultUsername;
      _password = prefs.getString(_passKey) ?? defaultPassword;
      _useSsl = prefs.getBool(_sslKey) ?? defaultUseSsl;
    } catch (_) {
      // ignore — keep defaults
    }
  }

  static Future<void> save({
    required String host,
    required int port,
    required String database,
    required String username,
    required String password,
    required bool useSsl,
  }) async {
    _host = host.trim();
    _port = port;
    _database = database.trim();
    _username = username.trim();
    _password = password;
    _useSsl = useSsl;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_hostKey, _host);
    await prefs.setInt(_portKey, _port);
    await prefs.setString(_dbKey, _database);
    await prefs.setString(_userKey, _username);
    await prefs.setString(_passKey, _password);
    await prefs.setBool(_sslKey, _useSsl);
  }
}
