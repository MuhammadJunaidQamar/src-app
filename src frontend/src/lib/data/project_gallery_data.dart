class ProjectGalleryItem {
  final String title;
  final String subtitle;
  final String? imagePath;

  const ProjectGalleryItem({
    required this.title,
    required this.subtitle,
    this.imagePath,
  });

  bool get isSvg =>
      imagePath != null && imagePath!.toLowerCase().endsWith('.svg');
}

class ProjectGalleryData {
  /// Asset paths must be relative to the Flutter project root (`assets/...`).
  final List<ProjectGalleryItem> items = const [
    ProjectGalleryItem(
      title: 'CanSat Flight',
      subtitle: 'Launch & recovery',
      imagePath: 'assets/images/Group-48095552.svg',
    ),
    ProjectGalleryItem(
      title: 'Ground Station',
      subtitle: 'Live telemetry dashboard',
      imagePath: 'assets/images/BackGround.png',
    ),
    ProjectGalleryItem(
      title: 'Payload Integration',
      subtitle: 'Sensors · camera · radio',
      imagePath: 'assets/icons/svgviewer-output.svg',
    ),
    ProjectGalleryItem(
      title: 'Team Lab',
      subtitle: 'Assembly & testing',
      imagePath: 'assets/icons/svgviewer-output (2).svg',
    ),
    ProjectGalleryItem(
      title: 'Team Lab',
      subtitle: 'Assembly & testing',
      imagePath: 'assets/icons/svgviewer-output (1).svg',
    ),
  ];
}
