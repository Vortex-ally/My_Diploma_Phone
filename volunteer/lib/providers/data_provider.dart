import 'package:flutter/foundation.dart';
import '../models/leaderboard_entry.dart';
import '../models/message.dart';
import '../models/project.dart';
import '../models/request.dart';
import '../models/subscriptions.dart';
import '../models/volunteer_goal.dart';
import '../services/api_service.dart';

class DataProvider with ChangeNotifier {
  final ApiService _api;

  List<Project> _projects = [];
  List<Request> _myApplications = [];
  List<LeaderboardEntry> _leaderboard = [];
  List<ChatPreview> _chatUsers = [];
  VolunteerGoal? _goal;
  Subscriptions _subscriptions = Subscriptions.empty;
  final Map<int, List<Map<String, dynamic>>> _participants = {};

  bool _isLoading = false;
  String? _error;

  DataProvider(this._api);

  List<Project> get projects => _projects;
  List<Request> get myApplications => _myApplications;
  List<LeaderboardEntry> get leaderboard => _leaderboard;
  List<ChatPreview> get chatUsers => _chatUsers;
  VolunteerGoal? get goal => _goal;
  Subscriptions get subscriptions => _subscriptions;
  Map<int, List<Map<String, dynamic>>> get participantsCache => _participants;
  bool get isLoading => _isLoading;
  String? get error => _error;

  void clearError() {
    _error = null;
    notifyListeners();
  }

  void reset() {
    _projects = [];
    _myApplications = [];
    _leaderboard = [];
    _chatUsers = [];
    _goal = null;
    _subscriptions = Subscriptions.empty;
    _participants.clear();
    _error = null;
    _isLoading = false;
    notifyListeners();
  }

  Future<List<Map<String, dynamic>>?> fetchParticipants(int projectId) async {
    try {
      final list = await _api.getParticipants(projectId);
      _participants[projectId] = list;
      notifyListeners();
      return list;
    } catch (e) {
      _error = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
      return null;
    }
  }

  Future<void> loadDashboard() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final results = await Future.wait([
        _api.getProjects(),
        _api.getMyApplications(),
        _api.getGoal(),
        _api.getSubscriptions(),
      ]);
      _projects = results[0] as List<Project>;
      _myApplications = results[1] as List<Request>;
      _goal = results[2] as VolunteerGoal;
      _subscriptions = results[3] as Subscriptions;
    } catch (e) {
      _error = e.toString().replaceAll('Exception: ', '');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchProjects() async {
    try {
      _projects = await _api.getProjects();
      _error = null;
    } catch (e) {
      _error = e.toString().replaceAll('Exception: ', '');
    } finally {
      notifyListeners();
    }
  }

  Future<Project?> fetchProjectDetail(int projectId) async {
    try {
      final project = await _api.getProjectDetail(projectId);
      final idx = _projects.indexWhere((p) => p.id == projectId);
      if (idx >= 0) {
        _projects[idx] = project;
        notifyListeners();
      }
      return project;
    } catch (e) {
      _error = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
      return null;
    }
  }

  Future<bool> applyToProject(int projectId) async {
    try {
      await _api.applyToProject(projectId);
      await Future.wait([fetchProjects(), fetchMyApplications()]);
      return true;
    } catch (e) {
      _error = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  Future<void> fetchMyApplications() async {
    try {
      _myApplications = await _api.getMyApplications();
      _error = null;
    } catch (e) {
      _error = e.toString().replaceAll('Exception: ', '');
    } finally {
      notifyListeners();
    }
  }

  Future<void> fetchGoal() async {
    try {
      _goal = await _api.getGoal();
      _error = null;
    } catch (e) {
      _error = e.toString().replaceAll('Exception: ', '');
    } finally {
      notifyListeners();
    }
  }

  Future<bool> setGoal({int? targetHours}) async {
    try {
      _goal = await _api.setGoal(targetHours: targetHours);
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  Future<void> fetchLeaderboard() async {
    try {
      _leaderboard = await _api.getLeaderboard();
      _error = null;
    } catch (e) {
      _error = e.toString().replaceAll('Exception: ', '');
    } finally {
      notifyListeners();
    }
  }

  Future<void> fetchChatUsers() async {
    try {
      _chatUsers = await _api.getChatUsers();
      _error = null;
    } catch (e) {
      _error = e.toString().replaceAll('Exception: ', '');
    } finally {
      notifyListeners();
    }
  }

  Future<bool> submitReview({
    required int requestId,
    required int rating,
    required String comment,
  }) async {
    try {
      await _api.submitReview(
        requestId: requestId,
        rating: rating,
        comment: comment,
      );
      await fetchMyApplications();
      return true;
    } catch (e) {
      _error = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  Future<void> fetchSubscriptions() async {
    try {
      _subscriptions = await _api.getSubscriptions();
      notifyListeners();
    } catch (_) {}
  }

  Future<bool> purchase({
    required String planType,
    int? projectId,
    required String cardNumber,
    required String cardholder,
    required String expiry,
    required String cvv,
  }) async {
    try {
      await _api.purchase(
        planType: planType,
        projectId: projectId,
        cardNumber: cardNumber,
        cardholder: cardholder,
        expiry: expiry,
        cvv: cvv,
      );
      await Future.wait([
        fetchSubscriptions(),
        fetchProjects(),
        fetchMyApplications(),
      ]);
      return true;
    } catch (e) {
      _error = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
      return false;
    }
  }
}
