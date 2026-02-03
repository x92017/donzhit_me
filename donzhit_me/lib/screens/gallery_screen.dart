import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/traffic_report.dart';
import '../providers/report_provider.dart';
import '../constants/dropdown_options.dart';
import '../services/api_service.dart';
import '../widgets/donzhit_logo.dart';
import '../widgets/platform_sign_in_button.dart';
import 'video_player_screen.dart';
import 'image_viewer_screen.dart';

class GalleryScreen extends StatefulWidget {
  const GalleryScreen({super.key});

  @override
  State<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends State<GalleryScreen> {
  String _selectedCategory = 'All';
  String? _selectedState;
  final ApiService _apiService = ApiService();
  bool _isSigningIn = false;

  // Event type categories for filtering
  static const List<String> _categories = [
    'All',
    'Pedestrian Intersection',
    'Red Light',
    'Speeding',
    'On Phone',
    'Reckless',
  ];

  @override
  void initState() {
    super.initState();
    _apiService.initialize();
    // Listen for auth state changes to update UI when auto sign-in completes
    _apiService.addAuthStateListener(_onAuthStateChanged);
    // Fetch approved reports on init
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ReportProvider>().fetchApprovedReports();
    });
  }

  @override
  void dispose() {
    _apiService.removeAuthStateListener(_onAuthStateChanged);
    super.dispose();
  }

  void _onAuthStateChanged() {
    if (mounted) {
      setState(() {
        // Rebuild to reflect sign-in state
      });
    }
  }

  Future<void> _handleSignIn() async {
    debugPrint('=== Sign-in button pressed ===');
    setState(() => _isSigningIn = true);
    try {
      final success = await _apiService.signIn();
      debugPrint('=== Sign-in completed: $success ===');
    } catch (e) {
      debugPrint('=== Sign-in exception: $e ===');
    } finally {
      if (mounted) {
        setState(() => _isSigningIn = false);
      }
    }
  }

  Future<void> _handleSignOut() async {
    await _apiService.signOut();
    setState(() {});
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

    // On web, use the Google-rendered sign-in button
    if (kIsWeb) {
      return buildGoogleSignInButton();
    }

    // On mobile platforms, use a custom button
    return ElevatedButton.icon(
      onPressed: _handleSignIn,
      icon: const Icon(Icons.login, size: 18),
      label: const Text('Sign In'),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light, // Light icons for dark header
        statusBarBrightness: Brightness.dark, // For iOS
      ),
      child: Scaffold(
        body: Consumer<ReportProvider>(
        builder: (context, provider, child) {
          return RefreshIndicator(
            onRefresh: () => provider.fetchApprovedReports(),
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Container(
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
                              _buildAuthButton(),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Report pedestrian/traffic violations',
                            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                  color: Colors.white.withValues(alpha: 0.9),
                                ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: _buildStateFilter(),
                ),
                SliverToBoxAdapter(
                  child: _buildCategoryFilter(),
                ),
                SliverToBoxAdapter(
                  child: _buildApprovedReportsGrid(provider),
                ),
              ],
            ),
          );
        },
      ),
      ),
    );
  }

  Widget _buildStateFilter() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(
        children: [
          Expanded(
            child: DropdownButtonFormField<String>(
              value: _selectedState,
              decoration: InputDecoration(
                labelText: 'State/Province',
                prefixIcon: const Icon(Icons.location_on),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                isDense: true,
              ),
              isExpanded: true,
              items: [
                const DropdownMenuItem<String>(
                  value: null,
                  child: Text('All Locations'),
                ),
                ...DropdownOptions.selectableStatesAndProvinces.map(
                  (state) => DropdownMenuItem(
                    value: state,
                    child: Text(state),
                  ),
                ),
              ],
              onChanged: (value) {
                setState(() {
                  _selectedState = value;
                });
              },
            ),
          ),
          if (_selectedState != null) ...[
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.clear),
              onPressed: () {
                setState(() {
                  _selectedState = null;
                });
              },
              tooltip: 'Clear filter',
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCategoryFilter() {
    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _categories.length,
        itemBuilder: (context, index) {
          final category = _categories[index];
          final isSelected = category == _selectedCategory;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(category),
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  _selectedCategory = category;
                });
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildApprovedReportsGrid(ReportProvider provider) {
    if (provider.isLoading && provider.approvedReports.isEmpty) {
      return const SizedBox(
        height: 200,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    var reports = provider.approvedReports;

    // Filter by state if selected
    if (_selectedState != null) {
      reports = reports.where((r) => r.state == _selectedState).toList();
    }

    // Filter by category (event type) - check if any event type matches
    if (_selectedCategory != 'All') {
      reports = reports.where((r) => r.eventTypes.contains(_selectedCategory)).toList();
    }

    if (reports.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.video_library_outlined, size: 64, color: Colors.grey[400]),
              const SizedBox(height: 16),
              Text(
                _selectedState != null || _selectedCategory != 'All'
                    ? 'No approved reports match your filters'
                    : 'No approved reports yet',
                style: TextStyle(color: Colors.grey[600]),
                textAlign: TextAlign.center,
              ),
              if (_selectedState != null || _selectedCategory != 'All') ...[
                const SizedBox(height: 16),
                TextButton.icon(
                  onPressed: () {
                    setState(() {
                      _selectedState = null;
                      _selectedCategory = 'All';
                    });
                  },
                  icon: const Icon(Icons.clear_all),
                  label: const Text('Clear Filters'),
                ),
              ],
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemCount: reports.length,
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: _ApprovedReportCard(
            report: reports[index],
            onTap: () => _openReportMedia(reports[index]),
          ),
        );
      },
    );
  }

  void _openReportMedia(TrafficReport report) {
    if (report.mediaFiles.isEmpty) {
      // Show report details if no media
      _showReportDetails(report);
      return;
    }

    final firstMedia = report.mediaFiles.first;
    if (firstMedia.isVideo) {
      // Check if YouTube video
      final youtubeId = _extractYouTubeId(firstMedia.url);
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => VideoPlayerScreen(
            videoPath: youtubeId == null && firstMedia.path.isNotEmpty ? firstMedia.path : null,
            videoUrl: youtubeId == null && firstMedia.path.isEmpty ? firstMedia.url : null,
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

      if (imageUrls.isNotEmpty) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ImageViewerScreen(
              allImages: imageUrls,
              initialIndex: 0,
              title: report.title,
            ),
          ),
        );
      } else {
        _showReportDetails(report);
      }
    }
  }

  void _showReportDetails(TrafficReport report) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              report.title,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                ...report.eventTypes.map((eventType) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getEventTypeColor(eventType),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    eventType,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                )),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.location_on, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Text(report.state, style: TextStyle(color: Colors.grey[600])),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              report.description,
              style: TextStyle(color: Colors.grey[700]),
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
}

class _ApprovedReportCard extends StatelessWidget {
  final TrafficReport report;
  final VoidCallback onTap;

  const _ApprovedReportCard({
    required this.report,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hasMedia = report.mediaFiles.isNotEmpty;
    final hasVideo = report.mediaFiles.any((m) => m.isVideo);
    final firstMedia = hasMedia ? report.mediaFiles.first : null;
    final thumbnailUrl = _getThumbnailUrl(firstMedia);

    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Thumbnail with 16:9 aspect ratio
            AspectRatio(
              aspectRatio: 16 / 9,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  thumbnailUrl != null && thumbnailUrl.isNotEmpty
                      ? Image.network(
                          thumbnailUrl,
                          fit: BoxFit.cover,
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return Container(
                              color: Colors.grey[300],
                              child: const Center(
                                child: CircularProgressIndicator(),
                              ),
                            );
                          },
                          errorBuilder: (context, error, stackTrace) {
                            return _buildPlaceholder(hasVideo);
                          },
                        )
                      : _buildPlaceholder(hasVideo),
                  // Play button overlay for videos
                  if (hasVideo)
                    Center(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.6),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.play_arrow,
                          color: Colors.white,
                          size: 40,
                        ),
                      ),
                    ),
                  // Event type badges
                  if (report.eventTypes.isNotEmpty)
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Wrap(
                        spacing: 4,
                        runSpacing: 4,
                        children: report.eventTypes.map((eventType) => Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: _getEventTypeColor(eventType).withValues(alpha: 0.9),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            eventType,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10.8,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        )).toList(),
                      ),
                    ),
                ],
              ),
            ),
            // Title, description, and location
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    report.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    report.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[700],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.location_on, size: 16, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Text(
                        report.city.isNotEmpty ? '${report.city}, ${report.state}' : report.state,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                  if (report.roadUsages.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.directions_car, size: 16, color: Colors.grey[600]),
                        const SizedBox(width: 4),
                        Text(
                          report.roadUsages.join(', '),
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholder(bool isVideo) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isVideo
              ? [Colors.indigo.shade200, Colors.indigo.shade400]
              : [Colors.grey.shade200, Colors.grey.shade400],
        ),
      ),
      child: Center(
        child: Icon(
          isVideo ? Icons.videocam : Icons.image,
          color: Colors.white.withValues(alpha: 0.8),
          size: 48,
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

  /// Get thumbnail URL for media - extracts YouTube thumbnail or returns image URL
  String? _getThumbnailUrl(MediaFile? media) {
    if (media == null || media.url == null) {
      debugPrint('_getThumbnailUrl: media=${media != null}, url=${media?.url}');
      return null;
    }

    final url = media.url!;
    debugPrint('_getThumbnailUrl: url=$url');

    // For images, use the URL directly
    if (media.isImage) {
      return url;
    }

    // For YouTube videos, extract video ID and construct thumbnail URL
    final youtubeId = _extractYouTubeId(url);
    if (youtubeId != null) {
      return 'https://img.youtube.com/vi/$youtubeId/hqdefault.jpg';
    }

    // For GCS/non-YouTube videos, no thumbnail available
    return null;
  }

  String? _extractYouTubeId(String url) {
    final watchMatch = RegExp(r'youtube\.com/watch\?v=([a-zA-Z0-9_-]+)').firstMatch(url);
    if (watchMatch != null) return watchMatch.group(1);

    final shortMatch = RegExp(r'youtu\.be/([a-zA-Z0-9_-]+)').firstMatch(url);
    if (shortMatch != null) return shortMatch.group(1);

    final embedMatch = RegExp(r'youtube\.com/embed/([a-zA-Z0-9_-]+)').firstMatch(url);
    if (embedMatch != null) return embedMatch.group(1);

    return null;
  }
}
