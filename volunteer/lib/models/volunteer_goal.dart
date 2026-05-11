class VolunteerGoal {
  final int targetHours;
  final int currentHours;
  final bool completed;
  final bool hasGoal;
  final double progressPercentage;

  const VolunteerGoal({
    required this.targetHours,
    required this.currentHours,
    required this.completed,
    required this.hasGoal,
    required this.progressPercentage,
  });

  factory VolunteerGoal.fromJson(Map<String, dynamic> json) {
    final target = (json['target_hours'] as int?) ?? 0;
    final current = (json['current_hours'] as int?) ?? 0;
    final p = (json['progress_percentage'] as num?)?.toDouble();
    return VolunteerGoal(
      targetHours: target,
      currentHours: current,
      completed: json['completed'] as bool? ?? (target > 0 && current >= target),
      hasGoal: json['has_goal'] as bool? ?? false,
      progressPercentage: p ??
          (target == 0 ? 100.0 : (current / target * 100.0).clamp(0.0, 100.0)),
    );
  }
}
