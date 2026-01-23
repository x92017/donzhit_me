import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import '../models/sample_videos.dart';
import '../models/traffic_report.dart';
import '../providers/report_provider.dart';
import '../constants/dropdown_options.dart';
import 'video_player_screen.dart';
import 'image_viewer_screen.dart';

class GalleryScreen extends StatefulWidget {
  const GalleryScreen({super.key});

  @override
  State<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends State<GalleryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _selectedCategory = 'All';
  String? _selectedState;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Media Gallery'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.play_circle), text: 'Sample Videos'),
            Tab(icon: Icon(Icons.photo_library), text: 'My Media'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildSampleVideosTab(),
          _buildMyMediaTab(),
        ],
      ),
    );
  }

  Widget _buildSampleVideosTab() {
    return Column(
      children: [
        // State/Province dropdown
        _buildStateFilter(),

        // Category filter
        _buildCategoryFilter(),

        // Videos grid
        Expanded(
          child: _buildVideosGrid(),
        ),
      ],
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
        itemCount: SampleVideos.categories.length,
        itemBuilder: (context, index) {
          final category = SampleVideos.categories[index];
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

  Widget _buildVideosGrid() {
    var videos = SampleVideos.getByCategory(_selectedCategory);

    // Filter by state if selected
    if (_selectedState != null) {
      videos = videos.where((v) => v.location == _selectedState).toList();
    }

    if (videos.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.video_library_outlined, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              _selectedState != null
                  ? 'No videos for $_selectedState'
                  : 'No videos in this category',
              style: TextStyle(color: Colors.grey[600]),
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
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 16 / 12,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: videos.length,
      itemBuilder: (context, index) {
        return _VideoCard(
          video: videos[index],
          onTap: () => _openVideoPlayer(videos[index]),
        );
      },
    );
  }

  Widget _buildMyMediaTab() {
    return Consumer<ReportProvider>(
      builder: (context, provider, child) {
        final allMedia = _getAllMediaFromReports(provider.reports);

        if (allMedia.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.photo_library_outlined,
                    size: 64, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  'No media uploaded yet',
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Upload photos or videos with your reports',
                  style: TextStyle(color: Colors.grey[500]),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () {
                    // Navigate to report form
                    DefaultTabController.of(context).animateTo(1);
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('Create Report'),
                ),
              ],
            ),
          );
        }

        return GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            childAspectRatio: 1,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
          ),
          itemCount: allMedia.length,
          itemBuilder: (context, index) {
            final media = allMedia[index];
            return _MediaThumbnail(
              media: media,
              onTap: () => _openMedia(media, allMedia, index),
            );
          },
        );
      },
    );
  }

  List<MediaFile> _getAllMediaFromReports(List<TrafficReport> reports) {
    final List<MediaFile> allMedia = [];
    for (final report in reports) {
      allMedia.addAll(report.mediaFiles);
    }
    return allMedia;
  }

  void _openVideoPlayer(SampleVideo video) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => VideoPlayerScreen(sampleVideo: video),
      ),
    );
  }

  void _openMedia(MediaFile media, List<MediaFile> allMedia, int index) {
    if (media.isVideo) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => VideoPlayerScreen(
            videoPath: media.path,
            title: media.name,
          ),
        ),
      );
    } else {
      final imagePaths = allMedia
          .where((m) => m.isImage)
          .map((m) => m.path)
          .toList();
      final imageIndex = imagePaths.indexOf(media.path);

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ImageViewerScreen(
            allImages: imagePaths,
            initialIndex: imageIndex >= 0 ? imageIndex : 0,
            title: media.name,
          ),
        ),
      );
    }
  }
}

class _VideoCard extends StatelessWidget {
  final SampleVideo video;
  final VoidCallback onTap;

  const _VideoCard({
    required this.video,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Thumbnail
            Expanded(
              flex: 3,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CachedNetworkImage(
                    imageUrl: video.thumbnailUrl,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      color: Colors.grey[300],
                      child: const Center(
                        child: CircularProgressIndicator(),
                      ),
                    ),
                    errorWidget: (context, url, error) => Container(
                      color: Colors.grey[300],
                      child: const Icon(Icons.error),
                    ),
                  ),
                  // Play button overlay
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(8),
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
                  // Category badge
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: _getCategoryColor(video.category),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        video.category,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Title
            Expanded(
              flex: 1,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Text(
                  video.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getCategoryColor(String category) {
    switch (category) {
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

class _MediaThumbnail extends StatelessWidget {
  final MediaFile media;
  final VoidCallback onTap;

  const _MediaThumbnail({
    required this.media,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(8),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (media.url != null && media.url!.isNotEmpty)
                CachedNetworkImage(
                  imageUrl: media.url!,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    color: Colors.grey[300],
                  ),
                  errorWidget: (context, url, error) => _buildPlaceholder(),
                )
              else
                _buildPlaceholder(),
              if (media.isVideo)
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.6),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.play_arrow,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      color: Colors.grey[300],
      child: Center(
        child: Icon(
          media.isVideo ? Icons.videocam : Icons.image,
          color: Colors.grey[600],
          size: 32,
        ),
      ),
    );
  }
}
