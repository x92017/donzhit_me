import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/traffic_report.dart';
import '../providers/report_provider.dart';
import '../providers/settings_provider.dart';
import '../constants/dropdown_options.dart';
import '../services/api_service.dart';
import '../services/places_service.dart';
import '../widgets/donzhit_logo.dart';
import '../widgets/platform_sign_in_button.dart';
import '../widgets/reaction_icons.dart';
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
  String? _selectedCity;
  final TextEditingController _cityController = TextEditingController();
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
    // Load default state from settings and fetch approved reports on init
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadDefaultState();
      context.read<ReportProvider>().fetchApprovedReports();
    });
  }

  void _loadDefaultState() {
    final settings = context.read<SettingsProvider>();
    if (_selectedState == null && settings.defaultState.isNotEmpty) {
      setState(() {
        _selectedState = settings.defaultState;
      });
    }
  }

  @override
  void dispose() {
    _apiService.removeAuthStateListener(_onAuthStateChanged);
    _cityController.dispose();
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
                  child: _buildCityFilter(),
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
                  // Clear city when state changes
                  _selectedCity = null;
                  _cityController.clear();
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
                  _selectedCity = null;
                  _cityController.clear();
                });
              },
              tooltip: 'Clear filter',
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCityFilter() {
    if (_selectedState == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: _CityAutocomplete(
        controller: _cityController,
        selectedState: _selectedState!,
        onCitySelected: (city) {
          setState(() {
            _selectedCity = city;
          });
        },
        onCleared: () {
          setState(() {
            _selectedCity = null;
          });
        },
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

    // Filter by city if selected
    if (_selectedCity != null && _selectedCity!.isNotEmpty) {
      reports = reports.where((r) =>
        r.city.toLowerCase().contains(_selectedCity!.toLowerCase())
      ).toList();
    }

    // Filter by category (event type) - check if any event type matches
    if (_selectedCategory != 'All') {
      reports = reports.where((r) => r.eventTypes.contains(_selectedCategory)).toList();
    }

    final hasFilters = _selectedState != null || _selectedCity != null || _selectedCategory != 'All';

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
                hasFilters
                    ? 'No approved reports match your filters'
                    : 'No approved reports yet',
                style: TextStyle(color: Colors.grey[600]),
                textAlign: TextAlign.center,
              ),
              if (hasFilters) ...[
                const SizedBox(height: 16),
                TextButton.icon(
                  onPressed: () {
                    setState(() {
                      _selectedState = null;
                      _selectedCity = null;
                      _cityController.clear();
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
            apiService: _apiService,
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

class _ApprovedReportCard extends StatefulWidget {
  final TrafficReport report;
  final VoidCallback onTap;
  final ApiService apiService;

  const _ApprovedReportCard({
    required this.report,
    required this.onTap,
    required this.apiService,
  });

  @override
  State<_ApprovedReportCard> createState() => _ApprovedReportCardState();
}

class _ApprovedReportCardState extends State<_ApprovedReportCard> {
  ReportEngagement? _engagement;
  List<Comment> _comments = [];
  bool _isLoadingEngagement = false;
  bool _isLoadingComments = false;
  bool _showComments = false;
  final TextEditingController _commentController = TextEditingController();

  TrafficReport get report => widget.report;

  @override
  void initState() {
    super.initState();
    _loadEngagement();
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _loadEngagement() async {
    if (report.id == null) return;
    setState(() => _isLoadingEngagement = true);
    final response = await widget.apiService.getReportEngagement(report.id!);
    if (mounted && response.isSuccess && response.data != null) {
      setState(() {
        _engagement = response.data;
        _isLoadingEngagement = false;
      });
    } else {
      setState(() => _isLoadingEngagement = false);
    }
  }

  Future<void> _loadComments() async {
    if (report.id == null) return;
    setState(() => _isLoadingComments = true);
    final response = await widget.apiService.getComments(report.id!);
    if (mounted && response.isSuccess && response.data != null) {
      setState(() {
        _comments = response.data!;
        _isLoadingComments = false;
      });
    } else {
      setState(() => _isLoadingComments = false);
    }
  }

  Future<void> _toggleReaction(ReactionType type) async {
    if (!widget.apiService.isSignedIn) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign in to react')),
      );
      return;
    }

    if (report.id == null || _engagement == null) return;

    final hasReacted = _engagement!.hasUserReacted(type);
    final existingReaction = _engagement!.userReactions.isNotEmpty
        ? _engagement!.userReactions.first
        : null;

    // If clicking the same reaction, toggle it off
    if (hasReacted) {
      // Optimistic update - remove reaction
      setState(() {
        final newCounts = Map<ReactionType, int>.from(_engagement!.reactionCounts);
        newCounts[type] = (newCounts[type] ?? 1) - 1;

        _engagement = ReportEngagement(
          reportId: _engagement!.reportId,
          reactionCounts: newCounts,
          userReactions: <ReactionType>{},
          commentCount: _engagement!.commentCount,
          comments: _engagement!.comments,
        );
      });

      final response = await widget.apiService.removeReaction(report.id!, type);
      if (!response.isSuccess) {
        _loadEngagement();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(response.error ?? 'Failed to remove reaction')),
          );
        }
      }
    } else {
      // Clicking a different reaction - remove existing first, then add new
      // Optimistic update
      setState(() {
        final newCounts = Map<ReactionType, int>.from(_engagement!.reactionCounts);

        // Remove count from existing reaction if any
        if (existingReaction != null) {
          newCounts[existingReaction] = (newCounts[existingReaction] ?? 1) - 1;
        }

        // Add count to new reaction
        newCounts[type] = (newCounts[type] ?? 0) + 1;

        _engagement = ReportEngagement(
          reportId: _engagement!.reportId,
          reactionCounts: newCounts,
          userReactions: {type},
          commentCount: _engagement!.commentCount,
          comments: _engagement!.comments,
        );
      });

      // Remove existing reaction first if any
      if (existingReaction != null) {
        await widget.apiService.removeReaction(report.id!, existingReaction);
      }

      // Add new reaction
      final response = await widget.apiService.addReaction(report.id!, type);
      if (!response.isSuccess) {
        _loadEngagement();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(response.error ?? 'Failed to add reaction')),
          );
        }
      }
    }
  }

  Future<void> _addComment() async {
    if (!widget.apiService.isSignedIn) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign in to comment')),
      );
      return;
    }

    final content = _commentController.text.trim();
    if (content.isEmpty || report.id == null) return;

    final response = await widget.apiService.addComment(report.id!, content);
    if (response.isSuccess && response.data != null) {
      setState(() {
        _comments.add(response.data!);
        _engagement = ReportEngagement(
          reportId: _engagement?.reportId ?? report.id!,
          reactionCounts: _engagement?.reactionCounts ?? {},
          userReactions: _engagement?.userReactions ?? {},
          commentCount: (_engagement?.commentCount ?? 0) + 1,
        );
      });
      _commentController.clear();
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(response.error ?? 'Failed to add comment')),
        );
      }
    }
  }

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
        onTap: widget.onTap,
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
                  const Divider(height: 16),
                  // Reactions row
                  _buildReactionsRow(),
                  // Comments section
                  if (_showComments) ...[
                    const SizedBox(height: 8),
                    _buildCommentsSection(),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReactionsRow() {
    if (_isLoadingEngagement) {
      return const SizedBox(
        height: 28,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }
    return Row(
      children: [
        _buildReactionButton(ReactionType.thumbsUp),
        _buildReactionButton(ReactionType.thumbsDown),
        _buildReactionButton(ReactionType.angryCar),
        _buildReactionButton(ReactionType.angryPedestrian),
        _buildReactionButton(ReactionType.angryBicycle),
        const Spacer(),
        // Comments button
        InkWell(
          onTap: () {
            setState(() {
              _showComments = !_showComments;
              if (_showComments && _comments.isEmpty) {
                _loadComments();
              }
            });
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              children: [
                Icon(
                  _showComments ? Icons.comment : Icons.comment_outlined,
                  size: 20,
                  color: _showComments ? Theme.of(context).primaryColor : Colors.grey[600],
                ),
                const SizedBox(width: 4),
                Text(
                  '${_engagement?.commentCount ?? 0}',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildReactionButton(ReactionType type) {
    final hasReacted = _engagement?.hasUserReacted(type) ?? false;
    final count = _engagement?.getCount(type) ?? 0;

    Color iconColor;
    switch (type) {
      case ReactionType.thumbsUp:
        iconColor = Colors.blue;
        break;
      case ReactionType.thumbsDown:
        iconColor = Colors.red;
        break;
      case ReactionType.angryCar:
        iconColor = Colors.orange;
        break;
      case ReactionType.angryPedestrian:
        iconColor = Colors.purple;
        break;
      case ReactionType.angryBicycle:
        iconColor = Colors.green;
        break;
    }

    final displayColor = hasReacted ? iconColor : Colors.grey[600]!;

    // Build the appropriate icon widget
    Widget iconWidget;
    switch (type) {
      case ReactionType.thumbsUp:
        iconWidget = Icon(
          hasReacted ? Icons.thumb_up : Icons.thumb_up_outlined,
          size: 20,
          color: displayColor,
        );
        break;
      case ReactionType.thumbsDown:
        iconWidget = Icon(
          hasReacted ? Icons.thumb_down : Icons.thumb_down_outlined,
          size: 20,
          color: displayColor,
        );
        break;
      case ReactionType.angryCar:
        iconWidget = AngryCarIcon(
          size: 20,
          color: displayColor,
          filled: hasReacted,
        );
        break;
      case ReactionType.angryPedestrian:
        iconWidget = AngryPedestrianIcon(
          size: 20,
          color: displayColor,
          filled: hasReacted,
        );
        break;
      case ReactionType.angryBicycle:
        iconWidget = AngryBicycleIcon(
          size: 20,
          color: displayColor,
          filled: hasReacted,
        );
        break;
    }

    return InkWell(
      onTap: () => _toggleReaction(type),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            iconWidget,
            if (count > 0) ...[
              const SizedBox(width: 2),
              Text(
                '$count',
                style: TextStyle(
                  fontSize: 12,
                  color: displayColor,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCommentsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Comment input
        if (widget.apiService.isSignedIn) ...[
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _commentController,
                  decoration: InputDecoration(
                    hintText: 'Add a comment...',
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  maxLines: 1,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _addComment(),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.send),
                onPressed: _addComment,
                iconSize: 20,
              ),
            ],
          ),
          const SizedBox(height: 8),
        ] else ...[
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'Sign in to comment',
              style: TextStyle(
                color: Colors.grey[600],
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
        // Comments list
        if (_isLoadingComments)
          const Padding(
            padding: EdgeInsets.all(8),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          )
        else if (_comments.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'No comments yet',
              style: TextStyle(color: Colors.grey[600]),
            ),
          )
        else
          ...(_comments.length > 3 ? _comments.take(3) : _comments).map((comment) => _buildCommentItem(comment)),
        if (_comments.length > 3)
          TextButton(
            onPressed: () {
              // Could navigate to a full comments screen
            },
            child: Text('View all ${_comments.length} comments'),
          ),
      ],
    );
  }

  Widget _buildCommentItem(Comment comment) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: Colors.grey[300],
            child: Text(
              comment.displayName.isNotEmpty ? comment.displayName[0].toUpperCase() : '?',
              style: const TextStyle(fontSize: 12),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  comment.displayName,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                Text(
                  comment.content,
                  style: const TextStyle(fontSize: 13),
                ),
              ],
            ),
          ),
        ],
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

/// Custom city autocomplete widget that filters by selected state
class _CityAutocomplete extends StatefulWidget {
  final TextEditingController controller;
  final String selectedState;
  final Function(String) onCitySelected;
  final VoidCallback onCleared;

  const _CityAutocomplete({
    required this.controller,
    required this.selectedState,
    required this.onCitySelected,
    required this.onCleared,
  });

  @override
  State<_CityAutocomplete> createState() => _CityAutocompleteState();
}

class _CityAutocompleteState extends State<_CityAutocomplete> {
  List<CityPrediction> _predictions = [];
  bool _isLoading = false;
  bool _showSuggestions = false;
  Timer? _debounceTimer;
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
    _focusNode.addListener(_onFocusChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    _focusNode.removeListener(_onFocusChanged);
    _focusNode.dispose();
    _debounceTimer?.cancel();
    _removeOverlay();
    super.dispose();
  }

  void _onFocusChanged() {
    if (!_focusNode.hasFocus) {
      _removeOverlay();
    }
  }

  void _onTextChanged() {
    _debounceTimer?.cancel();
    final query = widget.controller.text;

    if (query.isEmpty) {
      setState(() {
        _predictions = [];
        _showSuggestions = false;
      });
      _removeOverlay();
      return;
    }

    _debounceTimer = Timer(const Duration(milliseconds: 400), () {
      _searchCities(query);
    });
  }

  Future<void> _searchCities(String query) async {
    if (!mounted) return;

    setState(() => _isLoading = true);

    final results = await PlacesService.searchCities(query, widget.selectedState);

    if (!mounted) return;

    setState(() {
      _predictions = results;
      _isLoading = false;
      _showSuggestions = results.isNotEmpty;
    });

    if (_showSuggestions) {
      _showOverlay();
    } else {
      _removeOverlay();
    }
  }

  void _showOverlay() {
    _removeOverlay();

    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        width: MediaQuery.of(context).size.width - 32,
        child: CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          offset: const Offset(0, 48),
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(8),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 200),
              child: ListView.separated(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                itemCount: _predictions.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final prediction = _predictions[index];
                  return ListTile(
                    dense: true,
                    leading: const Icon(Icons.location_on, size: 20),
                    title: Text(prediction.mainText),
                    subtitle: Text(
                      prediction.secondaryText,
                      style: const TextStyle(fontSize: 12),
                    ),
                    onTap: () => _selectCity(prediction),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  void _selectCity(CityPrediction prediction) {
    widget.controller.text = prediction.mainText;
    widget.controller.selection = TextSelection.fromPosition(
      TextPosition(offset: widget.controller.text.length),
    );
    widget.onCitySelected(prediction.mainText);
    _removeOverlay();
    setState(() {
      _showSuggestions = false;
      _predictions = [];
    });
  }

  void _clearCity() {
    widget.controller.clear();
    widget.onCleared();
    _removeOverlay();
    setState(() {
      _showSuggestions = false;
      _predictions = [];
    });
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: TextField(
        controller: widget.controller,
        focusNode: _focusNode,
        decoration: InputDecoration(
          labelText: 'City (Optional)',
          hintText: 'Filter by city in ${widget.selectedState}',
          prefixIcon: const Icon(Icons.location_city),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          isDense: true,
          suffixIcon: _isLoading
              ? const Padding(
                  padding: EdgeInsets.all(12),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : widget.controller.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 20),
                      onPressed: _clearCity,
                    )
                  : null,
        ),
      ),
    );
  }
}
