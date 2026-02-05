import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import '../models/sample_videos.dart';
import 'web_youtube_player.dart' if (dart.library.io) 'web_youtube_player_stub.dart';
// Conditional import for dart:io (only available on mobile/desktop)
import 'video_player_io.dart' if (dart.library.io) 'video_player_io_real.dart';

class VideoPlayerScreen extends StatefulWidget {
  final String? videoPath;
  final String? videoUrl;
  final String? youtubeVideoId;
  final SampleVideo? sampleVideo;
  final String? title;

  const VideoPlayerScreen({
    super.key,
    this.videoPath,
    this.videoUrl,
    this.youtubeVideoId,
    this.sampleVideo,
    this.title,
  });

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  VideoPlayerController? _videoController;
  ChewieController? _chewieController;
  YoutubePlayerController? _youtubeController;
  bool _isLoading = true;
  String? _error;

  bool get _isYoutubeVideo =>
      widget.youtubeVideoId != null || widget.sampleVideo != null;

  String get _youtubeId =>
      widget.youtubeVideoId ?? widget.sampleVideo?.youtubeId ?? '';

  String get _title =>
      widget.title ??
      widget.sampleVideo?.title ??
      'Video Player';

  @override
  void initState() {
    super.initState();
    _initializePlayer();
  }

  Future<void> _initializePlayer() async {
    if (_isYoutubeVideo) {
      _initYoutubePlayer();
    } else {
      await _initVideoPlayer();
    }
  }

  void _initYoutubePlayer() {
    _youtubeController = YoutubePlayerController(
      initialVideoId: _youtubeId,
      flags: const YoutubePlayerFlags(
        autoPlay: true,
        mute: false,
        enableCaption: true,
        forceHD: false,
      ),
    );

    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _initVideoPlayer() async {
    try {
      if (widget.videoPath != null) {
        _videoController = createFileVideoController(widget.videoPath!);
        if (_videoController == null) {
          setState(() {
            _error = 'Local file playback not supported on this platform';
            _isLoading = false;
          });
          return;
        }
      } else if (widget.videoUrl != null) {
        _videoController = VideoPlayerController.networkUrl(
          Uri.parse(widget.videoUrl!),
        );
      } else {
        setState(() {
          _error = 'No video source provided';
          _isLoading = false;
        });
        return;
      }

      await _videoController!.initialize();

      _chewieController = ChewieController(
        videoPlayerController: _videoController!,
        autoPlay: true,
        looping: false,
        aspectRatio: _videoController!.value.aspectRatio,
        allowFullScreen: true,
        allowMuting: true,
        showControls: true,
        materialProgressColors: ChewieProgressColors(
          playedColor: Theme.of(context).colorScheme.primary,
          handleColor: Theme.of(context).colorScheme.primary,
          backgroundColor: Colors.grey,
          bufferedColor: Colors.grey[400]!,
        ),
        placeholder: Container(
          color: Colors.black,
          child: const Center(
            child: CircularProgressIndicator(),
          ),
        ),
        errorBuilder: (context, errorMessage) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.error_outline,
                  color: Colors.white,
                  size: 48,
                ),
                const SizedBox(height: 16),
                Text(
                  errorMessage,
                  style: const TextStyle(color: Colors.white),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        },
      );

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load video: $e';
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _videoController?.dispose();
    _chewieController?.dispose();
    _youtubeController?.dispose();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isYoutubeVideo) {
      // Use web-specific player on web platform
      if (kIsWeb) {
        return WebYoutubePlayer(
          videoId: _youtubeId,
          title: _title,
        );
      }
      return _buildYoutubePlayer();
    } else {
      return _buildLocalVideoPlayer();
    }
  }

  Widget _buildYoutubePlayer() {
    return YoutubePlayerBuilder(
      onExitFullScreen: () {
        SystemChrome.setPreferredOrientations(DeviceOrientation.values);
      },
      player: YoutubePlayer(
        controller: _youtubeController!,
        showVideoProgressIndicator: true,
        progressIndicatorColor: Theme.of(context).colorScheme.primary,
        progressColors: ProgressBarColors(
          playedColor: Theme.of(context).colorScheme.primary,
          handleColor: Theme.of(context).colorScheme.primary,
        ),
        width: double.infinity,
        onReady: () {
          setState(() {
            _isLoading = false;
          });
        },
        onEnded: (data) {
          // Video ended
        },
      ),
      builder: (context, player) {
        return Scaffold(
          backgroundColor: Colors.black,
          extendBodyBehindAppBar: true,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            foregroundColor: Colors.white,
            elevation: 0,
            title: Text(
              _title,
              style: const TextStyle(fontSize: 16),
            ),
          ),
          body: widget.sampleVideo != null
              ? Column(
                  children: [
                    player,
                    _buildVideoInfo(),
                  ],
                )
              : LayoutBuilder(
                  builder: (context, constraints) {
                    return SizedBox(
                      width: constraints.maxWidth,
                      height: constraints.maxHeight,
                      child: player,
                    );
                  },
                ),
        );
      },
    );
  }

  Widget _buildVideoInfo() {
    final video = widget.sampleVideo!;
    return Expanded(
      child: Container(
        color: Colors.grey[900],
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                video.title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _buildInfoChip(Icons.category, video.category),
                  const SizedBox(width: 8),
                  _buildInfoChip(Icons.location_on, video.location),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                video.description,
                style: TextStyle(
                  color: Colors.grey[300],
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Recorded: ${_formatDate(video.date)}',
                style: TextStyle(
                  color: Colors.grey[500],
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 24),
              // Action buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildActionButton(
                    Icons.share,
                    'Share',
                    () => _shareVideo(video),
                  ),
                  _buildActionButton(
                    Icons.flag,
                    'Report',
                    () => _reportVideo(video),
                  ),
                  _buildActionButton(
                    Icons.download,
                    'Save',
                    () => _saveVideo(video),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.grey[800],
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.grey[400]),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: Colors.grey[300],
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(IconData icon, String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Column(
        children: [
          Icon(icon, color: Colors.white, size: 24),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocalVideoPlayer() {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(
          _title,
          style: const TextStyle(fontSize: 16),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Colors.white),
            )
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        color: Colors.red,
                        size: 64,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _error!,
                        style: const TextStyle(color: Colors.white),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _isLoading = true;
                            _error = null;
                          });
                          _initVideoPlayer();
                        },
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : _chewieController != null
                  ? Chewie(controller: _chewieController!)
                  : const Center(
                      child: Text(
                        'Failed to load video player',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.month}/${date.day}/${date.year}';
  }

  void _shareVideo(SampleVideo video) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Share: ${video.youtubeUrl}'),
        action: SnackBarAction(
          label: 'Copy',
          onPressed: () {
            Clipboard.setData(ClipboardData(text: video.youtubeUrl));
          },
        ),
      ),
    );
  }

  void _reportVideo(SampleVideo video) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Report Video'),
        content: const Text(
          'Would you like to create a new report based on this video?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
              // Navigate to report form
            },
            child: const Text('Create Report'),
          ),
        ],
      ),
    );
  }

  void _saveVideo(SampleVideo video) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Video saved to favorites')),
    );
  }
}
