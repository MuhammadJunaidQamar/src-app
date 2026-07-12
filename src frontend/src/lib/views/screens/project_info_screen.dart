import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:src/data/project_gallery_data.dart';
import 'package:src/data/team_member_data.dart';
import 'package:src/utils/constants/constants.dart';
import 'package:src/utils/responsive.dart';
import 'package:src/widgets/custom_card_widget.dart';
import 'package:src/widgets/header_widget.dart';
import 'package:src/widgets/team_member_card.dart';

class ProjectInfoScreen extends StatelessWidget {
  const ProjectInfoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 10.0),
      child: Row(
        children: [
          Expanded(
            flex: 75,
            child: Column(
              children: [
                const HeaderWidget(),
                Expanded(
                  child: CustomCard(
                    expandChild: true,
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                    child: const _ProjectTeamBody(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

//TODO https://support.freepik.com/s/article/Attribution-How-when-and-where?language=en_US&_gl=1*wnybt3*_gcl_au*ODYwMzg4MTAzLjE3MjgwNzY1NDE.*_ga*MTk1NzQyNTgyNy4xNzI4MDc2NTQy*_ga_18B6QPTJPC*MTcyODA3NjU0MS4xLjEuMTcyODA3NjU2MC40MS4wLjA.*_ga_QWX66025LC*MTcyODA3NjU0Mi4xLjEuMTcyODA3NjU2MS40MS4wLjA.*_ga_Q29FZ8F7H4*MTcyODA3NjU0Mi4xLjEuMTcyODA3NjU2MC4wLjAuMA..
class _ProjectTeamBody extends StatefulWidget {
  const _ProjectTeamBody();

  @override
  State<_ProjectTeamBody> createState() => _ProjectTeamBodyState();
}

class _ProjectTeamBodyState extends State<_ProjectTeamBody> {
  final ScrollController _scrollController = ScrollController();
  // Start on the second slide so the hero (center, weight 7) is filled.
  final CarouselController _carouselController =
      CarouselController(initialItem: 1);

  @override
  void dispose() {
    _scrollController.dispose();
    _carouselController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final members = TeamMemberData().members;
    final gallery = ProjectGalleryData().items;
    final isMobile = Responsive.isMobile(context);
    // Landscape wallpaper strip (~16:9), not tall TV-hero.
    final screenWidth = MediaQuery.sizeOf(context).width;
    final carouselHeight =
        (screenWidth * 9 / 16).clamp(150.0, isMobile ? 190.0 : 240.0);

    // One vertical scroll for gallery + team. Explicit controllers so CarouselView
    // and SingleChildScrollView don't both bind to PrimaryScrollController.
    return Scrollbar(
      controller: _scrollController,
      thumbVisibility: true,
      thickness: 8,
      radius: const Radius.circular(8),
      child: SingleChildScrollView(
        controller: _scrollController,
        primary: false,
        padding: const EdgeInsets.fromLTRB(4, 0, 12, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionTitle(
              title: 'Project Gallery',
              subtitle: 'Flight · payload · ground station',
              isMobile: isMobile,
            ),
            const SizedBox(height: 10),
            // Same API as Material sample (hero layout):
            // flexWeights [1, 7, 1] → peek | large | peek
            // Large radius + default item padding = gaps between tiles
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: carouselHeight),
              child: CarouselView.weighted(
                controller: _carouselController,
                itemSnapping: true,
                flexWeights: const <int>[1, 7, 1],
                // Material 3 carousel shape from the sample UI (~28)
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.all(Radius.circular(28)),
                ),
                // Spacing between the 3 visible items (matches sample gaps)
                padding: const EdgeInsets.symmetric(horizontal: 8),
                children: [
                  for (final item in gallery) _HeroGalleryCard(item: item),
                ],
              ),
            ),
            const SizedBox(height: 22),
            _SectionTitle(
              title: 'Meet the Team',
              subtitle: 'Space Research Center — UCP',
              isMobile: isMobile,
            ),
            const SizedBox(height: 16),
            Center(
              child: Wrap(
                alignment: WrapAlignment.center,
                spacing: 32,
                runSpacing: 32,
                children: [
                  for (final member in members) TeamMemberCard(member: member),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({
    required this.title,
    required this.subtitle,
    required this.isMobile,
  });

  final String title;
  final String subtitle;
  final bool isMobile;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: AppColors.mainTextColor1,
              fontSize: isMobile ? 22 : 26,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(
              color: AppColors.lightSlateGrey,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

/// Same structure as Material sample `HeroLayoutCard`.
class _HeroGalleryCard extends StatelessWidget {
  const _HeroGalleryCard({required this.item});

  final ProjectGalleryItem item;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return Stack(
      alignment: Alignment.bottomLeft,
      children: <Widget>[
        ClipRect(
          child: OverflowBox(
            maxWidth: width * 7 / 8,
            minWidth: width * 7 / 8,
            child: item.imagePath != null
                ? _GalleryImage(item: item)
                : const ColoredBox(color: AppColors.eigengrauColor),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                item.title,
                overflow: TextOverflow.clip,
                softWrap: false,
                style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                      color: Colors.white,
                    ),
              ),
              const SizedBox(height: 10),
              Text(
                item.subtitle,
                overflow: TextOverflow.clip,
                softWrap: false,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.white,
                    ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _GalleryImage extends StatelessWidget {
  const _GalleryImage({required this.item});

  final ProjectGalleryItem item;

  @override
  Widget build(BuildContext context) {
    final path = item.imagePath!;
    if (item.isSvg) {
      return ColoredBox(
        color: AppColors.eigengrauColor,
        child: SvgPicture.asset(
          path,
          fit: BoxFit.contain,
          placeholderBuilder: (_) => const ColoredBox(
            color: AppColors.eigengrauColor,
          ),
        ),
      );
    }
    return Image.asset(
      path,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => const ColoredBox(
        color: AppColors.eigengrauColor,
      ),
    );
  }
}
