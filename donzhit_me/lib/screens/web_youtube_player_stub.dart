import 'package:flutter/material.dart';

/// Stub for non-web platforms - this should never be instantiated
class WebYoutubePlayer extends StatelessWidget {
  final String videoId;
  final String? title;

  const WebYoutubePlayer({
    super.key,
    required this.videoId,
    this.title,
  });

  @override
  Widget build(BuildContext context) {
    // This should never be called on non-web platforms
    return const Scaffold(
      body: Center(
        child: Text('Web YouTube player not available on this platform'),
      ),
    );
  }
}

/// Check if we're running on web - always false in this stub
bool get isWebPlatform => false;
