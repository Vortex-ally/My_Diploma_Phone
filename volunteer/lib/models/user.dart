// User model matching Django User + UserProfile
class User {
  final int id;
  final String username;
  final String email;
  final String? firstName;
  final String? lastName;
  final String role; // 'volunteer', 'organiser', 'admin'
  final String? groupName;
  final DateTime? dateJoined;

  User({
    required this.id,
    required this.username,
    required this.email,
    this.firstName,
    this.lastName,
    required this.role,
    this.groupName,
    this.dateJoined,
  });

  String get displayName {
    final fn = firstName?.trim();
    if (fn != null && fn.isNotEmpty) {
      final ln = lastName?.trim();
      return ln != null && ln.isNotEmpty ? '$fn $ln' : fn;
    }
    return username;
  }

  String get initials {
    final source = displayName.trim();
    if (source.isEmpty) return '?';
    return source[0].toUpperCase();
  }

  User copyWith({
    String? firstName,
    String? lastName,
    String? groupName,
    String? email,
  }) {
    return User(
      id: id,
      username: username,
      email: email ?? this.email,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      role: role,
      groupName: groupName ?? this.groupName,
      dateJoined: dateJoined,
    );
  }

  factory User.fromJson(Map<String, dynamic> json) {
    final email = (json['email'] as String?) ?? '';
    return User(
      id: json['id'] as int,
      username: (json['username'] as String?) ??
          (email.contains('@') ? email.split('@')[0] : email),
      email: email,
      firstName: json['first_name'] as String?,
      lastName: json['last_name'] as String?,
      role: (json['role'] as String?) ?? 'volunteer',
      groupName: json['group_name'] as String?,
      dateJoined: json['date_joined'] != null
          ? DateTime.tryParse(json['date_joined'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'email': email,
      'first_name': firstName,
      'last_name': lastName,
      'role': role,
      'group_name': groupName,
      'date_joined': dateJoined?.toIso8601String(),
    };
  }
}

class ProfileStats {
  final int totalEvents;
  final int totalHours;
  final int starCount;

  const ProfileStats({
    required this.totalEvents,
    required this.totalHours,
    required this.starCount,
  });

  factory ProfileStats.fromJson(Map<String, dynamic> json) {
    return ProfileStats(
      totalEvents: json['total_events'] as int? ?? 0,
      totalHours: json['total_hours'] as int? ?? 0,
      starCount: json['star_count'] as int? ?? 0,
    );
  }
}
