import 'dart:convert';

/// Model class for a traffic violation report
class TrafficReport {
  final String? id;
  final String title;
  final String description;
  final DateTime dateTime;
  final String roadUsage;
  final String eventType;
  final String state;
  final String injuries;
  final List<MediaFile> mediaFiles;
  final DateTime? createdAt;
  final ReportStatus status;

  TrafficReport({
    this.id,
    required this.title,
    required this.description,
    required this.dateTime,
    required this.roadUsage,
    required this.eventType,
    required this.state,
    required this.injuries,
    this.mediaFiles = const [],
    this.createdAt,
    this.status = ReportStatus.draft,
  });

  /// Convert to JSON for API submission
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'dateTime': dateTime.toIso8601String(),
      'roadUsage': roadUsage,
      'eventType': eventType,
      'state': state,
      'injuries': injuries,
      'mediaFiles': mediaFiles.map((f) => f.toJson()).toList(),
      'createdAt': createdAt?.toIso8601String(),
      'status': status.name,
    };
  }

  /// Create from JSON response
  factory TrafficReport.fromJson(Map<String, dynamic> json) {
    return TrafficReport(
      id: json['id'] as String?,
      title: json['title'] as String,
      description: json['description'] as String,
      dateTime: DateTime.parse(json['dateTime'] as String),
      roadUsage: json['roadUsage'] as String,
      eventType: json['eventType'] as String,
      state: json['state'] as String,
      injuries: json['injuries'] as String,
      mediaFiles: (json['mediaFiles'] as List<dynamic>?)
              ?.map((f) => MediaFile.fromJson(f as Map<String, dynamic>))
              .toList() ??
          [],
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : null,
      status: ReportStatus.values.firstWhere(
        (s) => s.name == json['status'],
        orElse: () => ReportStatus.draft,
      ),
    );
  }

  /// Create a copy with updated fields
  TrafficReport copyWith({
    String? id,
    String? title,
    String? description,
    DateTime? dateTime,
    String? roadUsage,
    String? eventType,
    String? state,
    String? injuries,
    List<MediaFile>? mediaFiles,
    DateTime? createdAt,
    ReportStatus? status,
  }) {
    return TrafficReport(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      dateTime: dateTime ?? this.dateTime,
      roadUsage: roadUsage ?? this.roadUsage,
      eventType: eventType ?? this.eventType,
      state: state ?? this.state,
      injuries: injuries ?? this.injuries,
      mediaFiles: mediaFiles ?? this.mediaFiles,
      createdAt: createdAt ?? this.createdAt,
      status: status ?? this.status,
    );
  }

  /// Encode to JSON string
  String encode() => jsonEncode(toJson());

  /// Decode from JSON string
  static TrafficReport decode(String source) =>
      TrafficReport.fromJson(jsonDecode(source) as Map<String, dynamic>);

  @override
  String toString() {
    return 'TrafficReport(id: $id, title: $title, eventType: $eventType, status: $status)';
  }
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

  MediaFile({
    this.id,
    required this.name,
    this.path = '',
    required this.type,
    required this.size,
    this.url,
    this.contentType,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'fileName': name,
      'contentType': contentType ?? (type == MediaType.video ? 'video/mp4' : 'image/jpeg'),
      'size': size,
      'url': url,
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
  draft,
  submitting,
  submitted,
  failed,
  reviewed,
}

extension ReportStatusExtension on ReportStatus {
  String get displayName {
    switch (this) {
      case ReportStatus.draft:
        return 'Draft';
      case ReportStatus.submitting:
        return 'Submitting...';
      case ReportStatus.submitted:
        return 'Submitted';
      case ReportStatus.failed:
        return 'Failed';
      case ReportStatus.reviewed:
        return 'Reviewed';
    }
  }

  String get icon {
    switch (this) {
      case ReportStatus.draft:
        return 'edit';
      case ReportStatus.submitting:
        return 'sync';
      case ReportStatus.submitted:
        return 'check_circle';
      case ReportStatus.failed:
        return 'error';
      case ReportStatus.reviewed:
        return 'verified';
    }
  }
}
