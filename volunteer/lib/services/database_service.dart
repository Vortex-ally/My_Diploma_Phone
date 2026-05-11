import 'package:postgres/postgres.dart';

import '../constants/db_config.dart';
import '../models/leaderboard_entry.dart';
import '../models/message.dart';
import '../models/project.dart';
import '../models/request.dart';
import '../models/subscriptions.dart';
import '../models/volunteer_goal.dart';
import '../utils/django_password.dart';

class DatabaseException implements Exception {
  final String message;
  DatabaseException(this.message);
  @override
  String toString() => message;
}

/// Direct-PostgreSQL replacement for the old `ApiService`. Mirrors that
/// class's public surface so the rest of the app (providers, screens) works
/// unchanged.
class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  Connection? _conn;
  int? _currentUserId;

  int? get currentUserId => _currentUserId;
  void setCurrentUserId(int? id) => _currentUserId = id;

  // ─── Connection management ────────────────────────────────────────────────

  Future<Connection> _connection() async {
    final existing = _conn;
    if (existing != null && existing.isOpen) return existing;
    try {
      final conn = await Connection.open(
        Endpoint(
          host: DbConfig.host,
          port: DbConfig.port,
          database: DbConfig.database,
          username: DbConfig.username,
          password: DbConfig.password.isEmpty ? null : DbConfig.password,
        ),
        settings: ConnectionSettings(
          sslMode: DbConfig.useSsl ? SslMode.require : SslMode.disable,
          connectTimeout: const Duration(seconds: 8),
          queryTimeout: const Duration(seconds: 15),
        ),
      );
      _conn = conn;
      return conn;
    } catch (e) {
      throw DatabaseException(
        "Не вдалося з'єднатися з PostgreSQL: ${_humanError(e)}",
      );
    }
  }

  Future<void> close() async {
    final c = _conn;
    _conn = null;
    if (c != null && c.isOpen) {
      try {
        await c.close();
      } catch (_) {}
    }
  }

  Future<bool> ping() async {
    try {
      final c = await _connection();
      await c.execute('SELECT 1');
      return true;
    } catch (_) {
      return false;
    }
  }

  String _humanError(Object e) {
    final s = e.toString();
    if (s.contains('SocketException') ||
        s.contains('Connection refused') ||
        s.contains('timed out') ||
        s.contains('Connection reset')) {
      return 'сервер БД недоступний (перевірте host/port та pg_hba.conf).';
    }
    if (s.contains('password') || s.contains('authentication')) {
      return 'невірний логін/пароль БД.';
    }
    return s;
  }

  Future<Result> _exec(
    String sql, {
    Map<String, dynamic>? params,
  }) async {
    final c = await _connection();
    try {
      return await c.execute(Sql.named(sql), parameters: params ?? const {});
    } catch (e) {
      throw DatabaseException(_humanError(e));
    }
  }

  // ─── Auth ─────────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> login(String email, String password) async {
    final result = await _exec(
      '''
      SELECT u.id, u.username, u.password, u.first_name, u.last_name, u.email,
             p.role, p.group_name
      FROM auth_user u
      LEFT JOIN volunteer_app_userprofile p ON p.user_id = u.id
      WHERE LOWER(u.email) = LOWER(@email) OR LOWER(u.username) = LOWER(@email)
      LIMIT 1
      ''',
      params: {'email': email},
    );
    if (result.isEmpty) {
      throw DatabaseException('Користувача не знайдено');
    }
    final row = result.first.toColumnMap();
    final hashed = row['password'] as String;
    if (!DjangoPassword.verify(password, hashed)) {
      throw DatabaseException('Невірний пароль');
    }
    final userId = row['id'] as int;
    _currentUserId = userId;
    return {
      'token': 'db_user_$userId',
      'user': {
        'id': userId,
        'username': row['username'],
        'first_name': row['first_name'],
        'last_name': row['last_name'],
        'name': (row['first_name'] as String?)?.isNotEmpty == true
            ? row['first_name']
            : row['username'],
        'email': row['email'],
        'role': row['role'] ?? 'volunteer',
        'group_name': row['group_name'],
      },
    };
  }

  void logout() {
    _currentUserId = null;
  }

  // ─── Profile ──────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> getProfile() async {
    final uid = _requireUser();
    final user = await _exec(
      '''
      SELECT u.id, u.username, u.email, u.first_name, u.last_name, u.date_joined,
             p.role, p.group_name
      FROM auth_user u
      LEFT JOIN volunteer_app_userprofile p ON p.user_id = u.id
      WHERE u.id = @id
      ''',
      params: {'id': uid},
    );
    if (user.isEmpty) {
      throw DatabaseException('Користувача не знайдено');
    }
    final u = user.first.toColumnMap();

    final stats = await _exec(
      '''
      SELECT
        (SELECT COUNT(*) FROM volunteer_app_request r
            WHERE r."Volunteer_id" = @id
              AND r.status IN ('approved','completed')) AS total_events,
        (SELECT COALESCE(SUM(
              CASE WHEN r.approved_hours IS NOT NULL
                   THEN r.approved_hours
                   ELSE COALESCE(p.hours, 0) END
           ), 0)
           FROM volunteer_app_request r
           JOIN volunteer_app_project p ON p.id = r.event_id
           WHERE r."Volunteer_id" = @id
             AND r.status IN ('approved','completed')) AS total_hours,
        (SELECT COUNT(*) FROM volunteer_app_request r
            WHERE r."Volunteer_id" = @id AND r.star_rating = TRUE) AS star_count
      ''',
      params: {'id': uid},
    );
    final s = stats.first.toColumnMap();

    return {
      'user': {
        'id': u['id'],
        'username': u['username'],
        'email': u['email'],
        'first_name': u['first_name'],
        'last_name': u['last_name'],
        'name': (u['first_name'] as String?)?.isNotEmpty == true
            ? u['first_name']
            : u['username'],
        'role': u['role'] ?? 'volunteer',
        'group_name': u['group_name'],
        'date_joined': (u['date_joined'] as DateTime?)?.toIso8601String(),
      },
      'stats': {
        'total_events': (s['total_events'] as int?) ?? 0,
        'total_hours': (s['total_hours'] as num?)?.toInt() ?? 0,
        'star_count': (s['star_count'] as int?) ?? 0,
      },
    };
  }

  Future<void> updateProfile({
    required String firstName,
    required String lastName,
    String? groupName,
  }) async {
    final uid = _requireUser();
    await _exec(
      '''
      UPDATE auth_user
      SET first_name = @first, last_name = @last
      WHERE id = @id
      ''',
      params: {'first': firstName, 'last': lastName, 'id': uid},
    );
    final group = (groupName ?? '').trim();
    await _exec(
      '''
      UPDATE volunteer_app_userprofile
      SET group_name = @g
      WHERE user_id = @id
      ''',
      params: {'g': group.isEmpty ? null : group, 'id': uid},
    );
  }

  Future<String?> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final uid = _requireUser();
    if (newPassword.length < 6) {
      throw DatabaseException('Пароль повинен містити мінімум 6 символів');
    }
    final existing = await _exec(
      'SELECT password FROM auth_user WHERE id = @id',
      params: {'id': uid},
    );
    if (existing.isEmpty) {
      throw DatabaseException('Користувача не знайдено');
    }
    final currentHash = existing.first.toColumnMap()['password'] as String;
    if (!DjangoPassword.verify(currentPassword, currentHash)) {
      throw DatabaseException('Поточний пароль невірний');
    }
    final newHash = DjangoPassword.makePassword(newPassword);
    await _exec(
      'UPDATE auth_user SET password = @h WHERE id = @id',
      params: {'h': newHash, 'id': uid},
    );
    return 'db_user_$uid';
  }

  // ─── Projects ─────────────────────────────────────────────────────────────

  Future<List<Project>> getProjects() async {
    final uid = _currentUserId;
    final rows = await _exec(
      '''
      SELECT p.id, p.name, p.description, p.location, p.organiser_id,
             u.first_name AS o_first, u.username AS o_username,
             p.date, p.hours, p.max_volunteers, p.current_volunteers,
             p.status, p.price,
             COALESCE(r.status, NULL) AS application_status,
             CASE WHEN ps.id IS NOT NULL THEN TRUE ELSE FALSE END AS has_priority
      FROM volunteer_app_project p
      JOIN auth_user u ON u.id = p.organiser_id
      LEFT JOIN volunteer_app_request r
        ON r.event_id = p.id AND r."Volunteer_id" = @uid
      LEFT JOIN volunteer_app_priorityspot ps
        ON ps.event_id = p.id AND ps.volunteer_id = @uid
      ORDER BY p.date DESC
      ''',
      params: {'uid': uid ?? -1},
    );
    return rows.map(_rowToProject).toList();
  }

  Future<Project> getProjectDetail(int projectId) async {
    final uid = _currentUserId;
    final rows = await _exec(
      '''
      SELECT p.id, p.name, p.description, p.location, p.organiser_id,
             u.first_name AS o_first, u.username AS o_username,
             p.date, p.hours, p.max_volunteers, p.current_volunteers,
             p.status, p.price,
             COALESCE(r.status, NULL) AS application_status,
             CASE WHEN ps.id IS NOT NULL THEN TRUE ELSE FALSE END AS has_priority
      FROM volunteer_app_project p
      JOIN auth_user u ON u.id = p.organiser_id
      LEFT JOIN volunteer_app_request r
        ON r.event_id = p.id AND r."Volunteer_id" = @uid
      LEFT JOIN volunteer_app_priorityspot ps
        ON ps.event_id = p.id AND ps.volunteer_id = @uid
      WHERE p.id = @pid
      LIMIT 1
      ''',
      params: {'uid': uid ?? -1, 'pid': projectId},
    );
    if (rows.isEmpty) {
      throw DatabaseException('Захід не знайдено');
    }
    return _rowToProject(rows.first);
  }

  Project _rowToProject(ResultRow row) {
    final m = row.toColumnMap();
    final firstName = (m['o_first'] as String?) ?? '';
    final username = (m['o_username'] as String?) ?? '';
    final price = m['price'];
    return Project.fromJson({
      'id': m['id'],
      'name': m['name'] ?? '',
      'description': m['description'] ?? '',
      'location': m['location'] ?? '',
      'organiser_id': m['organiser_id'],
      'organiser_name': firstName.isNotEmpty ? firstName : username,
      'date': (m['date'] as DateTime?)?.toIso8601String(),
      'hours': m['hours'] ?? 0,
      'max_volunteers': m['max_volunteers'] ?? 0,
      'current_volunteers': m['current_volunteers'] ?? 0,
      'status': m['status'] ?? 'apply',
      'price': price is num ? price.toDouble() : double.tryParse('$price') ?? 0.0,
      'application_status': m['application_status'],
      'has_priority': m['has_priority'] ?? false,
    });
  }

  Future<void> applyToProject(int projectId) async {
    final uid = _requireUser();
    final c = await _connection();
    try {
      await c.runTx((tx) async {
        final project = await tx.execute(
          Sql.named(
              'SELECT organiser_id, max_volunteers, current_volunteers FROM volunteer_app_project WHERE id = @id'),
          parameters: {'id': projectId},
        );
        if (project.isEmpty) {
          throw DatabaseException('Захід не знайдено');
        }
        final p = project.first.toColumnMap();
        if (p['organiser_id'] == uid) {
          throw DatabaseException(
              'Не можна подати заявку на власний проєкт');
        }
        final existing = await tx.execute(
          Sql.named(
              'SELECT 1 FROM volunteer_app_request WHERE event_id = @e AND "Volunteer_id" = @u'),
          parameters: {'e': projectId, 'u': uid},
        );
        if (existing.isNotEmpty) {
          throw DatabaseException('Заявка вже подана');
        }
        await tx.execute(
          Sql.named(
              'INSERT INTO volunteer_app_request (event_id, "Volunteer_id", status, organizer_reported, star_rating, date_requested) VALUES (@e, @u, \'pending\', FALSE, FALSE, NOW())'),
          parameters: {'e': projectId, 'u': uid},
        );
        if ((p['max_volunteers'] as int?) != null &&
            (p['max_volunteers'] as int) > 0) {
          await tx.execute(
            Sql.named(
                'UPDATE volunteer_app_project SET current_volunteers = current_volunteers + 1 WHERE id = @id'),
            parameters: {'id': projectId},
          );
        }
      });
    } on DatabaseException {
      rethrow;
    } catch (e) {
      throw DatabaseException(_humanError(e));
    }
  }

  // ─── Applications ─────────────────────────────────────────────────────────

  Future<List<Request>> getMyApplications() async {
    final uid = _requireUser();
    final rows = await _exec(
      '''
      SELECT r.id, r.event_id, p.name AS project_name, p.date AS project_date,
             p.hours AS project_hours, p.location AS project_location,
             r.status, r.approved_hours, r.organizer_report,
             r.star_rating, r.date_requested,
             CASE WHEN r.status = 'completed' AND vr.id IS NULL
                  THEN TRUE ELSE FALSE END AS can_review
      FROM volunteer_app_request r
      JOIN volunteer_app_project p ON p.id = r.event_id
      LEFT JOIN volunteer_app_volunteerreview vr
        ON vr.event_id = r.event_id AND vr.volunteer_id = r."Volunteer_id"
      WHERE r."Volunteer_id" = @uid
      ORDER BY r.date_requested DESC
      ''',
      params: {'uid': uid},
    );
    return rows.map((row) {
      final m = row.toColumnMap();
      return Request.fromJson({
        'id': m['id'],
        'project_id': m['event_id'],
        'project_name': m['project_name'] ?? '',
        'project_date': (m['project_date'] as DateTime?)?.toIso8601String(),
        'project_hours': m['project_hours'],
        'project_location': m['project_location'] ?? '',
        'status': m['status'] ?? 'pending',
        'approved_hours': m['approved_hours'],
        'organizer_report': m['organizer_report'],
        'star_rating': m['star_rating'] ?? false,
        'date': (m['date_requested'] as DateTime).toIso8601String(),
        'can_review': m['can_review'] ?? false,
      });
    }).toList();
  }

  // ─── Goal ─────────────────────────────────────────────────────────────────

  int _extractCourse(String? group) {
    if (group == null) return 1;
    for (final ch in group.split('')) {
      final n = int.tryParse(ch);
      if (n != null) return n;
    }
    return 1;
  }

  Future<int> _calcCurrentHours(int uid) async {
    final res = await _exec(
      '''
      SELECT COALESCE(SUM(
        CASE WHEN r.approved_hours IS NOT NULL
             THEN r.approved_hours
             ELSE COALESCE(p.hours, 0) END
      ), 0) AS total
      FROM volunteer_app_request r
      JOIN volunteer_app_project p ON p.id = r.event_id
      WHERE r."Volunteer_id" = @id AND r.status IN ('approved','completed')
      ''',
      params: {'id': uid},
    );
    return (res.first.toColumnMap()['total'] as num?)?.toInt() ?? 0;
  }

  Future<VolunteerGoal> getGoal() async {
    final uid = _requireUser();
    final group = await _exec(
      'SELECT group_name FROM volunteer_app_userprofile WHERE user_id = @id',
      params: {'id': uid},
    );
    final groupName =
        group.isEmpty ? null : group.first.toColumnMap()['group_name'] as String?;
    final course = _extractCourse(groupName);
    final defaultTarget = course == 1 ? 10 : 20;

    final goal = await _exec(
      'SELECT target_hours FROM volunteer_app_volunteergoal WHERE volunteer_id = @id',
      params: {'id': uid},
    );
    final hasGoal = goal.isNotEmpty;
    final target = hasGoal
        ? (goal.first.toColumnMap()['target_hours'] as int)
        : defaultTarget;
    final currentHours = await _calcCurrentHours(uid);
    final progress = target > 0
        ? (currentHours / target * 100.0).clamp(0.0, 100.0)
        : 100.0;

    return VolunteerGoal.fromJson({
      'target_hours': target,
      'current_hours': currentHours,
      'completed': currentHours >= target,
      'progress_percentage': double.parse(progress.toStringAsFixed(1)),
      'has_goal': hasGoal,
    });
  }

  Future<VolunteerGoal> setGoal({int? targetHours}) async {
    final uid = _requireUser();
    final group = await _exec(
      'SELECT group_name FROM volunteer_app_userprofile WHERE user_id = @id',
      params: {'id': uid},
    );
    final groupName =
        group.isEmpty ? null : group.first.toColumnMap()['group_name'] as String?;
    final defaultTarget = _extractCourse(groupName) == 1 ? 10 : 20;
    final target = (targetHours == null || targetHours < 1)
        ? defaultTarget
        : targetHours;
    final currentHours = await _calcCurrentHours(uid);
    final completed = currentHours >= target;

    await _exec(
      '''
      INSERT INTO volunteer_app_volunteergoal (volunteer_id, target_hours, current_hours, completed)
      VALUES (@u, @t, @c, @done)
      ON CONFLICT (volunteer_id) DO UPDATE
      SET target_hours = EXCLUDED.target_hours,
          current_hours = EXCLUDED.current_hours,
          completed = EXCLUDED.completed
      ''',
      params: {'u': uid, 't': target, 'c': currentHours, 'done': completed},
    );

    return VolunteerGoal.fromJson({
      'target_hours': target,
      'current_hours': currentHours,
      'completed': completed,
      'progress_percentage': target > 0
          ? double.parse(
              (currentHours / target * 100.0).clamp(0.0, 100.0).toStringAsFixed(1))
          : 100.0,
      'has_goal': true,
    });
  }

  // ─── Leaderboard ──────────────────────────────────────────────────────────

  Future<List<LeaderboardEntry>> getLeaderboard() async {
    final me = _requireUser();
    final rows = await _exec(
      '''
      SELECT u.id, u.first_name, u.username, p.group_name,
             COALESCE(SUM(CASE WHEN r.status IN ('approved','completed')
                               THEN pr.hours ELSE 0 END), 0) AS total_hours
      FROM auth_user u
      JOIN volunteer_app_userprofile p ON p.user_id = u.id
      LEFT JOIN volunteer_app_request r ON r."Volunteer_id" = u.id
      LEFT JOIN volunteer_app_project pr ON pr.id = r.event_id
      WHERE p.role = 'volunteer'
      GROUP BY u.id, u.first_name, u.username, p.group_name
      ORDER BY total_hours DESC, u.username ASC
      ''',
    );
    final list = <LeaderboardEntry>[];
    var rank = 0;
    for (final r in rows) {
      rank++;
      final m = r.toColumnMap();
      list.add(LeaderboardEntry.fromJson({
        'rank': rank,
        'id': m['id'],
        'name': (m['first_name'] as String?)?.isNotEmpty == true
            ? m['first_name']
            : m['username'],
        'group_name': m['group_name'],
        'total_hours': (m['total_hours'] as num?)?.toInt() ?? 0,
        'is_me': m['id'] == me,
      }));
    }
    return list;
  }

  // ─── Participants (premium) ────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getParticipants(int projectId) async {
    final uid = _requireUser();
    final subs = await _exec(
      "SELECT id FROM volunteer_app_usersubscription WHERE user_id = @uid AND plan_type = 'premium' AND is_active = TRUE",
      params: {'uid': uid},
    );
    if (subs.isEmpty) {
      throw DatabaseException('Необхідна Premium підписка для перегляду учасників');
    }
    final rows = await _exec(
      '''
      SELECT u.first_name, u.last_name, u.username, p.group_name, r.status
      FROM volunteer_app_request r
      JOIN auth_user u ON u.id = r."Volunteer_id"
      LEFT JOIN volunteer_app_userprofile p ON p.user_id = u.id
      WHERE r.event_id = @eid AND r.status IN ('approved','completed')
      ORDER BY u.username
      ''',
      params: {'eid': projectId},
    );
    return rows.map((row) {
      final m = row.toColumnMap();
      final first = (m['first_name'] as String?) ?? '';
      final last = (m['last_name'] as String?) ?? '';
      final username = (m['username'] as String?) ?? '';
      return <String, dynamic>{
        'name': first.isNotEmpty
            ? (last.isNotEmpty ? '$first $last' : first)
            : username,
        'group': (m['group_name'] as String?) ?? '',
        'status': m['status'] ?? '',
      };
    }).toList();
  }

  // ─── Reviews ──────────────────────────────────────────────────────────────

  Future<void> submitReview({
    required int requestId,
    required int rating,
    required String comment,
  }) async {
    final uid = _requireUser();
    if (rating < 1 || rating > 5) {
      throw DatabaseException('Оцінка має бути від 1 до 5');
    }
    final req = await _exec(
      '''
      SELECT event_id FROM volunteer_app_request
      WHERE id = @rid AND "Volunteer_id" = @uid AND status = 'completed'
      ''',
      params: {'rid': requestId, 'uid': uid},
    );
    if (req.isEmpty) {
      throw DatabaseException('Заявку для відгуку не знайдено');
    }
    final eventId = req.first.toColumnMap()['event_id'];

    final exists = await _exec(
      'SELECT 1 FROM volunteer_app_volunteerreview WHERE volunteer_id = @u AND event_id = @e',
      params: {'u': uid, 'e': eventId},
    );
    if (exists.isNotEmpty) {
      throw DatabaseException('Відгук вже залишено');
    }
    await _exec(
      '''
      INSERT INTO volunteer_app_volunteerreview (volunteer_id, event_id, rating, comment, created_at)
      VALUES (@u, @e, @r, @c, NOW())
      ''',
      params: {'u': uid, 'e': eventId, 'r': rating, 'c': comment},
    );
  }

  // ─── Chat ─────────────────────────────────────────────────────────────────

  Future<List<ChatPreview>> getChatUsers() async {
    final me = _requireUser();
    final rows = await _exec(
      '''
      SELECT u.id, u.username, u.first_name, p.role
      FROM auth_user u
      JOIN volunteer_app_userprofile p ON p.user_id = u.id
      WHERE p.role IN ('volunteer','organiser','admin') AND u.id != @me
      ''',
      params: {'me': me},
    );
    final previews = <ChatPreview>[];
    for (final r in rows) {
      final m = r.toColumnMap();
      final otherId = m['id'] as int;
      final last = await _exec(
        '''
        SELECT content, created_at, sender_id
        FROM volunteer_app_message
        WHERE (sender_id = @me AND recipient_id = @o)
           OR (sender_id = @o AND recipient_id = @me)
        ORDER BY created_at DESC
        LIMIT 1
        ''',
        params: {'me': me, 'o': otherId},
      );
      final unread = await _exec(
        '''
        SELECT COUNT(*) AS c FROM volunteer_app_message
        WHERE sender_id = @o AND recipient_id = @me AND is_read = FALSE
        ''',
        params: {'me': me, 'o': otherId},
      );
      Map<String, dynamic>? lastJson;
      if (last.isNotEmpty) {
        final lm = last.first.toColumnMap();
        lastJson = {
          'content': lm['content'],
          'created_at': (lm['created_at'] as DateTime).toIso8601String(),
          'is_mine': lm['sender_id'] == me,
        };
      }
      previews.add(ChatPreview.fromJson({
        'id': otherId,
        'username': m['username'],
        'name': (m['first_name'] as String?)?.isNotEmpty == true
            ? m['first_name']
            : m['username'],
        'role': m['role'] ?? 'volunteer',
        'last_message': lastJson,
        'unread_count':
            (unread.first.toColumnMap()['c'] as num?)?.toInt() ?? 0,
      }));
    }
    previews.sort((a, b) {
      final aT = a.lastAt?.millisecondsSinceEpoch ?? 0;
      final bT = b.lastAt?.millisecondsSinceEpoch ?? 0;
      return bT.compareTo(aT);
    });
    return previews;
  }

  Future<({List<Message> messages, ChatPartner partner})> getChatMessages(
    String username,
  ) async {
    final me = _requireUser();
    final other = await _exec(
      '''
      SELECT u.id, u.username, u.first_name, p.role
      FROM auth_user u
      LEFT JOIN volunteer_app_userprofile p ON p.user_id = u.id
      WHERE u.username = @uname
      ''',
      params: {'uname': username},
    );
    if (other.isEmpty) {
      throw DatabaseException('Співрозмовника не знайдено');
    }
    final om = other.first.toColumnMap();
    final otherId = om['id'] as int;

    final rows = await _exec(
      '''
      SELECT m.id, m.sender_id, m.recipient_id, m.content, m.created_at, m.is_read,
             us.first_name AS s_first, us.username AS s_username,
             ur.first_name AS r_first, ur.username AS r_username
      FROM volunteer_app_message m
      JOIN auth_user us ON us.id = m.sender_id
      JOIN auth_user ur ON ur.id = m.recipient_id
      WHERE (m.sender_id = @me AND m.recipient_id = @o)
         OR (m.sender_id = @o AND m.recipient_id = @me)
      ORDER BY m.created_at ASC
      ''',
      params: {'me': me, 'o': otherId},
    );
    final messages = rows.map((row) {
      final m = row.toColumnMap();
      return Message.fromJson({
        'id': m['id'],
        'sender_id': m['sender_id'],
        'sender_name': (m['s_first'] as String?)?.isNotEmpty == true
            ? m['s_first']
            : m['s_username'],
        'recipient_id': m['recipient_id'],
        'recipient_name': (m['r_first'] as String?)?.isNotEmpty == true
            ? m['r_first']
            : m['r_username'],
        'content': m['content'],
        'created_at': (m['created_at'] as DateTime).toIso8601String(),
        'is_read': m['is_read'] ?? false,
        'is_mine': m['sender_id'] == me,
      });
    }).toList();

    await _exec(
      '''
      UPDATE volunteer_app_message SET is_read = TRUE
      WHERE sender_id = @o AND recipient_id = @me AND is_read = FALSE
      ''',
      params: {'me': me, 'o': otherId},
    );

    final partner = ChatPartner.fromJson({
      'id': otherId,
      'username': om['username'],
      'name': (om['first_name'] as String?)?.isNotEmpty == true
          ? om['first_name']
          : om['username'],
      'role': om['role'] ?? 'volunteer',
    });
    return (messages: messages, partner: partner);
  }

  Future<Message> sendMessage({
    required String recipientUsername,
    required String content,
  }) async {
    final me = _requireUser();
    final recipient = await _exec(
      'SELECT id, first_name, username FROM auth_user WHERE username = @u',
      params: {'u': recipientUsername},
    );
    if (recipient.isEmpty) {
      throw DatabaseException('Отримувача не знайдено');
    }
    final r = recipient.first.toColumnMap();
    final inserted = await _exec(
      '''
      INSERT INTO volunteer_app_message (sender_id, recipient_id, content, created_at, is_read)
      VALUES (@s, @r, @c, NOW(), FALSE)
      RETURNING id, created_at
      ''',
      params: {'s': me, 'r': r['id'], 'c': content},
    );
    final m = inserted.first.toColumnMap();
    return Message.fromJson({
      'id': m['id'],
      'sender_id': me,
      'recipient_id': r['id'],
      'content': content,
      'created_at': (m['created_at'] as DateTime).toIso8601String(),
      'is_read': false,
      'is_mine': true,
    });
  }

  // ─── Subscriptions / purchase ─────────────────────────────────────────────

  Future<Subscriptions> getSubscriptions() async {
    final uid = _requireUser();
    final subs = await _exec(
      '''
      SELECT plan_type FROM volunteer_app_usersubscription
      WHERE user_id = @uid AND is_active = TRUE
      ''',
      params: {'uid': uid},
    );
    final plans =
        subs.map((r) => r.toColumnMap()['plan_type'] as String).toList();

    final priorities = await _exec(
      '''
      SELECT event_id FROM volunteer_app_priorityspot WHERE volunteer_id = @uid
      ''',
      params: {'uid': uid},
    );
    final priorityIds =
        priorities.map((r) => r.toColumnMap()['event_id'] as int).toList();

    return Subscriptions.fromJson({
      'active_plans': plans,
      'has_premium': plans.contains('premium'),
      'has_analytics':
          plans.contains('analytics') || plans.contains('premium'),
      'priority_event_ids': priorityIds,
    });
  }

  Future<Map<String, dynamic>> purchase({
    required String planType,
    int? projectId,
    required String cardNumber,
    required String cardholder,
    required String expiry,
    required String cvv,
  }) async {
    final uid = _requireUser();
    final cleanCard = cardNumber.replaceAll(' ', '');
    final ok = cleanCard.length >= 12 &&
        RegExp(r'^\d+$').hasMatch(cleanCard) &&
        cardholder.trim().isNotEmpty &&
        expiry.trim().length >= 4 &&
        cvv.trim().length >= 3 &&
        RegExp(r'^\d+$').hasMatch(cvv.trim());
    if (!ok) {
      throw DatabaseException('Невірні платіжні дані');
    }

    if (planType == 'premium' || planType == 'analytics') {
      await _exec(
        '''
        INSERT INTO volunteer_app_usersubscription (user_id, plan_type, purchased_at, is_active)
        VALUES (@u, @p, NOW(), TRUE)
        ON CONFLICT (user_id, plan_type) DO UPDATE SET is_active = TRUE
        ''',
        params: {'u': uid, 'p': planType},
      );
      return {
        'subscription': {'plan_type': planType, 'is_active': true}
      };
    }
    if (planType == 'priority') {
      if (projectId == null) {
        throw DatabaseException('Не вказано проєкт');
      }
      await _exec(
        '''
        INSERT INTO volunteer_app_priorityspot (volunteer_id, event_id, created_at)
        VALUES (@u, @e, NOW())
        ON CONFLICT (volunteer_id, event_id) DO NOTHING
        ''',
        params: {'u': uid, 'e': projectId},
      );
      final existing = await _exec(
        '''
        SELECT id FROM volunteer_app_request
        WHERE "Volunteer_id" = @u AND event_id = @e
        ''',
        params: {'u': uid, 'e': projectId},
      );
      if (existing.isEmpty) {
        await applyToProject(projectId);
      }
      return {
        'priority': {'project_id': projectId}
      };
    }
    throw DatabaseException('Невідомий тарифний план');
  }

  // ─── Organizer ────────────────────────────────────────────────────────────

  Future<List<Project>> getOrganizerProjects() async {
    final uid = _requireUser();
    final rows = await _exec(
      '''
      SELECT p.id, p.name, p.description, p.location, p.organiser_id,
             u.first_name AS o_first, u.username AS o_username,
             p.date, p.hours, p.max_volunteers, p.current_volunteers,
             p.status, p.price,
             NULL AS application_status,
             FALSE AS has_priority
      FROM volunteer_app_project p
      JOIN auth_user u ON u.id = p.organiser_id
      WHERE p.organiser_id = @uid
      ORDER BY p.date DESC
      ''',
      params: {'uid': uid},
    );
    return rows.map(_rowToProject).toList();
  }

  Future<Project> createProject({
    required String name,
    required String description,
    required String location,
    required DateTime date,
    required int hours,
    required int maxVolunteers,
    double price = 0,
  }) async {
    final uid = _requireUser();
    final rows = await _exec(
      '''
      INSERT INTO volunteer_app_project
        (name, description, location, organiser_id, date, hours, max_volunteers, current_volunteers, status, price)
      VALUES (@name, @desc, @loc, @uid, @date, @hrs, @max, 0, 'apply', @price)
      RETURNING id
      ''',
      params: {
        'name': name,
        'desc': description,
        'loc': location,
        'uid': uid,
        'date': date,
        'hrs': hours,
        'max': maxVolunteers,
        'price': price,
      },
    );
    final id = rows.first.toColumnMap()['id'] as int;
    return getProjectDetail(id);
  }

  Future<List<Map<String, dynamic>>> getProjectApplications(int projectId) async {
    final uid = _requireUser();
    final rows = await _exec(
      '''
      SELECT r.id, r.status, r.approved_hours, r.organizer_report,
             r.star_rating, r.date_requested,
             u.id AS volunteer_id, u.first_name, u.last_name, u.username,
             p.group_name
      FROM volunteer_app_request r
      JOIN auth_user u ON u.id = r."Volunteer_id"
      LEFT JOIN volunteer_app_userprofile p ON p.user_id = u.id
      WHERE r.event_id = @eid
        AND (SELECT organiser_id FROM volunteer_app_project WHERE id = @eid) = @uid
      ORDER BY r.date_requested DESC
      ''',
      params: {'eid': projectId, 'uid': uid},
    );
    return rows.map((row) {
      final m = row.toColumnMap();
      final first = (m['first_name'] as String?) ?? '';
      final last = (m['last_name'] as String?) ?? '';
      final username = (m['username'] as String?) ?? '';
      return <String, dynamic>{
        'id': m['id'],
        'volunteer_name': first.isNotEmpty
            ? (last.isNotEmpty ? '$first $last' : first)
            : username,
        'group_name': (m['group_name'] as String?) ?? '',
        'status': m['status'] ?? 'pending',
        'approved_hours': m['approved_hours'],
        'organizer_report': m['organizer_report'],
        'star_rating': m['star_rating'] ?? false,
        'date_requested': (m['date_requested'] as DateTime?)?.toIso8601String(),
      };
    }).toList();
  }

  Future<void> updateApplicationStatus({
    required int requestId,
    required String status,
    int? approvedHours,
    String? report,
    bool? starRating,
  }) async {
    final uid = _requireUser();
    final req = await _exec(
      '''
      SELECT r.id FROM volunteer_app_request r
      JOIN volunteer_app_project p ON p.id = r.event_id
      WHERE r.id = @rid AND p.organiser_id = @uid
      ''',
      params: {'rid': requestId, 'uid': uid},
    );
    if (req.isEmpty) {
      throw DatabaseException('Заявку не знайдено або недостатньо прав');
    }
    final params = <String, dynamic>{
      'status': status,
      'rid': requestId,
    };
    final setParts = <String>['status = @status'];
    if (approvedHours != null) {
      setParts.add('approved_hours = @hours');
      params['hours'] = approvedHours;
    }
    if (report != null) {
      setParts.add('organizer_report = @report');
      params['report'] = report;
    }
    if (starRating != null) {
      setParts.add('star_rating = @star');
      params['star'] = starRating;
    }
    await _exec(
      'UPDATE volunteer_app_request SET ${setParts.join(', ')} WHERE id = @rid',
      params: params,
    );
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────

  int _requireUser() {
    final id = _currentUserId;
    if (id == null) {
      throw DatabaseException('Не авторизовано');
    }
    return id;
  }
}
