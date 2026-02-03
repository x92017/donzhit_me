import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/report_provider.dart';
import '../models/traffic_report.dart';
import '../services/api_service.dart';
import 'video_player_screen.dart';
import 'image_viewer_screen.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  final ApiService _apiService = ApiService();
  bool _isSigningIn = false;

  @override
  void initState() {
    super.initState();
    _apiService.initialize();
    // Fetch admin data if user is admin
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_apiService.isAdmin) {
        _fetchAdminData();
      }
    });
    _apiService.addAuthStateListener(_onAuthStateChanged);
  }

  @override
  void dispose() {
    _apiService.removeAuthStateListener(_onAuthStateChanged);
    super.dispose();
  }

  void _onAuthStateChanged() {
    if (mounted) {
      setState(() {});
      if (_apiService.isAdmin) {
        _fetchAdminData();
      }
    }
  }

  Future<void> _fetchAdminData() async {
    final provider = context.read<ReportProvider>();
    await Future.wait([
      provider.fetchAllReportsAdmin(),
      provider.fetchReviewQueue(),
    ]);
  }

  Future<void> _handleSignIn() async {
    setState(() => _isSigningIn = true);
    try {
      await _apiService.signIn();
    } finally {
      setState(() => _isSigningIn = false);
    }
  }

  Future<void> _handleSignOut() async {
    await _apiService.signOut();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = _apiService.isAdmin;

    return Scaffold(
      body: Consumer<ReportProvider>(
        builder: (context, provider, child) {
          return RefreshIndicator(
            onRefresh: () async {
              if (isAdmin) {
                await _fetchAdminData();
              }
              await provider.fetchReports();
            },
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: _buildHeader(context),
                ),
                SliverToBoxAdapter(
                  child: _buildStatistics(context, provider),
                ),
                if (isAdmin) ...[
                  SliverToBoxAdapter(
                    child: _buildReviewQueue(context, provider),
                  ),
                ] else ...[
                  SliverToBoxAdapter(
                    child: _buildQuickActions(context),
                  ),
                  SliverToBoxAdapter(
                    child: _buildRecentReports(context, provider),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Colors.black,
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.admin_panel_settings,
                  color: Colors.white,
                  size: 40,
                ),
                const SizedBox(width: 12),
                Text(
                  'Admin Dashboard',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const Spacer(),
                _buildAuthButton(),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Manage reports and system settings',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
            ),
            if (_apiService.isSignedIn) ...[
              const SizedBox(height: 8),
              Text(
                'Signed in as ${_apiService.userEmail}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.white.withValues(alpha: 0.7),
                    ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAuthButton() {
    if (_isSigningIn) {
      return const SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(
          color: Colors.white,
          strokeWidth: 2,
        ),
      );
    }

    if (_apiService.isSignedIn) {
      return IconButton(
        icon: const Icon(Icons.logout, color: Colors.white),
        onPressed: _handleSignOut,
        tooltip: 'Sign out',
      );
    }

    return ElevatedButton.icon(
      onPressed: _handleSignIn,
      icon: const Icon(Icons.login, size: 18),
      label: const Text('Sign In'),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
    );
  }

  Widget _buildStatistics(BuildContext context, ReportProvider provider) {
    final isAdmin = _apiService.isAdmin;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isAdmin ? 'System Statistics' : 'Your Activity',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  title: 'Total Reports',
                  value: isAdmin
                      ? provider.totalReportsAdmin.toString()
                      : provider.totalReports.toString(),
                  icon: Icons.description,
                  color: Colors.blue,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCard(
                  title: 'Pending Review',
                  value: isAdmin
                      ? provider.pendingReviewReportsAdmin.toString()
                      : provider.pendingReviewReports.toString(),
                  icon: Icons.hourglass_empty,
                  color: Colors.orange,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  title: 'Approved',
                  value: isAdmin
                      ? provider.approvedReportsAdmin.toString()
                      : provider.approvedReportsCount.toString(),
                  icon: Icons.verified,
                  color: Colors.green,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCard(
                  title: 'Rejected',
                  value: isAdmin
                      ? provider.rejectedReportsAdmin.toString()
                      : provider.rejectedReportsCount.toString(),
                  icon: Icons.cancel,
                  color: Colors.red,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildReviewQueue(BuildContext context, ReportProvider provider) {
    final reviewQueue = provider.reviewQueue;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Review Queue',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              if (reviewQueue.isNotEmpty)
                Chip(
                  label: Text('${reviewQueue.length} pending'),
                  backgroundColor: Colors.orange.withValues(alpha: 0.2),
                  labelStyle: const TextStyle(color: Colors.orange),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (provider.isLoading)
            const Center(child: CircularProgressIndicator())
          else if (reviewQueue.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  children: [
                    Icon(
                      Icons.check_circle_outline,
                      size: 64,
                      color: Colors.green[400],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'All caught up!',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'No reports awaiting review',
                      style: TextStyle(
                        color: Colors.grey[500],
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            ...reviewQueue.map((report) => _ReviewQueueItem(
                  report: report,
                  onApprove: () => _showReviewDialog(context, report, approve: true),
                  onReject: () => _showReviewDialog(context, report, approve: false),
                  onView: () => _showReportDetailsForReview(context, report),
                )),
        ],
      ),
    );
  }

  void _showReviewDialog(BuildContext context, TrafficReport report, {required bool approve}) {
    final reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(approve ? 'Approve Report' : 'Reject Report'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Report: ${report.title}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text('Event Type: ${report.eventType}'),
            Text('State: ${report.state}'),
            Text('Date: ${DateFormat('MMM d, yyyy').format(report.dateTime)}'),
            if (!approve) ...[
              const SizedBox(height: 16),
              TextField(
                controller: reasonController,
                decoration: const InputDecoration(
                  labelText: 'Rejection Reason (required)',
                  hintText: 'Explain why this report is being rejected...',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (!approve && reasonController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please provide a rejection reason')),
                );
                return;
              }

              Navigator.pop(context);

              final provider = context.read<ReportProvider>();
              final success = await provider.reviewReport(
                report.id!,
                approve: approve,
                reason: approve ? null : reasonController.text.trim(),
              );

              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(success
                        ? 'Report ${approve ? 'approved' : 'rejected'} successfully'
                        : 'Failed to review report'),
                    backgroundColor: success ? Colors.green : Colors.red,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: approve ? Colors.green : Colors.red,
              foregroundColor: Colors.white,
            ),
            child: Text(approve ? 'Approve' : 'Reject'),
          ),
        ],
      ),
    );
  }

  void _showReportDetailsForReview(BuildContext context, TrafficReport report) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.8,
        maxChildSize: 0.95,
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
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Text(
                      'Pending Review',
                      style: TextStyle(
                        color: Colors.orange,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Event type and location
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getEventTypeColorForReview(report.eventType),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      report.eventType,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Icon(Icons.location_on, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(report.state, style: TextStyle(color: Colors.grey[600])),
                  const SizedBox(width: 12),
                  Icon(Icons.calendar_today, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    DateFormat('MMM d, yyyy').format(report.dateTime),
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Description
              const Text(
                'Description',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
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

              // Media Files
              if (report.mediaFiles.isNotEmpty) ...[
                Text(
                  'Media Files (${report.mediaFiles.length})',
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 200,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: report.mediaFiles.length,
                    itemBuilder: (context, index) {
                      final media = report.mediaFiles[index];
                      return Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: GestureDetector(
                          onTap: () => _openMediaForReview(context, media, report),
                          child: Container(
                            width: 200,
                            decoration: BoxDecoration(
                              color: Colors.grey[200],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  if (media.url != null && media.url!.isNotEmpty && !media.isVideo)
                                    Image.network(
                                      media.url!,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => _buildMediaPlaceholder(media),
                                    )
                                  else
                                    _buildMediaPlaceholder(media),
                                  if (media.isVideo)
                                    Center(
                                      child: Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: Colors.black.withValues(alpha: 0.7),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.play_arrow,
                                          color: Colors.white,
                                          size: 32,
                                        ),
                                      ),
                                    ),
                                  Positioned(
                                    bottom: 0,
                                    left: 0,
                                    right: 0,
                                    child: Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          begin: Alignment.bottomCenter,
                                          end: Alignment.topCenter,
                                          colors: [
                                            Colors.black.withValues(alpha: 0.7),
                                            Colors.transparent,
                                          ],
                                        ),
                                      ),
                                      child: Text(
                                        media.name,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Action buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _showReviewDialog(context, report, approve: false);
                      },
                      icon: const Icon(Icons.close),
                      label: const Text('Reject'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _showReviewDialog(context, report, approve: true);
                      },
                      icon: const Icon(Icons.check),
                      label: const Text('Approve'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMediaPlaceholder(MediaFile media) {
    return Container(
      color: Colors.grey[300],
      child: Center(
        child: Icon(
          media.isVideo ? Icons.videocam : Icons.image,
          color: Colors.grey[500],
          size: 48,
        ),
      ),
    );
  }

  void _openMediaForReview(BuildContext context, MediaFile media, TrafficReport report) {
    if (media.isVideo) {
      final youtubeId = _extractYouTubeId(media.url);
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => VideoPlayerScreen(
            videoPath: youtubeId == null && media.path.isNotEmpty ? media.path : null,
            videoUrl: youtubeId == null && media.path.isEmpty ? media.url : null,
            youtubeVideoId: youtubeId,
            title: report.title,
          ),
        ),
      );
    } else {
      final imageUrls = report.mediaFiles
          .where((m) => m.isImage)
          .map((m) => m.url ?? '')
          .where((url) => url.isNotEmpty)
          .toList();
      final currentIndex = imageUrls.indexOf(media.url ?? '');

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ImageViewerScreen(
            allImages: imageUrls,
            initialIndex: currentIndex >= 0 ? currentIndex : 0,
            title: report.title,
          ),
        ),
      );
    }
  }

  String? _extractYouTubeId(String? url) {
    if (url == null) return null;
    final watchMatch = RegExp(r'youtube\.com/watch\?v=([a-zA-Z0-9_-]+)').firstMatch(url);
    if (watchMatch != null) return watchMatch.group(1);
    final shortMatch = RegExp(r'youtu\.be/([a-zA-Z0-9_-]+)').firstMatch(url);
    if (shortMatch != null) return shortMatch.group(1);
    final embedMatch = RegExp(r'youtube\.com/embed/([a-zA-Z0-9_-]+)').firstMatch(url);
    if (embedMatch != null) return embedMatch.group(1);
    return null;
  }

  Color _getEventTypeColorForReview(String eventType) {
    switch (eventType) {
      case 'Red Light':
        return Colors.red;
      case 'Speeding':
        return Colors.orange;
      case 'On Phone':
        return Colors.purple;
      case 'Reckless':
        return Colors.deepOrange;
      case 'Pedestrian Intersection':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  Widget _buildQuickActions(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Quick Actions',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _ActionButton(
                  icon: Icons.add_a_photo,
                  label: 'New Report',
                  onTap: () => _navigateToReportForm(context),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _ActionButton(
                  icon: Icons.history,
                  label: 'View History',
                  onTap: () => _navigateToHistory(context),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRecentReports(BuildContext context, ReportProvider provider) {
    final recentReports = provider.reports.take(5).toList();

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Recent Reports',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              if (provider.reports.isNotEmpty)
                TextButton(
                  onPressed: () => _navigateToHistory(context),
                  child: const Text('See All'),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (recentReports.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  children: [
                    Icon(
                      Icons.inbox_outlined,
                      size: 64,
                      color: Colors.grey[400],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No reports yet',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Create your first traffic violation report',
                      style: TextStyle(
                        color: Colors.grey[500],
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            ...recentReports.map((report) => _ReportCard(report: report)),
        ],
      ),
    );
  }

  void _navigateToReportForm(BuildContext context) {
    // Navigate using the main navigation (index 1)
    final scaffold = Scaffold.of(context);
    if (scaffold.hasDrawer) {
      Navigator.of(context).pop();
    }
    // This will be handled by the parent navigation
  }

  void _navigateToHistory(BuildContext context) {
    // Navigate using the main navigation (index 2)
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey[600],
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReportCard extends StatelessWidget {
  final TrafficReport report;

  const _ReportCard({required this.report});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _getStatusColor(report.status).withValues(alpha: 0.2),
          child: Icon(
            _getStatusIcon(report.status),
            color: _getStatusColor(report.status),
          ),
        ),
        title: Text(
          report.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              report.eventType,
              style: TextStyle(color: Colors.grey[600]),
            ),
            Text(
              _formatDate(report.dateTime),
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: 12,
              ),
            ),
          ],
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: _getStatusColor(report.status).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            report.status.displayName,
            style: TextStyle(
              color: _getStatusColor(report.status),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        isThreeLine: true,
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
        return Colors.red[800]!;  // Rejected
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

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays == 0) {
      return 'Today';
    } else if (diff.inDays == 1) {
      return 'Yesterday';
    } else if (diff.inDays < 7) {
      return '${diff.inDays} days ago';
    } else {
      return '${date.month}/${date.day}/${date.year}';
    }
  }
}

class _ReviewQueueItem extends StatelessWidget {
  final TrafficReport report;
  final VoidCallback onApprove;
  final VoidCallback onReject;
  final VoidCallback onView;

  const _ReviewQueueItem({
    required this.report,
    required this.onApprove,
    required this.onReject,
    required this.onView,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        report.title,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: _getEventTypeColor(report.eventType),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              report.eventType,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            report.state,
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Text(
                  DateFormat('MMM d').format(report.dateTime),
                  style: TextStyle(
                    color: Colors.grey[500],
                    fontSize: 12,
                  ),
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
            if (report.mediaFiles.isNotEmpty) ...[
              const SizedBox(height: 8),
              InkWell(
                onTap: onView,
                borderRadius: BorderRadius.circular(4),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.attach_file, size: 14, color: Colors.blue[700]),
                      const SizedBox(width: 4),
                      Text(
                        '${report.mediaFiles.length} file(s) - tap to view',
                        style: TextStyle(
                          color: Colors.blue[700],
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(Icons.open_in_new, size: 12, color: Colors.blue[700]),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                // View Details button
                OutlinedButton.icon(
                  onPressed: onView,
                  icon: const Icon(Icons.visibility, size: 14),
                  label: const Text('View', style: TextStyle(fontSize: 11)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.blue,
                    side: const BorderSide(color: Colors.blue),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
                const SizedBox(width: 6),
                OutlinedButton.icon(
                  onPressed: onReject,
                  icon: const Icon(Icons.close, size: 14),
                  label: const Text('Reject', style: TextStyle(fontSize: 11)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
                const SizedBox(width: 6),
                ElevatedButton.icon(
                  onPressed: onApprove,
                  icon: const Icon(Icons.check, size: 14),
                  label: const Text('Approve', style: TextStyle(fontSize: 11)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _getEventTypeColor(String eventType) {
    switch (eventType) {
      case 'Red Light':
        return Colors.red;
      case 'Speeding':
        return Colors.orange;
      case 'On Phone':
        return Colors.purple;
      case 'Reckless':
        return Colors.deepOrange;
      case 'Pedestrian Intersection':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }
}
