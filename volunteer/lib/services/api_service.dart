import '../models/leaderboard_entry.dart';
import '../models/message.dart';
import '../models/project.dart';
import '../models/request.dart';
import '../models/subscriptions.dart';
import '../models/volunteer_goal.dart';
import 'database_service.dart';

/// Compatibility shim. The mobile app no longer talks to the Django HTTP API —
/// it connects directly to the same PostgreSQL database. The rest of the
/// codebase (providers, screens) still imports `ApiService`, so this class
/// preserves the old surface while delegating to [DatabaseService].
class ApiException implements Exception {
  final String message;
  final int? statusCode;
  ApiException(this.message, {this.statusCode});
  @override
  String toString() => message;
}

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  final DatabaseService _db = DatabaseService();

  String? _token;
  String? get token => _token;

  void setToken(String? token) {
    _token = token;
    _db.setCurrentUserId(_userIdFromToken(token));
  }

  void clearToken() {
    _token = null;
    _db.setCurrentUserId(null);
  }

  int? _userIdFromToken(String? token) {
    if (token == null) return null;
    const prefix = 'db_user_';
    if (!token.startsWith(prefix)) return null;
    return int.tryParse(token.substring(prefix.length));
  }

  T _wrap<T>(T Function() fn) {
    try {
      return fn();
    } on DatabaseException catch (e) {
      throw ApiException(e.message);
    }
  }

  Future<T> _wrapAsync<T>(Future<T> Function() fn) async {
    try {
      return await fn();
    } on DatabaseException catch (e) {
      throw ApiException(e.message);
    }
  }

  Future<bool> ping() => _db.ping();

  // ─── Auth ─────────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> login(String email, String password) async {
    final result = await _wrapAsync(() => _db.login(email, password));
    _token = result['token'] as String?;
    return result;
  }

  void logout() {
    _token = null;
    _wrap(() => _db.logout());
  }

  Future<void> close() => _db.close();

  // ─── Profile ──────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> getProfile() => _wrapAsync(() => _db.getProfile());

  Future<void> updateProfile({
    required String firstName,
    required String lastName,
    String? groupName,
  }) =>
      _wrapAsync(() => _db.updateProfile(
            firstName: firstName,
            lastName: lastName,
            groupName: groupName,
          ));

  Future<String?> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final newToken = await _wrapAsync(() => _db.changePassword(
          currentPassword: currentPassword,
          newPassword: newPassword,
        ));
    if (newToken != null) _token = newToken;
    return newToken;
  }

  // ─── Projects ─────────────────────────────────────────────────────────────

  Future<List<Project>> getProjects() => _wrapAsync(() => _db.getProjects());

  Future<Project> getProjectDetail(int projectId) =>
      _wrapAsync(() => _db.getProjectDetail(projectId));

  Future<void> applyToProject(int projectId) =>
      _wrapAsync(() => _db.applyToProject(projectId));

  // ─── Applications ─────────────────────────────────────────────────────────

  Future<List<Request>> getMyApplications() =>
      _wrapAsync(() => _db.getMyApplications());

  // ─── Goal ─────────────────────────────────────────────────────────────────

  Future<VolunteerGoal> getGoal() => _wrapAsync(() => _db.getGoal());

  Future<VolunteerGoal> setGoal({int? targetHours}) =>
      _wrapAsync(() => _db.setGoal(targetHours: targetHours));

  // ─── Leaderboard ──────────────────────────────────────────────────────────

  Future<List<LeaderboardEntry>> getLeaderboard() =>
      _wrapAsync(() => _db.getLeaderboard());

  // ─── Participants (premium) ────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getParticipants(int projectId) =>
      _wrapAsync(() => _db.getParticipants(projectId));

  // ─── Reviews ──────────────────────────────────────────────────────────────

  Future<void> submitReview({
    required int requestId,
    required int rating,
    required String comment,
  }) =>
      _wrapAsync(() => _db.submitReview(
            requestId: requestId,
            rating: rating,
            comment: comment,
          ));

  // ─── Chat ─────────────────────────────────────────────────────────────────

  Future<List<ChatPreview>> getChatUsers() =>
      _wrapAsync(() => _db.getChatUsers());

  Future<({List<Message> messages, ChatPartner partner})> getChatMessages(
    String username,
  ) =>
      _wrapAsync(() => _db.getChatMessages(username));

  Future<Message> sendMessage({
    required String recipientUsername,
    required String content,
  }) =>
      _wrapAsync(() => _db.sendMessage(
            recipientUsername: recipientUsername,
            content: content,
          ));

  // ─── Organizer ────────────────────────────────────────────────────────────

  Future<List<Project>> getOrganizerProjects() =>
      _wrapAsync(() => _db.getOrganizerProjects());

  Future<Project> createProject({
    required String name,
    required String description,
    required String location,
    required DateTime date,
    required int hours,
    required int maxVolunteers,
    double price = 0,
  }) =>
      _wrapAsync(() => _db.createProject(
            name: name,
            description: description,
            location: location,
            date: date,
            hours: hours,
            maxVolunteers: maxVolunteers,
            price: price,
          ));

  Future<List<Map<String, dynamic>>> getProjectApplications(int projectId) =>
      _wrapAsync(() => _db.getProjectApplications(projectId));

  Future<void> updateApplicationStatus({
    required int requestId,
    required String status,
    int? approvedHours,
    String? report,
    bool? starRating,
  }) =>
      _wrapAsync(() => _db.updateApplicationStatus(
            requestId: requestId,
            status: status,
            approvedHours: approvedHours,
            report: report,
            starRating: starRating,
          ));

  // ─── Subscriptions / purchase ─────────────────────────────────────────────

  Future<Subscriptions> getSubscriptions() =>
      _wrapAsync(() => _db.getSubscriptions());

  Future<Map<String, dynamic>> purchase({
    required String planType,
    int? projectId,
    required String cardNumber,
    required String cardholder,
    required String expiry,
    required String cvv,
  }) =>
      _wrapAsync(() => _db.purchase(
            planType: planType,
            projectId: projectId,
            cardNumber: cardNumber,
            cardholder: cardholder,
            expiry: expiry,
            cvv: cvv,
          ));
}
