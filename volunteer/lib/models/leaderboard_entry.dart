class LeaderboardEntry {
  final int rank;
  final int id;
  final String name;
  final String? groupName;
  final int totalHours;
  final bool isMe;

  const LeaderboardEntry({
    required this.rank,
    required this.id,
    required this.name,
    required this.totalHours,
    required this.isMe,
    this.groupName,
  });

  factory LeaderboardEntry.fromJson(Map<String, dynamic> json) {
    return LeaderboardEntry(
      rank: json['rank'] as int? ?? 0,
      id: json['id'] as int,
      name: json['name'] as String? ?? '',
      groupName: json['group_name'] as String?,
      totalHours: json['total_hours'] as int? ?? 0,
      isMe: json['is_me'] as bool? ?? false,
    );
  }
}
