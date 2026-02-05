import 'dart:convert';

/// Model class for a traffic violation report
class TrafficReport {
  final String? id;
  final String title;
  final String description;
  final DateTime dateTime;
  final List<String> roadUsages;
  final List<String> eventTypes;
  final String state;
  final String city;
  final String injuries;
  final bool retainMediaMetadata; // Whether to keep GPS/date data from media files
  final List<MediaFile> mediaFiles;
  final DateTime? createdAt;
  final ReportStatus status;
  final String? reviewReason;
  final int? priority; // 1-5, where 1 is highest priority (only for approved reports)

  TrafficReport({
    this.id,
    required this.title,
    required this.description,
    required this.dateTime,
    this.roadUsages = const [],
    this.eventTypes = const [],
    required this.state,
    this.city = '',
    required this.injuries,
    this.retainMediaMetadata = true,
    this.mediaFiles = const [],
    this.createdAt,
    this.status = ReportStatus.draft,
    this.reviewReason,
    this.priority,
  });

  /// Convert to JSON for API submission
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'dateTime': dateTime.toIso8601String(),
      'roadUsages': roadUsages,
      'eventTypes': eventTypes,
      'state': state,
      'city': city,
      'injuries': injuries,
      'retainMediaMetadata': retainMediaMetadata,
      'mediaFiles': mediaFiles.map((f) => f.toJson()).toList(),
      'createdAt': createdAt?.toIso8601String(),
      'status': status.toJsonValue(),
      if (reviewReason != null) 'reviewReason': reviewReason,
      if (priority != null) 'priority': priority,
    };
  }

  /// Create from JSON response
  factory TrafficReport.fromJson(Map<String, dynamic> json) {
    return TrafficReport(
      id: json['id'] as String?,
      title: json['title'] as String,
      description: json['description'] as String,
      dateTime: DateTime.parse(json['dateTime'] as String),
      roadUsages: (json['roadUsages'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      eventTypes: (json['eventTypes'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      state: json['state'] as String,
      city: json['city'] as String? ?? '',
      injuries: json['injuries'] as String,
      retainMediaMetadata: json['retainMediaMetadata'] as bool? ?? true,
      mediaFiles: (json['mediaFiles'] as List<dynamic>?)
              ?.map((f) => MediaFile.fromJson(f as Map<String, dynamic>))
              .toList() ??
          [],
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : null,
      status: ReportStatusExtension.fromJsonValue(json['status'] as String?),
      reviewReason: json['reviewReason'] as String?,
      priority: json['priority'] as int?,
    );
  }

  /// Create a copy with updated fields
  TrafficReport copyWith({
    String? id,
    String? title,
    String? description,
    DateTime? dateTime,
    List<String>? roadUsages,
    List<String>? eventTypes,
    String? state,
    String? city,
    String? injuries,
    bool? retainMediaMetadata,
    List<MediaFile>? mediaFiles,
    DateTime? createdAt,
    ReportStatus? status,
    String? reviewReason,
    int? priority,
  }) {
    return TrafficReport(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      dateTime: dateTime ?? this.dateTime,
      roadUsages: roadUsages ?? this.roadUsages,
      eventTypes: eventTypes ?? this.eventTypes,
      state: state ?? this.state,
      city: city ?? this.city,
      injuries: injuries ?? this.injuries,
      retainMediaMetadata: retainMediaMetadata ?? this.retainMediaMetadata,
      mediaFiles: mediaFiles ?? this.mediaFiles,
      createdAt: createdAt ?? this.createdAt,
      status: status ?? this.status,
      reviewReason: reviewReason ?? this.reviewReason,
      priority: priority ?? this.priority,
    );
  }

  /// Encode to JSON string
  String encode() => jsonEncode(toJson());

  /// Decode from JSON string
  static TrafficReport decode(String source) =>
      TrafficReport.fromJson(jsonDecode(source) as Map<String, dynamic>);

  @override
  String toString() {
    return 'TrafficReport(id: $id, title: $title, eventTypes: $eventTypes, status: $status)';
  }

  /// Get the first available GPS coordinates from media files
  /// Returns null if no media has GPS data or retainMediaMetadata is false
  ({double latitude, double longitude})? get gpsCoordinates {
    if (!retainMediaMetadata) return null;

    for (final media in mediaFiles) {
      if (media.hasGpsCoordinates) {
        return (latitude: media.gpsLatitude!, longitude: media.gpsLongitude!);
      }
    }
    return null;
  }

  /// Check if this report has GPS coordinates available
  bool get hasGpsCoordinates => gpsCoordinates != null;
}

/// Media file attachment
class MediaFile {
  final String? id;
  final String name;
  final String path;
  final MediaType type;
  final int size;
  final String? url;
  final String? contentType;
  final Map<String, dynamic>? metadata; // EXIF/video metadata including GPS

  MediaFile({
    this.id,
    required this.name,
    this.path = '',
    required this.type,
    required this.size,
    this.url,
    this.contentType,
    this.metadata,
  });

  /// Get GPS latitude from metadata if available
  double? get gpsLatitude {
    if (metadata == null) return null;
    final lat = metadata!['gps_latitude'];
    if (lat is num) return lat.toDouble();
    return null;
  }

  /// Get GPS longitude from metadata if available
  double? get gpsLongitude {
    if (metadata == null) return null;
    final lon = metadata!['gps_longitude'];
    if (lon is num) return lon.toDouble();
    return null;
  }

  /// Check if this media file has GPS coordinates
  bool get hasGpsCoordinates => gpsLatitude != null && gpsLongitude != null;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'fileName': name,
      'contentType': contentType ?? (type == MediaType.video ? 'video/mp4' : 'image/jpeg'),
      'size': size,
      'url': url,
      if (metadata != null) 'metadata': metadata,
    };
  }

  factory MediaFile.fromJson(Map<String, dynamic> json) {
    // Handle both backend format (fileName/contentType) and local format (name/type)
    final fileName = json['fileName'] as String? ?? json['name'] as String? ?? '';
    final contentType = json['contentType'] as String? ?? '';

    return MediaFile(
      id: json['id'] as String?,
      name: fileName,
      path: json['path'] as String? ?? '',
      type: _detectMediaType(contentType, fileName),
      size: (json['size'] as num?)?.toInt() ?? 0,
      url: json['url'] as String?,
      contentType: contentType,
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }

  static MediaType _detectMediaType(String contentType, String fileName) {
    if (contentType.startsWith('video/')) return MediaType.video;
    if (contentType.startsWith('image/')) return MediaType.image;
    final lower = fileName.toLowerCase();
    if (lower.endsWith('.mp4') || lower.endsWith('.mov') || lower.endsWith('.avi')) {
      return MediaType.video;
    }
    return MediaType.image;
  }

  /// Check if this is a video file
  bool get isVideo => type == MediaType.video;

  /// Check if this is an image file
  bool get isImage => type == MediaType.image;

  /// Get file size in human-readable format
  String get formattedSize {
    if (size < 1024) return '$size B';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(1)} KB';
    if (size < 1024 * 1024 * 1024) {
      return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(size / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}

/// Types of media files
enum MediaType {
  image,
  video,
}

/// Report submission status
enum ReportStatus {
  draft,           // Local only
  submitting,      // In progress
  submitted,       // Awaiting review
  failed,          // Submission failed
  reviewedPass,    // Admin approved
  reviewedFail,    // Admin rejected
}

extension ReportStatusExtension on ReportStatus {
  String get displayName {
    switch (this) {
      case ReportStatus.draft:
        return 'Draft';
      case ReportStatus.submitting:
        return 'Submitting...';
      case ReportStatus.submitted:
        return 'Pending Review';
      case ReportStatus.failed:
        return 'Failed';
      case ReportStatus.reviewedPass:
        return 'Approved';
      case ReportStatus.reviewedFail:
        return 'Rejected';
    }
  }

  String get icon {
    switch (this) {
      case ReportStatus.draft:
        return 'edit';
      case ReportStatus.submitting:
        return 'sync';
      case ReportStatus.submitted:
        return 'hourglass_empty';
      case ReportStatus.failed:
        return 'error';
      case ReportStatus.reviewedPass:
        return 'verified';
      case ReportStatus.reviewedFail:
        return 'cancel';
    }
  }

  /// Convert to backend JSON value
  String toJsonValue() {
    switch (this) {
      case ReportStatus.draft:
        return 'draft';
      case ReportStatus.submitting:
        return 'submitting';
      case ReportStatus.submitted:
        return 'submitted';
      case ReportStatus.failed:
        return 'failed';
      case ReportStatus.reviewedPass:
        return 'reviewed_pass';
      case ReportStatus.reviewedFail:
        return 'reviewed_fail';
    }
  }

  /// Parse from backend JSON value
  static ReportStatus fromJsonValue(String? value) {
    switch (value) {
      case 'submitted':
        return ReportStatus.submitted;
      case 'reviewed_pass':
        return ReportStatus.reviewedPass;
      case 'reviewed_fail':
        return ReportStatus.reviewedFail;
      case 'submitting':
        return ReportStatus.submitting;
      case 'failed':
        return ReportStatus.failed;
      default:
        return ReportStatus.draft;
    }
  }
}

/// Reaction types for reports
enum ReactionType {
  thumbsUp,
  thumbsDown,
  angryCar,
  angryPedestrian,
  angryBicycle,
}

extension ReactionTypeExtension on ReactionType {
  String get apiValue {
    switch (this) {
      case ReactionType.thumbsUp:
        return 'thumbs_up';
      case ReactionType.thumbsDown:
        return 'thumbs_down';
      case ReactionType.angryCar:
        return 'angry_car';
      case ReactionType.angryPedestrian:
        return 'angry_pedestrian';
      case ReactionType.angryBicycle:
        return 'angry_bicycle';
    }
  }

  static ReactionType fromApiValue(String value) {
    switch (value) {
      case 'thumbs_up':
        return ReactionType.thumbsUp;
      case 'thumbs_down':
        return ReactionType.thumbsDown;
      case 'angry_car':
        return ReactionType.angryCar;
      case 'angry_pedestrian':
        return ReactionType.angryPedestrian;
      case 'angry_bicycle':
        return ReactionType.angryBicycle;
      default:
        return ReactionType.thumbsUp;
    }
  }
}

/// Reaction count for a specific type
class ReactionCount {
  final ReactionType type;
  final int count;

  ReactionCount({required this.type, required this.count});

  factory ReactionCount.fromJson(Map<String, dynamic> json) {
    return ReactionCount(
      type: ReactionTypeExtension.fromApiValue(json['reactionType'] as String),
      count: json['count'] as int,
    );
  }
}

/// Comment on a report
class Comment {
  final String id;
  final String reportId;
  final String userId;
  final String userEmail;
  final String content;
  final DateTime createdAt;
  final DateTime updatedAt;

  Comment({
    required this.id,
    required this.reportId,
    required this.userId,
    required this.userEmail,
    required this.content,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Comment.fromJson(Map<String, dynamic> json) {
    return Comment(
      id: json['id'] as String,
      reportId: json['reportId'] as String,
      userId: json['userId'] as String,
      userEmail: json['userEmail'] as String,
      content: json['content'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }

  /// Get a display name from email (part before @)
  String get displayName {
    final atIndex = userEmail.indexOf('@');
    return atIndex > 0 ? userEmail.substring(0, atIndex) : userEmail;
  }
}

/// Engagement data for a report (reactions and comments)
class ReportEngagement {
  final String reportId;
  final Map<ReactionType, int> reactionCounts;
  final Set<ReactionType> userReactions;
  final int commentCount;
  final List<Comment> comments;

  ReportEngagement({
    required this.reportId,
    required this.reactionCounts,
    required this.userReactions,
    required this.commentCount,
    this.comments = const [],
  });

  factory ReportEngagement.fromJson(Map<String, dynamic> json) {
    final reactionCounts = <ReactionType, int>{};
    final countsJson = json['reactionCounts'] as List<dynamic>? ?? [];
    for (final countJson in countsJson) {
      final rc = ReactionCount.fromJson(countJson as Map<String, dynamic>);
      reactionCounts[rc.type] = rc.count;
    }

    final userReactionsJson = json['userReactions'] as List<dynamic>? ?? [];
    final userReactions = userReactionsJson
        .map((r) => ReactionTypeExtension.fromApiValue(r as String))
        .toSet();

    final commentsJson = json['comments'] as List<dynamic>? ?? [];
    final comments = commentsJson
        .map((c) => Comment.fromJson(c as Map<String, dynamic>))
        .toList();

    return ReportEngagement(
      reportId: json['reportId'] as String,
      reactionCounts: reactionCounts,
      userReactions: userReactions,
      commentCount: json['commentCount'] as int? ?? 0,
      comments: comments,
    );
  }

  /// Get count for a specific reaction type
  int getCount(ReactionType type) => reactionCounts[type] ?? 0;

  /// Check if user has made a specific reaction
  bool hasUserReacted(ReactionType type) => userReactions.contains(type);

  /// Get total reaction count
  int get totalReactions =>
      reactionCounts.values.fold(0, (sum, count) => sum + count);
}
