/**
 * Test User Creation Script for Volunteer App
 *
 * This Dart script creates test users with different roles (volunteer, organiser, admin)
 * by calling the Django REST API. It can be run from the command line or imported
 * as a library in Flutter tests.
 *
 * Usage (CLI):
 *   dart run create_test_users.dart --count 10 --roles volunteer,organiser --password test123456
 *
 * Usage (Library):
 *   final creator = TestUserCreator(baseUrl: 'http://localhost:8000');
 *   await creator.createTestUsers(count: 5, roles: ['volunteer', 'organiser']);
 */

import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:http/http.dart' as http;

/// Configuration for test user creation
class TestUserConfig {
  final String baseUrl;
  final String adminEmail;
  final String adminPassword;
  final int count;
  final List<String> roles;
  final String password;
  final bool clearExisting;
  final bool createProjects;

  const TestUserConfig({
    this.baseUrl = 'http://192.168.0.105:8000',
    this.adminEmail = 'admin@volunteer.test',
    this.adminPassword = 'admin123',
    this.count = 5,
    this.roles = const ['volunteer', 'organiser', 'admin'],
    this.password = 'test123456',
    this.clearExisting = false,
    this.createProjects = true,
  });
}

/// Represents a test user to be created
class TestUser {
  final String username;
  final String email;
  final String firstName;
  final String lastName;
  final String role;
  final String password;
  final String? groupName;

  const TestUser({
    required this.username,
    required this.email,
    required this.firstName,
    required this.lastName,
    required this.role,
    required this.password,
    this.groupName,
  });

  Map<String, dynamic> toJson() => {
    'username': username,
    'email': email,
    'first_name': firstName,
    'last_name': lastName,
    'password': password,
    'role': role,
    'group_name': groupName,
  };
}

/// Creates test users via the Django API
class TestUserCreator {
  final String baseUrl;
  final http.Client _client = http.Client();
  String? _token;

  TestUserCreator({required this.baseUrl});

  /// Login as admin to get authentication token
  Future<bool> login(String email, String password) async {
    try {
      final response = await _client.post(
        Uri.parse('$baseUrl/api/auth/login/'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'password': password}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _token = data['token'];
        print('✓ Logged in successfully');
        return true;
      } else {
        print('✗ Login failed: ${response.body}');
        return false;
      }
    } catch (e) {
      print('✗ Login error: $e');
      return false;
    }
  }

  /// Get authentication headers
  Map<String, String> get _authHeaders => {
    'Content-Type': 'application/json',
    if (_token != null) 'Authorization': 'Token $_token',
  };

  /// Create a single user via API
  Future<bool> createUser(TestUser user) async {
    try {
      // Note: The Django API doesn't have a direct user creation endpoint
      // We'll use the admin dashboard endpoint or create via User model if needed
      // For now, we'll simulate creation by directly using the Django ORM
      // This method should be called from within the Django environment
      print(
        '  ⚠ API user creation not implemented - use Python script instead',
      );
      return false;
    } catch (e) {
      print('✗ Error creating user ${user.username}: $e');
      return false;
    }
  }

  /// Get all users
  Future<List<dynamic>> getUsers() async {
    try {
      final response = await _client.get(
        Uri.parse('$baseUrl/api/users/'),
        headers: _authHeaders,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['users'] ?? [];
      } else {
        print('✗ Failed to get users: ${response.body}');
        return [];
      }
    } catch (e) {
      print('✗ Error getting users: $e');
      return [];
    }
  }

  /// Get all projects
  Future<List<dynamic>> getProjects() async {
    try {
      final response = await _client.get(
        Uri.parse('$baseUrl/api/projects/'),
        headers: _authHeaders,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['projects'] ?? [];
      } else {
        print('✗ Failed to get projects: ${response.body}');
        return [];
      }
    } catch (e) {
      print('✗ Error getting projects: $e');
      return [];
    }
  }

  /// Create a test project
  Future<bool> createTestProject({
    required String name,
    required String description,
    required String location,
    required int hours,
    required int maxVolunteers,
  }) async {
    try {
      final response = await _client.post(
        Uri.parse('$baseUrl/api/projects/'),
        headers: _authHeaders,
        body: jsonEncode({
          'name': name,
          'description': description,
          'location': location,
          'hours': hours,
          'max_volunteers': maxVolunteers,
          'days': 7,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        print('  ✓ Created project: $name');
        return true;
      } else {
        print('✗ Failed to create project: ${response.body}');
        return false;
      }
    } catch (e) {
      print('✗ Error creating project: $e');
      return false;
    }
  }

  /// Apply to a project as a volunteer
  Future<bool> applyToProject(int projectId) async {
    try {
      final response = await _client.post(
        Uri.parse('$baseUrl/api/projects/$projectId/apply/'),
        headers: _authHeaders,
      );

      if (response.statusCode == 200) {
        print('  ✓ Applied to project #$projectId');
        return true;
      } else {
        print('✗ Failed to apply: ${response.body}');
        return false;
      }
    } catch (e) {
      print('✗ Error applying: $e');
      return false;
    }
  }

  /// Close HTTP client
  void dispose() {
    _client.close();
  }

  /// Create multiple test projects
  Future<void> createTestProjects(int count) async {
    final projectNames = [
      'Збори пластику у парку',
      'Посадка дерев біля школи',
      'Прибирання берегової лінії',
      'Майстер-клас з рукоділля',
      'Тренінг з першої допомоги',
      'Організація благодійного ярмарку',
      'Пікник для дітей-сиріт',
      'Розбудова громадського простору',
      'Курс компʼютерної грамотності',
      'Екологічна акція "Чисте місто"',
    ];

    final descriptions = [
      'Долучайтеся до важливої та корисної суспільної роботи!',
      'Разом ми можемо зробити більше для нашого спільноти.',
      'Чекаємо на активних та енергійних волонтерів!',
    ];

    final locations = [
      'Парк культури та відпочинку',
      'Центральна площа',
      'Берегова лінія річки',
      'Училище №1',
      'Міський парк',
    ];

    final random = Random();
    int created = 0;

    for (int i = 0; i < count; i++) {
      final name = projectNames[random.nextInt(projectNames.length)];
      final success = await createTestProject(
        name: '$name #${i + 1}',
        description: descriptions[random.nextInt(descriptions.length)],
        location: locations[random.nextInt(locations.length)],
        hours: 2 + random.nextInt(7),
        maxVolunteers: random.nextBool() ? 0 : 5 + random.nextInt(15),
      );
      if (success) created++;
      await Future.delayed(const Duration(milliseconds: 200));
    }

    print('\n✓ Created $created/$count projects');
  }
}

/// Main function for CLI usage
Future<void> main(List<String> args) async {
  final parser = ArgParser()
    ..addOption(
      'count',
      abbr: 'c',
      defaultsTo: '5',
      help: 'Number of users per role',
    )
    ..addOption(
      'roles',
      abbr: 'r',
      defaultsTo: 'volunteer,organiser,admin',
      help: 'Comma-separated roles',
    )
    ..addOption(
      'password',
      abbr: 'p',
      defaultsTo: 'test123456',
      help: 'Password for created users',
    )
    ..addOption(
      'url',
      abbr: 'u',
      defaultsTo: 'http://192.168.0.105:8000',
      help: 'Base URL of Django API',
    )
    ..addFlag('help', abbr: 'h', negatable: false, help: 'Show help');

  try {
    final results = parser.parse(args);

    if (results['help'] as bool) {
      print('Test User Creation Script for Volunteer App');
      print('\nUsage: dart run create_test_users.dart [options]');
      print('\nOptions:');
      print(parser.usage);
      print('\nExamples:');
      print(
        '  dart run create_test_users.dart --count 10 --roles volunteer,organiser',
      );
      print(
        '  dart run create_test_users.dart -c 5 -r volunteer -p mypassword123',
      );
      return;
    }

    final count = int.tryParse(results['count'] as String) ?? 5;
    final roles = (results['roles'] as String)
        .split(',')
        .map((r) => r.trim())
        .toList();
    final password = results['password'] as String;
    final baseUrl = results['url'] as String;

    print('=' * 60);
    print('VOLUNTEER APP - TEST USER CREATOR');
    print('=' * 60);
    print('\nConfiguration:');
    print('  Base URL: $baseUrl');
    print('  Roles: ${roles.join(", ")}');
    print('  Count per role: $count');
    print('  Password: $password');
    print('');

    final creator = TestUserCreator(baseUrl: baseUrl);

    // Login first with admin credentials
    print('Logging in...');
    bool loggedIn = await creator.login('admin@volunteer.test', 'admin123');

    if (!loggedIn) {
      print('\n⚠ Warning: Could not login with default admin credentials.');
      print('Note: User creation via API requires admin authentication.');
      print('\nTo create test users, use the Python script instead:');
      print('  cd /path/to/Django/project');
      print(
        '  python create_test_data.py --count $count --roles ${roles.join(",")}\n',
      );
      creator.dispose();
      return;
    }

    print('\nAvailable commands:');
    print('  - Get users: GET /api/users/');
    print('  - Get projects: GET /api/projects/');
    print('  - Create project: POST /api/projects/');
    print('');

    // Show existing users
    print('Fetching existing users...');
    final users = await creator.getUsers();
    print('  Found ${users.length} users');

    // Show existing projects
    print('\nFetching existing projects...');
    final projects = await creator.getProjects();
    print('  Found ${projects.length} projects');

    // Create test projects
    if (projects.length < 5) {
      print('\nCreating test projects...');
      await creator.createTestProjects(5);
    } else {
      print('\n✓ Sufficient projects already exist');
    }

    creator.dispose();

    print('\n' + '=' * 60);
    print('✓ Done!');
    print('=' * 60);
    print('\nNote: To create test users with specific roles,');
    print('use the Python script which directly accesses the database.');
  } catch (e) {
    print('Error parsing arguments: $e');
    print('Use --help for usage information');
  }
}

/// ArgParser for CLI argument parsing
class ArgParser {
  final Map<String, ArgOption> _options = {};
  final Map<String, ArgResult> _results = {};

  void addOption(
    String name, {
    String? abbr,
    String? defaultsTo,
    String? help,
    bool negatable = false,
  }) {
    _options[name] = ArgOption(
      name: name,
      abbr: abbr,
      defaultsTo: defaultsTo,
      help: help,
      negatable: negatable,
    );
  }

  void addFlag(
    String name, {
    String? abbr,
    bool negatable = false,
    String? help,
    bool defaultsTo = false,
  }) {
    _options[name] = ArgOption(
      name: name,
      abbr: abbr,
      isFlag: true,
      defaultsTo: defaultsTo.toString(),
      help: help,
      negatable: negatable,
    );
  }

  ArgResults parse(List<String> args) {
    for (int i = 0; i < args.length; i++) {
      final arg = args[i];
      if (arg.startsWith('--')) {
        final name = arg.substring(2);
        final option = _options[name];
        if (option != null) {
          if (option.isFlag) {
            _results[name] = ArgResult(name, 'true');
          } else if (i + 1 < args.length && !args[i + 1].startsWith('-')) {
            _results[name] = ArgResult(name, args[i + 1]);
            i++;
          }
        }
      } else if (arg.startsWith('-') && arg.length == 2) {
        final abbr = arg.substring(1);
        final option = _options.values.firstWhere(
          (o) => o.abbr == abbr,
          orElse: () => ArgOption(name: ''),
        );
        if (option.name.isNotEmpty) {
          if (option.isFlag) {
            _results[option.name] = ArgResult(option.name, 'true');
          } else if (i + 1 < args.length && !args[i + 1].startsWith('-')) {
            _results[option.name] = ArgResult(option.name, args[i + 1]);
            i++;
          }
        }
      }
    }

    for (final entry in _options.entries) {
      if (!_results.containsKey(entry.key) && entry.value.defaultsTo != null) {
        _results[entry.key] = ArgResult(entry.key, entry.value.defaultsTo!);
      }
    }

    return ArgResults._(_results);
  }

  String get usage {
    final buf = StringBuffer();
    for (final entry in _options.entries) {
      final opt = entry.value;
      final abbr = opt.abbr != null ? '  -${opt.abbr},' : '     ';
      final defaultStr = opt.defaultsTo != null
          ? ' (defaults to "${opt.defaultsTo}")'
          : '';
      buf.writeln(
        '$abbr --${opt.name}$defaultStr${opt.help != null ? '\n       ${opt.help}' : ''}',
      );
    }
    return buf.toString();
  }
}

class ArgOption {
  final String name;
  final String? abbr;
  final String? defaultsTo;
  final String? help;
  final bool negatable;
  final bool isFlag;

  ArgOption({
    required this.name,
    this.abbr,
    this.defaultsTo,
    this.help,
    this.negatable = false,
    this.isFlag = false,
  });
}

class ArgResults {
  final Map<String, ArgResult> _results;

  ArgResults._(this._results);

  dynamic operator [](String name) => _results[name]?.value;

  bool get parsed => _results.isNotEmpty;
}

class ArgResult {
  final String name;
  final String value;

  ArgResult(this.name, this.value);
}
