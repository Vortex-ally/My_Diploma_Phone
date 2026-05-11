// Project model matching Django Project
class Project {
  final int id;
  final String name;
  final String? description;
  final String? location;
  final int organiserId;
  final String organiserName;
  final DateTime? date;
  final int hours;
  final int maxVolunteers;
  final int currentVolunteers;
  final String status; // 'apply', 'approved', 'pending', 'rejected'
  final double price;
  final String? applicationStatus; // current user's request status, if any
  final bool hasPriority;

  Project({
    required this.id,
    required this.name,
    this.description,
    this.location,
    required this.organiserId,
    required this.organiserName,
    this.date,
    required this.hours,
    required this.maxVolunteers,
    required this.currentVolunteers,
    required this.status,
    this.price = 0,
    this.applicationStatus,
    this.hasPriority = false,
  });

  bool get isFull => maxVolunteers > 0 && currentVolunteers >= maxVolunteers;
  bool get hasApplied => applicationStatus != null;
  bool get canApply => !hasApplied && !isFull;

  factory Project.fromJson(Map<String, dynamic> json) {
    return Project(
      id: json['id'] as int,
      name: json['name'] as String? ?? '',
      description: json['description'] as String?,
      location: json['location'] as String?,
      organiserId: json['organiser_id'] as int,
      organiserName: json['organiser_name'] as String? ?? '',
      date: json['date'] != null ? DateTime.parse(json['date'] as String) : null,
      hours: (json['hours'] as int?) ?? 0,
      maxVolunteers: (json['max_volunteers'] as int?) ?? 0,
      currentVolunteers: (json['current_volunteers'] as int?) ?? 0,
      status: json['status'] as String? ?? 'apply',
      price: (json['price'] as num?)?.toDouble() ?? 0,
      applicationStatus: json['application_status'] as String?,
      hasPriority: json['has_priority'] as bool? ?? false,
    );
  }
}
