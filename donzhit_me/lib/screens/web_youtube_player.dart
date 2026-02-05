// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;
import 'package:flutter/material.dart';

/// YouTube player widget for Flutter web using iframe
class WebYoutubePlayer extends StatefulWidget {
  final String videoId;
  final String? title;

  const WebYoutubePlayer({
    super.key,
    required this.videoId,
    this.title,
  });

  @override
  State<WebYoutubePlayer> createState() => _WebYoutubePlayerState();
}

class _WebYoutubePlayerState extends State<WebYoutubePlayer> {
  late String _viewType;

  @override
  void initState() {
    super.initState();
    _viewType = 'youtube-player-${widget.videoId}-${DateTime.now().millisecondsSinceEpoch}';

    // Register the view factory
    ui_web.platformViewRegistry.registerViewFactory(
      _viewType,
      (int viewId) {
        final iframe = html.IFrameElement()
          // Use youtube-nocookie.com for privacy-enhanced embed (fewer restrictions)
          ..src = 'https://www.youtube-nocookie.com/embed/${widget.videoId}?autoplay=1&rel=0&modestbranding=1'
          ..style.border = 'none'
          ..style.width = '100%'
          ..style.height = '100%'
          ..allowFullscreen = true
          ..allow = 'accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share';
        return iframe;
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(
          widget.title ?? 'Video',
          style: const TextStyle(fontSize: 16),
        ),
      ),
      body: HtmlElementView(viewType: _viewType),
    );
  }
}

/// Check if we're running on web - always true in this file
bool get isWebPlatform => true;
