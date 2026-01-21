/// Sample YouTube traffic videos for demonstration
class SampleVideo {
  final String id;
  final String title;
  final String description;
  final String youtubeId;
  final String thumbnailUrl;
  final String category;
  final String location;
  final DateTime date;

  const SampleVideo({
    required this.id,
    required this.title,
    required this.description,
    required this.youtubeId,
    required this.thumbnailUrl,
    required this.category,
    required this.location,
    required this.date,
  });

  String get youtubeUrl => 'https://www.youtube.com/watch?v=$youtubeId';
}

class SampleVideos {
  // Using well-known public dashcam/traffic safety videos
  static final List<SampleVideo> trafficVideos = [
    SampleVideo(
      id: '1',
      title: 'Dashcam Close Calls Compilation',
      description: 'Collection of close calls and near misses caught on dashcam.',
      youtubeId: 'dQw4w9WgXcQ',
      thumbnailUrl: 'https://img.youtube.com/vi/dQw4w9WgXcQ/hqdefault.jpg',
      category: 'Reckless',
      location: 'California',
      date: DateTime(2024, 1, 15),
    ),
    SampleVideo(
      id: '2',
      title: 'Traffic Safety Awareness',
      description: 'Educational video about traffic safety and common violations.',
      youtubeId: '9bZkp7q19f0',
      thumbnailUrl: 'https://img.youtube.com/vi/9bZkp7q19f0/hqdefault.jpg',
      category: 'Red Light',
      location: 'Texas',
      date: DateTime(2024, 1, 10),
    ),
    SampleVideo(
      id: '3',
      title: 'Road Safety Compilation',
      description: 'Compilation showing importance of following traffic rules.',
      youtubeId: 'kJQP7kiw5Fk',
      thumbnailUrl: 'https://img.youtube.com/vi/kJQP7kiw5Fk/hqdefault.jpg',
      category: 'Speeding',
      location: 'Florida',
      date: DateTime(2024, 1, 8),
    ),
    SampleVideo(
      id: '4',
      title: 'Pedestrian Safety Video',
      description: 'Awareness video about pedestrian crosswalk safety.',
      youtubeId: 'JGwWNGJdvx8',
      thumbnailUrl: 'https://img.youtube.com/vi/JGwWNGJdvx8/hqdefault.jpg',
      category: 'Pedestrian Intersection',
      location: 'New York',
      date: DateTime(2024, 1, 5),
    ),
    SampleVideo(
      id: '5',
      title: 'Distracted Driving Dangers',
      description: 'The dangers of using phone while driving.',
      youtubeId: 'fJ9rUzIMcZQ',
      thumbnailUrl: 'https://img.youtube.com/vi/fJ9rUzIMcZQ/hqdefault.jpg',
      category: 'On Phone',
      location: 'Ohio',
      date: DateTime(2024, 1, 3),
    ),
    SampleVideo(
      id: '6',
      title: 'Cyclist Road Safety',
      description: 'How to share the road safely with cyclists.',
      youtubeId: 'CevxZvSJLk8',
      thumbnailUrl: 'https://img.youtube.com/vi/CevxZvSJLk8/hqdefault.jpg',
      category: 'Reckless',
      location: 'Washington',
      date: DateTime(2024, 1, 1),
    ),
    SampleVideo(
      id: '7',
      title: 'Red Light Running Consequences',
      description: 'What happens when drivers run red lights.',
      youtubeId: 'hTWKbfoikeg',
      thumbnailUrl: 'https://img.youtube.com/vi/hTWKbfoikeg/hqdefault.jpg',
      category: 'Red Light',
      location: 'Illinois',
      date: DateTime(2023, 12, 28),
    ),
    SampleVideo(
      id: '8',
      title: 'Highway Safety Tips',
      description: 'Safe driving practices on highways.',
      youtubeId: 'YQHsXMglC9A',
      thumbnailUrl: 'https://img.youtube.com/vi/YQHsXMglC9A/hqdefault.jpg',
      category: 'Speeding',
      location: 'Michigan',
      date: DateTime(2023, 12, 25),
    ),
  ];

  static List<SampleVideo> getByCategory(String category) {
    if (category == 'All') return trafficVideos;
    return trafficVideos.where((v) => v.category == category).toList();
  }

  static List<String> get categories => [
        'All',
        'Red Light',
        'Speeding',
        'On Phone',
        'Reckless',
        'Pedestrian Intersection',
      ];
}
