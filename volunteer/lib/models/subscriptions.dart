class Subscriptions {
  final List<String> activePlans;
  final bool hasPremium;
  final bool hasAnalytics;
  final Set<int> priorityEventIds;

  const Subscriptions({
    required this.activePlans,
    required this.hasPremium,
    required this.hasAnalytics,
    required this.priorityEventIds,
  });

  static const empty = Subscriptions(
    activePlans: [],
    hasPremium: false,
    hasAnalytics: false,
    priorityEventIds: <int>{},
  );

  bool hasPriorityFor(int projectId) => priorityEventIds.contains(projectId);

  factory Subscriptions.fromJson(Map<String, dynamic> json) {
    return Subscriptions(
      activePlans: ((json['active_plans'] as List?) ?? const [])
          .map((e) => e.toString())
          .toList(),
      hasPremium: json['has_premium'] as bool? ?? false,
      hasAnalytics: json['has_analytics'] as bool? ?? false,
      priorityEventIds: ((json['priority_event_ids'] as List?) ?? const [])
          .map((e) => e as int)
          .toSet(),
    );
  }
}
