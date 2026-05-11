// Request model: a volunteer's application/participation in a project.
class Request {
  final int id;
  final int projectId;
  final String projectName;
  final DateTime? projectDate;
  final int? projectHours;
  final String? projectLocation;
  final String status; // 'pending', 'approved', 'completed', 'rejected'
  final DateTime dateRequested;
  final int? approvedHours;
  final String? organizerReport;
  final bool starRating;
  final bool canReview;

  Request({
    required this.id,
    required this.projectId,
    required this.projectName,
    required this.status,
    required this.dateRequested,
    this.projectDate,
    this.projectHours,
    this.projectLocation,
    this.approvedHours,
    this.organizerReport,
    this.starRating = false,
    this.canReview = false,
  });

  bool get isPending => status == 'pending';
  bool get isApproved => status == 'approved';
  bool get isCompleted => status == 'completed';
  bool get isRejected => status == 'rejected';

  factory Request.fromJson(Map<String, dynamic> json) {
    return Request(
      id: json['id'] as int,
      projectId: json['project_id'] as int,
      projectName: json['project_name'] as String? ?? '',
      projectDate: json['project_date'] != null
          ? DateTime.parse(json['project_date'] as String)
          : null,
      projectHours: json['project_hours'] as int?,
      projectLocation: json['project_location'] as String?,
      status: json['status'] as String? ?? 'pending',
      dateRequested: json['date'] != null
          ? DateTime.parse(json['date'] as String)
          : DateTime.now(),
      approvedHours: json['approved_hours'] as int?,
      organizerReport: json['organizer_report'] as String?,
      starRating: json['star_rating'] as bool? ?? false,
      canReview: json['can_review'] as bool? ?? false,
    );
  }
}
