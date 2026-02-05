import 'dart:io';
import 'package:video_player/video_player.dart';

/// Create a VideoPlayerController from a local file path
VideoPlayerController? createFileVideoController(String path) {
  return VideoPlayerController.file(File(path));
}
