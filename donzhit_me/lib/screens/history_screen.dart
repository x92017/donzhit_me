import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/traffic_report.dart';
import '../providers/report_provider.dart';
import '../widgets/donzhit_logo.dart';
import 'video_player_screen.dart';
import 'image_viewer_screen.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  String _searchQuery = '';
  ReportStatus? _filterStatus;
  String? _filterEventType;

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      child: Scaffold(
        body: Column(
          children: [
            // Black header with logo and title
            Container(
              padding: const EdgeInsets.only(left: 24, right: 24, bottom: 11, top: 2),
              decoration: const BoxDecoration(
                color: Colors.black,
              ),
              child: SafeArea(
                bottom: false,
                minimum: const EdgeInsets.only(top: 2),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const DonzHitLogoHorizontal(height: 62),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.filter_list, color: Colors.white),
                          onPressed: _showFilterDialog,
                          tooltip: 'Filter',
                        ),
                        IconButton(
                          icon: const Icon(Icons.refresh, color: Colors.white),
                          onPressed: () => context.read<ReportProvider>().fetchReports(),
                          tooltip: 'Refresh',
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'My Reports',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: Colors.white.withValues(alpha: 0.9),
                          ),
                    ),
                  ],
                ),
              ),
            ),
            // Content
            Expanded(
              child: Consumer<ReportProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          final filteredReports = _getFilteredReports(provider.reports);

          return Column(
            children: [
              // Search Bar
              Padding(
                padding: const EdgeInsets.all(16),
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Search reports...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              setState(() {
                                _searchQuery = '';
                              });
                            },
                          )
                        : null,
                  ),
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value;
                    });
                  },
                ),
              ),

              // Filter Chips
              if (_filterStatus != null || _filterEventType != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Wrap(
                    spacing: 8,
                    children: [
                      if (_filterStatus != null)
                        Chip(
                          label: Text(_filterStatus!.displayName),
                          onDeleted: () {
                            setState(() {
                              _filterStatus = null;
                            });
                          },
                        ),
                      if (_filterEventType != null)
                        Chip(
                          label: Text(_filterEventType!),
                          onDeleted: () {
                            setState(() {
                              _filterEventType = null;
                            });
                          },
                        ),
                    ],
                  ),
                ),

              // Reports List
              Expanded(
                child: filteredReports.isEmpty
                    ? _buildEmptyState()
                    : RefreshIndicator(
                        onRefresh: () => provider.fetchReports(),
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: filteredReports.length,
                          itemBuilder: (context, index) {
                            return _ReportListItem(
                              report: filteredReports[index],
                              onTap: () =>
                                  _showReportDetails(filteredReports[index]),
                              onDelete: () =>
                                  _deleteReport(filteredReports[index]),
                            );
                          },
                        ),
                      ),
              ),
            ],
          );
        },
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<TrafficReport> _getFilteredReports(List<TrafficReport> reports) {
    return reports.where((report) {
      // Search filter
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        final eventTypesMatch = report.eventTypes.any((e) => e.toLowerCase().contains(query));
        if (!report.title.toLowerCase().contains(query) &&
            !report.description.toLowerCase().contains(query) &&
            !eventTypesMatch) {
          return false;
        }
      }

      // Status filter
      if (_filterStatus != null && report.status != _filterStatus) {
        return false;
      }

      // Event type filter - check if any event type matches
      if (_filterEventType != null && !report.eventTypes.contains(_filterEventType)) {
        return false;
      }

      return true;
    }).toList();
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.inbox_outlined,
              size: 80,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              _searchQuery.isNotEmpty ||
                      _filterStatus != null ||
                      _filterEventType != null
                  ? 'No matching reports'
                  : 'No reports yet',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _searchQuery.isNotEmpty ||
                      _filterStatus != null ||
                      _filterEventType != null
                  ? 'Try adjusting your filters'
                  : 'Create a report to get started',
              style: TextStyle(
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showFilterDialog() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Filter Reports',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _filterStatus = null;
                        _filterEventType = null;
                      });
                      Navigator.pop(context);
                    },
                    child: const Text('Clear All'),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Status Filter
              const Text(
                'Status',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: ReportStatus.values.map((status) {
                  final isSelected = _filterStatus == status;
                  return FilterChip(
                    label: Text(status.displayName),
                    selected: isSelected,
                    onSelected: (selected) {
                      setModalState(() {
                        setState(() {
                          _filterStatus = selected ? status : null;
                        });
                      });
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),

              // Event Type Filter
              const Text(
                'Event Type',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  'Pedestrian Intersection',
                  'Red Light',
                  'Speeding',
                  'On Phone',
                  'Reckless',
                ].map((type) {
                  final isSelected = _filterEventType == type;
                  return FilterChip(
                    label: Text(type),
                    selected: isSelected,
                    onSelected: (selected) {
                      setModalState(() {
                        setState(() {
                          _filterEventType = selected ? type : null;
                        });
                      });
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Apply Filters'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showReportDetails(TrafficReport report) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.5,
        expand: false,
        builder: (context, scrollController) => SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Expanded(
                    child: Text(
                      report.title,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _getStatusColor(report.status).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      report.status.displayName,
                      style: TextStyle(
                        color: _getStatusColor(report.status),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Details
              _DetailRow(
                icon: Icons.calendar_today,
                label: 'Date/Time',
                value:
                    DateFormat('MMMM d, yyyy - h:mm a').format(report.dateTime),
              ),
              _DetailRow(
                icon: Icons.directions_car,
                label: 'Road Usage',
                value: report.roadUsages.join(', '),
              ),
              _DetailRow(
                icon: Icons.warning_amber,
                label: 'Event Type',
                value: report.eventTypes.join(', '),
              ),
              _DetailRow(
                icon: Icons.location_on,
                label: 'State/Province',
                value: report.state,
              ),
              _DetailRow(
                icon: Icons.healing,
                label: 'Injuries',
                value: report.injuries,
              ),
              const SizedBox(height: 16),

              // Description
              const Text(
                'Description',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(report.description),
              ),
              const SizedBox(height: 16),

              // Rejection Reason (for rejected reports)
              if (report.status == ReportStatus.reviewedFail &&
                  report.reviewReason != null &&
                  report.reviewReason!.isNotEmpty) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red[200]!),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.info_outline, size: 16, color: Colors.red[700]),
                          const SizedBox(width: 8),
                          Text(
                            'Rejection Reason',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Colors.red[700],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        report.reviewReason!,
                        style: TextStyle(color: Colors.red[900]),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Media Files
              if (report.mediaFiles.isNotEmpty) ...[
                const Text(
                  'Media Files',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: report.mediaFiles.map((file) {
                    return ActionChip(
                      avatar: Icon(
                        file.isVideo ? Icons.videocam : Icons.image,
                        size: 18,
                      ),
                      label: Text(file.name),
                      onPressed: () => _openMedia(file, report.mediaFiles),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
              ],

              // Actions
              if (report.status == ReportStatus.failed)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      context.read<ReportProvider>().retrySubmit(report.id!);
                    },
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry Submit'),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _openMedia(MediaFile media, List<MediaFile> allMedia) {
    debugPrint('_openMedia: name=${media.name}, path=${media.path}, url=${media.url}, isVideo=${media.isVideo}');

    if (media.isVideo) {
      // Check if this is a YouTube video
      final youtubeId = _extractYouTubeId(media.url);

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => VideoPlayerScreen(
            videoPath: youtubeId == null && media.path.isNotEmpty ? media.path : null,
            videoUrl: youtubeId == null && media.path.isEmpty ? media.url : null,
            youtubeVideoId: youtubeId,
            title: media.name,
          ),
        ),
      );
    } else {
      // Use URL for remote images, path for local images
      final imageUrls = allMedia
          .where((m) => m.isImage)
          .map((m) => m.path.isNotEmpty ? m.path : (m.url ?? ''))
          .where((url) => url.isNotEmpty)
          .toList();
      final currentImageUrl = media.path.isNotEmpty ? media.path : (media.url ?? '');
      final imageIndex = imageUrls.indexOf(currentImageUrl);

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ImageViewerScreen(
            allImages: imageUrls,
            initialIndex: imageIndex >= 0 ? imageIndex : 0,
            title: media.name,
          ),
        ),
      );
    }
  }

  void _deleteReport(TrafficReport report) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Report'),
        content: const Text(
            'Are you sure you want to delete this report? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              context.read<ReportProvider>().deleteReport(report.id!);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Report deleted')),
              );
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(ReportStatus status) {
    switch (status) {
      case ReportStatus.draft:
        return Colors.grey;
      case ReportStatus.submitting:
        return Colors.blue;
      case ReportStatus.submitted:
        return Colors.orange;  // Pending review
      case ReportStatus.failed:
        return Colors.red;
      case ReportStatus.reviewedPass:
        return Colors.green;   // Approved
      case ReportStatus.reviewedFail:
        return Colors.red[800]!;  // Rejected (dark red)
    }
  }

  /// Extract YouTube video ID from a URL
  String? _extractYouTubeId(String? url) {
    if (url == null) return null;

    // Match youtube.com/watch?v=VIDEO_ID
    final watchMatch = RegExp(r'youtube\.com/watch\?v=([a-zA-Z0-9_-]+)').firstMatch(url);
    if (watchMatch != null) return watchMatch.group(1);

    // Match youtu.be/VIDEO_ID
    final shortMatch = RegExp(r'youtu\.be/([a-zA-Z0-9_-]+)').firstMatch(url);
    if (shortMatch != null) return shortMatch.group(1);

    // Match youtube.com/embed/VIDEO_ID
    final embedMatch = RegExp(r'youtube\.com/embed/([a-zA-Z0-9_-]+)').firstMatch(url);
    if (embedMatch != null) return embedMatch.group(1);

    return null;
  }
}

class _ReportListItem extends StatelessWidget {
  final TrafficReport report;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _ReportListItem({
    required this.report,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor:
                        _getStatusColor(report.status).withValues(alpha: 0.2),
                    child: Icon(
                      _getStatusIcon(report.status),
                      color: _getStatusColor(report.status),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          report.title,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          report.eventTypes.join(', '),
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'delete') {
                        onDelete();
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete, color: Colors.red),
                            SizedBox(width: 8),
                            Text('Delete'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                report.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.grey[700],
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(
                    Icons.calendar_today,
                    size: 14,
                    color: Colors.grey[500],
                  ),
                  const SizedBox(width: 4),
                  Text(
                    DateFormat('MMM d, yyyy').format(report.dateTime),
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[500],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Icon(
                    Icons.location_on,
                    size: 14,
                    color: Colors.grey[500],
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      report.state,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[500],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (report.mediaFiles.isNotEmpty) ...[
                    Icon(
                      Icons.attach_file,
                      size: 14,
                      color: Colors.grey[500],
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${report.mediaFiles.length}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[500],
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getStatusColor(ReportStatus status) {
    switch (status) {
      case ReportStatus.draft:
        return Colors.grey;
      case ReportStatus.submitting:
        return Colors.blue;
      case ReportStatus.submitted:
        return Colors.orange;  // Pending review
      case ReportStatus.failed:
        return Colors.red;
      case ReportStatus.reviewedPass:
        return Colors.green;   // Approved
      case ReportStatus.reviewedFail:
        return Colors.red[800]!;  // Rejected (dark red)
    }
  }

  IconData _getStatusIcon(ReportStatus status) {
    switch (status) {
      case ReportStatus.draft:
        return Icons.edit_note;
      case ReportStatus.submitting:
        return Icons.sync;
      case ReportStatus.submitted:
        return Icons.hourglass_empty;  // Pending review
      case ReportStatus.failed:
        return Icons.error;
      case ReportStatus.reviewedPass:
        return Icons.verified;  // Approved
      case ReportStatus.reviewedFail:
        return Icons.cancel;  // Rejected
    }
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Colors.grey[600]),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[500],
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
